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
$engineUrl = "tcp://slc-med-app5:12100/EngineController"

UpgradeInstances -engineUrl $engineUrl `
	-moduleName "CoreMOdules" `
    -moduleVersion "3.1.1.4"