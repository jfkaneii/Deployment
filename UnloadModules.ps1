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

#UnloadInstances -engineUrl $engineUrl `
#	-moduleName "Translator"
    
#Remove-NexusAssembly $engineUrl 270
#ReloadInstances -engineUrl $engineUrl `
#	-moduleName "Translator"

ReloadInstances -engineUrl $engineUrl `
	-moduleName "CDRWriter"
