# make sure we have the nexus management snapin loaded
#if( (get-pssnapin | where-object { $_.Name -eq "NexusManagement" }) -eq $null )
#{
#	add-pssnapin "NexusManagement"
#}

function WaitForState ( [string] $engineurl, [string] $iname, [string] $state, [int] $timeoutms )
{	
	$end = [DateTime]::Now.AddMilliseconds($timeoutms);

	while( $true )
	{
		$ii = get-nexusinstance $engineurl $iname

		if( $ii.State -eq $state )
		{
			return $true;
		}
		[System.Threading.Thread]::Sleep(1000)

		if( [DateTime]::Now -gt $end )
		{
			throw [string]::Format("Timeout waiting for state: {0}.", $iname);
		}
	}
		
}

function UploadModules()
{
    param (
		[string] $engineUrl = $(throw "You must specify an engine url.")
		,[string] $modulePath = ".\modules"
	)
    
	$files = Get-ChildItem $modulePath -rec|where-object {!($_.psiscontainer) -and $_.name -like "*.dll"}
	if ( $files.length -lt 1 )
	{
		[string]::format("No modules found in folder {0}", $modulePath)
		return
	}
	
	foreach ($file in $files)
	{   
		[string]::format("Uploading file {0}", $file.fullname)
		add-nexusassembly $engineurl $file.fullname
		
	}
}

function UploadNAC()
{
    param (
		[string] $engineUrl = $(throw "You must specify an engine url.")
		,[string] $filePath = ".\NAC"
	)
    
	$files = Get-ChildItem $filePath -rec|where-object {!($_.psiscontainer) -and $_.name -like "*.dll"}
	if ( $files.length -lt 1 )
	{
		[string]::format("No dll files found in folder {0}", $filePath)
		return
	}
	
	foreach ($file in $files)
	{   
		[string]::format("Uploading file {0} to NAC.", $file.fullname)
		add-nexusasmcache $engineurl $file.fullname
		
	}
}

function UpgradeInstances()
{
	param (
		[string] $engineUrl = $(throw "You must specify an engine url.")
		,[string] $moduleName = $(throw "You must specify a module name.")
		,[string] $moduleVersion = ""
		,[string] $instanceNameFilter = ""		
	)
	
	##################################
	# Upgrade instances
	##################################	

	$moduleName = $moduleName.Trim()
	if ( $moduleVersion -eq "" )
	{
		$newestMod = get-nexusmodinfo $engineurl | where-object { $_.Name -like $moduleName } | sort-object Version -Descending | select-object -first 1
	}
	else
	{		
		$newestMod = get-nexusmodinfo $engineurl | where-object { $_.Name -like $moduleName  -and $_.Version -eq [Version]$moduleVersion } | select-object -first 1
	}
	
	
	if ( $newestMod -ne $null )
	{
		[string]::format("Newest Module: {0} Version: {1}.", $newestMod.Name, $newestMod.Version.ToString())
				
		if ( $instanceNameFilter -eq "" )
		{
			$instances  = get-nexusinstance $engineurl | where-object { $_.ModuleName -like $moduleName -and $_.ModuleVersion -ne $newestMod.Version }
		}
		else
		{
			$instances  = get-nexusinstance $engineurl | where-object { $_.Name -like $instanceNameFilter -and $_.ModuleName -like $moduleName -and $_.ModuleVersion -ne $newestMod.Version }
		}
		
		if( $instances -ne $null )
		{
			if ( $instances.length -ne $null )
			{
				[string]::format("{0} instances found for Module: {1}.", $instances.length.ToString(), $newestMod.Name)
			}
			else
			{
				[string]::format("1 instance found for Module: {0}.", $newestMod.Name)
			}
			
			foreach( $instance in $instances )		
			{
				[string]::format("Upgrading Instance {0} from module {1}({2}) to {3}({4}) ", $instance.Name, $instance.ModuleName, $instance.ModuleVersion.ToString(), $newestMod.Name, $newestMod.Version.ToString())
				$started = $FALSE
				
				if( $instance.state -ne "Stopped" -and $instance.state -ne "Uninitialized" )
				{
					$started = $TRUE
					"Stopping..."
					stop-nexusinstance $engineurl $instance.Name
					if ( (WaitForState $engineurl $instance.Name "Stopped" 30000) -eq $false )
					{
						continue
					}
					
				}
				if( $instance.state -ne "Uninitialized" )
				{
					"Unloading..."
					unload-nexusinstance $engineurl $instance.Name
				}
				
				"Performing upgrade..."
				upgrade-nexusinstance $engineurl $instance.Name $newestMod.Version
				
				"Loading..."
				load-nexusinstance $engineurl $instance.Name
				if ( $started -eq $TRUE )
				{
					"Starting..."
					start-nexusinstance $engineurl $instance.Name
				}					
			}
		
		}
		else
		{
			"No instances found to upgrade."				
		}
	}
	else
	{
		[string]::format("Module: {0} not found!", $moduleName)
	}
	
}

