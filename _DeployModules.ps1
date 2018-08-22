###################################################
# 3/7/2017 jfk
# 1. Changed line 5:Mandatory=$true to $false
# 2. Changed line 46, 48 from $moduleDir to $NACDir
###################################################

param(
    [Parameter(Position=0, Mandatory=$false)]
    [string]$engineUrl = "tcp://localhost:2048/EngineController",
    [Parameter(Position=1)]
    [switch]$purgeNac = $false,
    [Parameter(Position=2)]
    [switch]$upgrade = $false
)

"engineUrl = $engineUrl"
"purgeNac = $purgeNac"
"upgrade = $upgrade"

##################################
#	Dot Source external files
##################################
$scriptPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$nexusFunctions = Join-Path $scriptPath "\nexusFunctions.ps1"
$installLib = Join-Path $scriptPath "\InstallLib.ps1"

cd $scriptPath

## libs
. $nexusFunctions
. $installLib

#User Defined Vars
$artifactDir = ".\modules"

$workingDir = ".\working"
$moduleDir = $workingDir + "\Modules"
$NACDir =  $workingDir + "\NAC"

#clear working folder
if ( (purgeFolder($workingDir)) -ne $true )
{
    "Deployment aborted."
    return;
}

#create working directories if necessary
if ( (Test-Path ($moduleDir)) -ne $true )
{
    New-Item ($moduleDir) -type directory    
}   
if ( (Test-Path ($workingDir)) -ne $true )
{
    New-Item ($workingDir) -type directory
}

#$moduleDir = Join-Path $workingDir $moduleDir
#$NACDir = Join-Path $workingDir $NACDir

#Extract Artifacts
$files = Get-ChildItem $artifactDir -rec|where-object {!($_.psiscontainer) -and $_.name -like "*_artifacts.zip"}
foreach ($file in $files)
{   
    [string]::format("Processing file {0}", $file.fullname)    
    $extractPath = (Join-Path $file.directory.fullname ($file.name -replace $file.extension, ""))
    unzip $file.fullname $extractPath
    
    $artfiles = Get-ChildItem $extractPath -rec|where-object {!($_.psiscontainer)}
    foreach ($artfile in $artfiles)    
    {
        if ( $artfile.name -like "*_dependencies.zip")
        {
            $artextractPath = (Join-Path $NACDir ($file.name -replace $file.extension, ""))
        }
        else
        {        
            $artextractPath = (Join-Path $moduleDir ($file.name -replace $file.extension, ""))
        }
        
        [string]::format("Extracting file {0} to {1}", $file.fullname, $artextractPath)
        unzip $artfile.fullname $artextractPath
    }
}

#determine engine version
$engineVersion = (Get-NexusEngineStatus $engineUrl).Version
$useFileVersion = (($engineVersion.Major -eq 4 -or $engineVersion.Major -eq 5 -or ($engineVersion.Major -le 3 -and $engineVersion.Minor -le 3)) -eq $false)

#get assembly cache list
$asmList = Get-NexusAsmCacheInfo $engineUrl

#Upload NAC
$files = Get-ChildItem $NACDir -rec|where-object {!($_.psiscontainer) -and $_.name -like "*.dll"}
foreach ($file in $files)
{
    $dll = [system.reflection.assembly]::loadfile($file.fullname)
    $name = $dll.GetName().Name
    $asmVersion = $dll.GetName().Version.ToString()

    if ($useFileVersion)
    {
        $fileVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($file.fullname).FileVersion
        if (Get-NexusAsmCacheInfo $engineUrl | where {$_.name -eq $name -and $_.version -eq $fileVersion })
        {
            #Exact file version already in engine - move along
            continue
        }
    } 
    else 
    {
        $findAsm = $asmList | Where-Object{$_.Name -eq $name -and $_.Version -eq $asmVersion}
        if ( $findAsm -ne $null)
        {
            if ( $purgeNac -eq $true )
            {
                #remove it before uploading it
                "Removing " + $findAsm.Name + " " + $findAsm.Version
                remove-nexusasmcache $engineUrl $findAsm.AssemblyId -force $true
            } else {
                #Skip it - it's already there and we're not purging
                continue
            }
        }
    }

	[string]::format("Uploading file {0} to NAC.", $file.fullname)
	add-nexusasmcache $engineurl $file.fullname
}

#Upload Modules
"Uploading Assemblies."
UploadModules -engineUrl $engineUrl `
-modulePath $moduleDir


##################################
# OPTIONAL: Update instances to 
#  lastest version of modules.
##################################
# Standard Names:
# GenericTransformer
# MPIWriter
# DeliveryPreferencesRouter
# Validator
# HL7Receiver
# Translator
# WorklistWriter
# MedicityDatabaseParser
##################################
if ($upgrade)
{
    UpgradeInstances -engineUrl $engineUrl `
    	-moduleName "Translator" 
    	
    UpgradeInstances -engineUrl $engineUrl `
    	-moduleName "Transformer" 

    UpgradeInstances -engineUrl $engineUrl `
    	-moduleName "CDRWriter" 
    	
    UpgradeInstances -engineUrl $engineUrl `
    	-moduleName "HL7MimeTypeConverter" 
    	
    UpgradeInstances -engineUrl $engineUrl `
    	-moduleName "AmbulatoryMedsQueryRouter" 
    	
    UpgradeInstances -engineUrl $engineUrl `
    	-moduleName "IDEnricher" 

    UpgradeInstances -engineUrl $engineUrl `
    	-moduleName "IndexWriter" 

    UpgradeInstances -engineUrl $engineUrl `
    	-moduleName "MComSender" 

    UpgradeInstances -engineUrl $engineUrl `
    	-moduleName "DeliveryPreferencesRouter" 
    	
    UpgradeInstances -engineUrl $engineUrl `
    	-moduleName "WorkListEventWriter" 
    	
    UpgradeInstances -engineUrl $engineUrl `
    	-moduleName "HL7Receiver" `
        -instanceName "CCADTNewReceiver"

    UpgradeInstances -engineUrl $engineUrl `
    	-moduleName "PhinMsReceiver"

    UpgradeInstances -engineUrl $engineUrl `
    	-moduleName "PhinMsSender"

    UpgradeInstances -engineUrl $engineUrl `
    	-moduleName "MedicityDatabaseParser"

    UpgradeInstances -engineUrl $engineUrl `
    	-moduleName "MPIWriter"

    UpgradeInstances -engineUrl $engineUrl `
    	-moduleName "DeliveryPreferencesRouter"

    UpgradeInstances -engineUrl $engineUrl `
    	-moduleName "WorklistWriter"
}
