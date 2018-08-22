param(
    [Parameter(Position=0)]
    [string]$engineUrl = "tcp://localhost:2048/EngineController",
    [Parameter(Position=1)]
    [switch]$purgeNac = $true,
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

#determine engine version
$engineVersion = (Get-NexusEngineStatus $engineUrl).Version
""
"**************************"
[string]::format("Engine version is {0}", $engineVersion)    
"**************************"
""

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
if ( (Test-Path ($workingDir)) -ne $true )
{
    New-Item ($workingDir) -type directory 2>&1>$null

}
if ( (Test-Path ($moduleDir)) -ne $true )
{
    New-Item ($moduleDir) -type directory 2>&1>$null
   
}   

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
        
        [string]::format("Extracting file {0} to {1}", $artfile.fullname, $artextractPath)
        unzip $artfile.fullname $artextractPath
    }
}

$useFileVersion = (($engineVersion.Major -eq 4 -or $engineVersion.Major -eq 5 -or ($engineVersion.Major -le 3 -and $engineVersion.Minor -le 3)) -eq $false)

#get assembly cache list
$asmList = Get-NexusAsmCacheInfo $engineUrl

#Upload NAC
""
"** Uploading NAC **"
$files = Get-ChildItem $NACDir -rec|where-object {!($_.psiscontainer) -and $_.name -like "*.dll"}
foreach ($file in $files)
{
    $dll = [System.Reflection.AssemblyName]::GetAssemblyName($file.fullname);
    $name = $dll.Name
    $asmVersion = $dll.Version.ToString()

    if ($useFileVersion)
    {
        $fileVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($file.fullname).FileVersion
        if (Get-NexusAsmCacheInfo $engineUrl | where {$_.name -eq $name -and $_.version -eq $fileVersion })
        {
            #Exact file version already in engine - move along
            [string]::format("Skipping NAC {0} v{1} - already loaded", $file.fullname, $fileVersion)
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
                [string]::format("Removing NAC {0} v{1}", $findAsm.Name, $findAsm.Version)
                remove-nexusasmcache $engineUrl $findAsm.AssemblyId -force $true
            } else {
                #Skip it - it's already there and we're not purging
                [string]::format("Skipping NAC {0} v{1} - already loaded", $file.fullname, $findAsm.Version)
                continue
            }
        }
    }

	[string]::format("Uploading file {0} to NAC.", $file.fullname)
	add-nexusasmcache $engineurl $file.fullname
}

#Upload Modules
""
"**Uploading Assemblies **"
UploadModules -engineUrl $engineUrl -modulePath $moduleDir


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
