NOTICE: These scripts are used primarily within R&D and are not necessarily used for PRODUCTION deployment by SET.
==================================================================================================================

DeployModules.ps1 will deploy any module packages (in the form of the original zip files from the released software share) 
located in the "modules" directory. 

This version of this script supports Nexus v3.4, which has support for semantically versioned modules and dependencies. 
With this version of Nexus it is no longer necessary to use the "purgeNac" option to deploy updated packages. This
script now accepts input parameters to control which Nexus Engine to deploy the modules to as well as control optional
behavior.

Usage:
.\DeployModules.ps1 [[-engineUrl] <Uri[]>] [[-purgeNac] <Boolean> = $false] [[-upgrade] <Boolean> = $false]

-engineUrl : Specifies the url for the Nexus Engine controller for which to deploy modules to.
             This is defaulted to tcp://localhost:2048/EngineController. 

-purgeNac  : Controls whether or not the script will delete matching assembles from the NAC.
             This is defaulted to $false. This option is ignored for v3.4 of the Nexus Engine. 

-upgrade   : Controls whether or not to upgrade existing module instances to the latest version.
             This is defaulted to $false.

Examples:

.\DeployModules.ps1
  - This will execute using the default parameters

.\DeployModules.ps1 tcp://server:12000/EngineController
  - This will use the supplied engineUrl and the default values for purgeNac and upgrade.

.\DeployModules.ps1 tcp://server:12000/EngineController $true $false
  - This will use the supplied engineUrl and the supplied values for purgeNac and upgrade.

.\DeployModules.ps1 -purgeNac $true
  - This will use the default value for the engineUrl and upgrade option.


NOTE: This script will load into memory the assemblies in the package. It is HIGHLY recommended that the PowerShell
      session used to execute this command is closed before attempting to run the command subsequent times.