function ReloadInstances()
{
	param (
		[string] $engineUrl = $(throw "You must specify an engine url.")
		,[string] $moduleName = $(throw "You must specify a module name.")
		,[string] $moduleVersion = ""
		,[string] $instanceNameFilter = ""		
	)
	
	$moduleName = $moduleName.Trim()
	
				
		if ( $instanceNameFilter -eq "" )
		{
			if ( $moduleVersion -eq "" )
			{
				[string]::format("Module: {0}.", $moduleName)
				$instances  = get-nexusinstance $engineurl | where-object { $_.ModuleName -eq $moduleName }
			}
			else
			{
				[string]::format("Module: {0} Version: {1}.", $moduleName, $moduleVersion)
				$instances  = get-nexusinstance $engineurl | where-object { $_.ModuleName -eq $moduleName -and $_.ModuleVersion -eq [Version]$moduleVersion }
			}
		}
		else
		{
			if ( $moduleVersion -eq "" )
			{
				[string]::format("Module: {0}.", $moduleName)
				$instances  = get-nexusinstance $engineurl | where-object { $_.Name -like $instanceNameFilter -and $_.ModuleName -eq $moduleName }
			}
			else
			{
				[string]::format("Module: {0} Version: {1}.", $moduleName, $moduleVersion)
				$instances  = get-nexusinstance $engineurl | where-object { $_.Name -like $instanceNameFilter -and $_.ModuleName -eq $moduleName -and $_.ModuleVersion -eq [Version]$moduleVersion }
			}
		}
		
		if( $instances -ne $null )
		{
			if ( $instances.length -ne $null )
			{
				[string]::format("{0} instances found for Module: {1}.", $instances.length.ToString(), $moduleName)
			}
			else
			{
				[string]::format("1 instance found for Module: {0}.", $moduleName)
			}
			
			foreach( $instance in $instances )		
			{
				[string]::format("Reloading Instance {0} ", $instance.Name)
				$started = $FALSE
				
				if( $instance.state -ne "Stopped" -and $instance.state -ne "Uninitialized" )
				{
					$started = $TRUE
					
				}

				"Unloading..."
				unload-nexusinstance $engineurl $instance.Name
								
				"Loading..."
				load-nexusinstance $engineurl $instance.Name
				if ( $started -eq $TRUE )
				{
					"Starting..."
					start-nexusinstance $engineurl $instance.Name
				}					
			}
		
		}
		else
		{
			"No instances found to upgrade."				
		}

}

function UnloadInstances()
{
	param (
		[string] $engineUrl = $(throw "You must specify an engine url.")
		,[string] $moduleName = $(throw "You must specify a module name.")
		,[string] $moduleVersion = ""
		,[string] $instanceNameFilter = ""		
	)
	
	$moduleName = $moduleName.Trim()
	
				
		if ( $instanceNameFilter -eq "" )
		{
			if ( $moduleVersion -eq "" )
			{
				[string]::format("Module: {0}.", $moduleName)
				$instances  = get-nexusinstance $engineurl | where-object { $_.ModuleName -eq $moduleName }
			}
			else
			{
				[string]::format("Module: {0} Version: {1}.", $moduleName, $moduleVersion)
				$instances  = get-nexusinstance $engineurl | where-object { $_.ModuleName -eq $moduleName -and $_.ModuleVersion -eq [Version]$moduleVersion }
			}
		}
		else
		{
			if ( $moduleVersion -eq "" )
			{
				[string]::format("Module: {0}.", $moduleName)
				$instances  = get-nexusinstance $engineurl | where-object { $_.Name -like $instanceNameFilter -and $_.ModuleName -eq $moduleName }
			}
			else
			{
				[string]::format("Module: {0} Version: {1}.", $moduleName, $moduleVersion)
				$instances  = get-nexusinstance $engineurl | where-object { $_.Name -like $instanceNameFilter -and $_.ModuleName -eq $moduleName -and $_.ModuleVersion -eq [Version]$moduleVersion }
			}
		}
		
		if( $instances -ne $null )
		{
			if ( $instances.length -ne $null )
			{
				[string]::format("{0} instances found for Module: {1}.", $instances.length.ToString(), $moduleName)
			}
			else
			{
				[string]::format("1 instance found for Module: {0}.", $moduleName)
			}
			
			foreach( $instance in $instances )		
			{
				[string]::format("Reloading Instance {0} ", $instance.Name)
				$started = $FALSE
				
				if( $instance.state -ne "Stopped" -and $instance.state -ne "Uninitialized" )
				{
					$started = $TRUE
					
				}

				"Unloading..."
				unload-nexusinstance $engineurl $instance.Name
								
			}
		
		}
		else
		{
			"No instances found to upgrade."				
		}

}


