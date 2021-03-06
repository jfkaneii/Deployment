$scriptPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

if (-not (test-path "$scriptPath\7za.exe")) {throw "$scriptPath\7za.exe needed"}
set-alias sz "$scriptPath\7za.exe"

function purgeFolder
{
    param (
        [string]$purgeFolder
    )
    
    $caption = "Purge folder?";
    $message = "You are about to delete all files and folders in $purgeFolder, are you sure?";
    $yes = new-Object System.Management.Automation.Host.ChoiceDescription "&Yes","help";
    $no = new-Object System.Management.Automation.Host.ChoiceDescription "&No","help";
    $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes,$no);
    $answer = $host.ui.PromptForChoice($caption,$message,$choices,0)
    
    $return = $false;
    switch ($answer){
        0 {get-childitem $purgeFolder -recurse | remove-item  -recurse -force; $return = $true; break}
        1 {break;}
    }
    
    $return
}

function unzip()
{
    param (
        [string]$file,
        [string]$outputDir = ''
    )

    if (-not (Test-Path $file)) {
        $file = Resolve-Path $file
    }

    if ($outputDir -eq '') {
        $outputDir = [System.IO.Path]::GetFileNameWithoutExtension($file)
    }

    sz x -y $file "-o$outputDir"

}

function zip()
{
    param (
        [string]$file,
        [string]$path = ''
    )

    sz a -tzip $file $path

}

function Get-PSCredential {
    param (
        [string]$credentialFile = ""
    )
    
    if ( $credentialFile -eq "" )
    {
        $cred = Get-Credential
    }
    else
    {
        #$credentialFile = Join-Path $scriptPath $credentialFileName
        if ( !(Test-Path $credentialFile) )
        {
            Export-PSCredential -path $credentialFile
        }

        $cred = Import-PSCredential -path $credentialFile
    }
    
    $cred
}

function Export-PSCredential {
	param ( $Credential = (Get-Credential), $Path = "credentials.enc.xml" )

	# Look at the object type of the $Credential parameter to determine how to handle it
	switch ( $Credential.GetType().Name ) {
		# It is a credential, so continue
		PSCredential		{ continue }
		# It is a string, so use that as the username and prompt for the password
		String				{ $Credential = Get-Credential -credential $Credential }
		# In all other caess, throw an error and exit
		default				{ Throw "You must specify a credential object to export to disk." }
	}
	
	# Create temporary object to be serialized to disk
	$export = "" | Select-Object Username, EncryptedPassword
	
	# Give object a type name which can be identified later
	$export.PSObject.TypeNames.Insert(0,’ExportedPSCredential’)
	
	$export.Username = $Credential.Username

	# Encrypt SecureString password using Data Protection API
	# Only the current user account can decrypt this cipher
	$export.EncryptedPassword = $Credential.Password | ConvertFrom-SecureString

	# Export using the Export-Clixml cmdlet
	$export | Export-Clixml $Path
	Write-Host -foregroundcolor Green "Credentials saved to: " -noNewLine

	# Return FileInfo object referring to saved credentials
	Get-Item $Path
}

function Import-PSCredential {
	param ( $Path = "credentials.enc.xml" )

	# Import credential file
	$import = Import-Clixml $Path 
	
	# Test for valid import
	if ( !$import.UserName -or !$import.EncryptedPassword ) {
		Throw "Input is not a valid ExportedPSCredential object, exiting."
	}
	$Username = $import.Username
	
	# Decrypt the password and store as a SecureString object for safekeeping
	$SecurePass = $import.EncryptedPassword | ConvertTo-SecureString
	
	# Build the new credential object
	$Credential = New-Object System.Management.Automation.PSCredential $Username, $SecurePass
	Write-Output $Credential
}

function Deploy-Archive {

    param(
        [string]$zipFile = $(throw "ZipFile parameter is required.")
        ,[string]$deployPath = $(throw "DeploymentPath parameter is required.")
        ,[string]$artifacts = ""
        #,[string]$artifactDeployPath = ""
        ,[string]$backupZipPath = ""
        ,[switch]$cleanInstall = $false
    )
    
    
    #backup
    if ( $backupZipPath -ne "" )
    {
        #TODO: Cleanup older archives
        $backupZipFile = Join-Path $backupZipPath ((Get-Item $deployPath).Name + "_backup_" + ((Get-Date).tostring("yyyyMMdd-hhmmss")) + ".zip")   
        Write-Host "Backing up deploy path:" $deployPath " to " $backupZipFile -foregroundcolor White -BackgroundColor Green
        zip -file $backupZipFile -path ( Join-path $deployPath "*" )
    }
    
    #delete existing files
    if ( $cleanInstall )
    {
        Write-Host "Cleaning deploy path:" $deployPath  -foregroundcolor White -BackgroundColor Red
        #$configFiles = "AppConfigs.config", "ConnectionStrings.config", "Endpoints.config"
        #Get-ChildItem -path $PA5Path -recurse | Where-Object { $configFiles -notcontains ($_.Name) -and !($_.Name -eq 'AppConfiguration' -and $_.psIsContainer) } | Remove-Item -whatif
        Get-ChildItem -path $deployPath -recurse | Remove-Item -recurse
    }
    
    #extract
    Write-Host "Extracting " $zipFile " to " $deployPath -foregroundcolor White -BackgroundColor Green
    unzip -file $zipFile -outputDir $deployPath

    #copy artifacts
    if ( $artifacts -ne "" -and ( Test-Path $artifacts ) )
    {
        if ( $artifacts.EndsWith(".zip") )
        {
            Write-Host "Extracting artifact zip " $artifacts " to " $deployPath -foregroundcolor White -BackgroundColor Green
            unzip -file $artifacts -outputDir $deployPath
        }
        else
        {
            Write-Host "Copying artifacts from " $artifacts " to " $deployPath -foregroundcolor White -BackgroundColor Green
            Copy-Item ( Join-Path $artifacts "\*" ) -destination $deployPath -recurse
        }
    }
}

function StopServiceDelay()
{
    param ( 
        $srvc = $(throw "Service required.") 
        , $delayTime = 30
    )
    
    if ( $srvc )
    {
        if ( $srvc.status -ne "stopped" )
        {
            Write-Host "Stopping service " $srvc.Name "..." -foregroundcolor White -BackgroundColor Green
            $srvc.Stop()
            $srvc.WaitForStatus(”Stopped”, (new-timespan -minutes 5))
            Start-Sleep -s $delayTime
            Write-Host "Service " $srvc.Name " status is " $srvc.status -foregroundcolor Black -BackgroundColor Yellow
        }        
    }
}