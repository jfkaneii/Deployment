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
UpgradeInstances -engineUrl $engineUrl `
	-moduleName "WorkListEventWriter" 


#UpgradeInstances -engineUrl $engineUrl `
#	-moduleName "Translator" `
#	-moduleVersion "1.0.11.8295"

UpgradeInstances -engineUrl $eng#ineUrl `
#	-moduleName "CDRWriter"

#UpgradeInstances -engineUrl $engineUrl `
#	-moduleName "IndexWriter"
	
#UpgradeInstances -engineUrl $engineUrl `
#	-moduleName "McomSender"	
	
#UpgradeInstances -engineUrl $engineUrl `
#	-moduleName "HL7Receiver" `
#    -instanceName "CCADTNewReceiver"

#UpgradeInstances -engineUrl $engineUrl `
#	-moduleName "PhinMsReceiver"

#UpgradeInstances -engineUrl $engineUrl `
#	-moduleName "PhinMsSender"

#UpgradeInstances -engineUrl $engineUrl `
#	-moduleName "MedicityDatabaseParser"

#UpgradeInstances -engineUrl $engineUrl `
#	-moduleName "MPIWriter"

#UpgradeInstances -engineUrl $engineUrl `
#	-moduleName "DeliveryPreferencesRouter"

#UpgradeInstances -engineUrl $engineUrl `
#	-moduleName "WorklistEventWriter"