function Format-XML ([xml]$xml, $indent=2)
{
    $StringWriter = New-Object System.IO.StringWriter
    $XmlWriter = New-Object System.XMl.XmlTextWriter $StringWriter
    $xmlWriter.Formatting = "indented"
    $xmlWriter.Indentation = $Indent
    $xml.WriteContentTo($XmlWriter)
    $XmlWriter.Flush()
    $StringWriter.Flush()
    Write-Output $StringWriter.ToString()
}

function UpdateInstanceConfig()
{
	param (
		[string] $engineUrl = $(throw "You must specify an engine url.")
		,[string] $instanceName = $(throw "You must specify an instance name.")
		,$xmlConfigFile = ""
		,[xml]$xmlConfigContent = $null
	)
	
	if ( $xmlConfigFile -eq "" -and !$xmlConfigContent )
	{
		throw("xmlConfig file or content must be specified.")
	}
	
	$instConfig = Get-NexusInstanceConfig $engineUrl $instanceName
	
	if ( !$instConfig ) 
	{
		Write-Host [string]::format("Instance: {0} not found!", $instanceName) -ForegroundColor White -BackgroundColor Red
		return
	}

	#read content of file if supplied
	if ( $xmlConfigFile -ne "" )
	{
		$xmlConfigContent = [xml](Get-Content $xmlConfigFile)
	}
	
	"Saving instance configuration..."	
	$instConfig.Configuration = Format-XML $xmlConfigContent
	Set-NexusInstanceConfig $engineUrl $instanceName $instConfig
}

function SaveInstanceConfig()
{
	param (
		[string] $engineUrl = $(throw "You must specify an engine url.")
		,[string] $instanceName = $(throw "You must specify an instance name.")
		,$outputFile  = $(throw "You must specify an output file.")
	)
	
	$instConfig = Get-NexusInstanceConfig $engineUrl $instanceName
	
	if ( !$instConfig ) 
	{
		$msg = [string]::format("Instance: {0} not found!", $instanceName)
		Write-Host $msg -ForegroundColor White -BackgroundColor Red
		return
	}

	"Saving instance configuration content to file..."	
	$instConfig.Configuration | Out-File -filepath $outputFile
}

function GetInstanceConfigFiles
{
	param (
		[string] $engineUrl = $(throw "You must specify an engine url.")
		,[string] $outPath = $(throw "You must specify an output path.")
		,[string] $instanceFilter = ""
        ,$overwrite = $False
    )
    
    # Create directory if doesn't exist
    if ( !(Test-Path -path $outPath) )
    {
        New-Item $outPath -type directory
    }
    elseif ( !($overwrite) )
    {
            throw "Directory already exists!"
            return
    }

    if ( $instanceFilter -ne "" )
    {
        $instances = Get-NexusInstance $engineurl | Where-Object { $_.Name -like $instanceFilter }
    }
    else
    {
        #Get every instance
        $instances = Get-NexusInstance $engineurl #| Where-Object { $_.ModuleName -eq "Validator" -and ( $_.Name -like "CC*" -or $_.Name -like "CTY*" ) }
    }

    foreach ( $instance in $instances )
    {
    	$fileName = $instance.Name + ".xml"
    	$outFile = Join-Path $outPath $fileName
    	
    	$instance.Name + ">>" + $outFile
    	
    	SaveInstanceConfig -engineUrl $engineUrl -instanceName $instance.Name -outputFile $outFile
    }

	
}


#Receiver
function ReceiverConfig()
{
	param (
		[string] $engineUrl
		,[string] $instanceName
		,$configKeys = @{}
	)
	
	$instConfig = Get-NexusInstanceConfig $engineUrl $instanceName
	$xml = [xml]$instConfig.Configuration
	$root = $xml.get_DocumentElement()
	
	#get the receiver node
	$node = $root.SelectSingleNode("Section[@Name = ""Receiver""]")
	
	foreach ( $configKey in $configKeys.keys )
	{
		"Set Key $configKey = " + $configKeys[$configKey]
		
		$node.SelectSingleNode("Key[@Name = """ + $configKey + """]").innertext = $configKeys[$configKey]
	}

	"Saving instance configuration..."	
	$instConfig.Configuration = Format-XML $xml
	Set-NexusInstanceConfig $engineUrl $instanceName $instConfig
}