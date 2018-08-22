param(
    [Parameter(Mandatory=$true,Position=0)]
    [ValidateNotNullOrEmpty()]
    [string]$modName,    # name of the assembly (the primary .dll)
    [Parameter(Position=1)]
    [string]$deployDir = "C:\Medicity\Deployment"    # location of InstallLib.ps1 file
)

$highlightFgColor = "green"
$errorFgColor = "Red"

function Write-Highlight {
    param([string]$text = "")
    Write-Text $text $highlightFgColor
}

function Write-Text {
    param([string]$text = "",
        [string]$fgc = "white",
        [string]$bgc = "darkblue")
    Write-Host $text -ForegroundColor $fgc -BackgroundColor $bgc
}

""
"******************************"
"BUILD DEPLOYMENT ARTIFACT FILE"
"******************************"
"modName (name of the assembly, without the dll) = $modName"
"deployDir (location of InstallLib.ps1 file) = $deployDir"
""

##################################
#	Dot Source external file for 7zip
##################################
$installLib = Join-Path $deployDir "\InstallLib.ps1"

## libs
. $installLib

##################################
#	set paths
##################################
$directoryPath = (Resolve-Path .\)
$zipDir = $directoryPath
$binPath = $directorypath, $modName, "bin\debug" -join "\"

"binPath (path to module dll) = $binPath"
"zipDir (name of the directory where the deployment zip file will go) = $zipDir"
""

$dllFileVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo("$binPath\$modName.dll").FileVersion

## name zip files to be used
$zipFileMod = $modName + ".zip" ## Module.zip
$zipFileDep = $modName + "_dependencies.zip" ## Module_dependencies.zip
$zipFileArt = $modName + "_" + $dllFileVersion + "_artifacts.zip" ## Module_artifacts.zip

## remove zip files to be created
Remove-Item –path $zipFileMod 2>&1 > $null
Remove-Item –path $zipFileDep 2>&1 > $null
Remove-Item –path $zipFileArt 2>&1 > $null

## construct filter for separating files into Module and Module_dependencies zips
$modFilter = @("$modName.dll","$modName.pdb")

## Module.zip
$bak = Get-ChildItem -Recurse -Path $binPath -Include $modFilter `
    | where {($_.name -like "*.dll") -or ($_.name -like "*.pdb") } `

""
Write-Highlight "vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv"
Write-Highlight ">> building $zipFileMod..."
foreach ($file in $bak) {
					$name = $file.name
                    "adding $binPath\$name"
					sz a -tzip "$zipFileMod" "$binPath\$name" > $null
				}
Write-Highlight ">>   ...completed $zipFileMod"
Write-Highlight "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"

## Module_dependencies.zip			}
$bak = Get-ChildItem -Recurse -Path $binPath  -Exclude $modFilter `
    | where {($_.name -like "*.dll") -or ($_.name -like "*.pdb") } `
    | where {$_.name -notlike "*NexusEngine.Domains.Modules*"}
$zipFileDep = $modName + "_dependencies.zip"

""
""
Write-Highlight "vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv"
Write-Highlight ">> building $zipFileDep..."
foreach ($file in $bak) {
					$name = $file.name
                    "adding $binPath\$name"
					sz a -tzip "$zipFileDep" "$binPath\$name" > $null	
				}
Write-Highlight ">>   ...completed $zipFileDep"
Write-Highlight "vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv"

## Module_artifacts.zip			}
$zipFileArt = $modName + "_" + $dllFileVersion + "_artifacts.zip"

""
""
Write-Highlight "********************************************************************************"
Write-Highlight ">> building $zipFileArt..."
foreach ($name in $zipFileMod, $zipFileDep) {
                    "adding $binPath\$name"
					sz a -tzip $zipFileArt $zipDir\$name > $null	
                    Remove-Item –path $zipDir\$name 2>&1 > $null
				}
Write-Highlight ">>   ...completed $zipFileArt"

Write-Highlight "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
""
Write-Highlight "Archive file: $directoryPath\$zipFileArt"
""
""
