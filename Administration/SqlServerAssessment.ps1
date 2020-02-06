Import-Module SqlServer

# Confirm the SqlServer module is installed and is the correct version.
$module = Get-Module SqlServer
if ($null -eq $module) {
    Write-Error "SqlServer module is not installed. Script exiting."
    exit
} elseif ($module.Version.Major -lt 22 -and $module.Version.Minor -lt 2 -and $module.Version.Build -lt 18147) {
    Write-Error "SqlServer module version must be at least 21.1.18147. Script exiting."
    exit
}

# Prompt for and validate the location where the assessment results will be exported to.
$path = Read-Host -Prompt "Provide the export directory location"
while ($null -eq $path -or -not (Test-Path $path)) {
	Write-Host "Invalid export directory path, please try again. Alternatively, type `"exit`" to abort script execution."
	$path = Read-Host -Prompt "Provide the export directory location"
	if ($path -ieq "EXIT") {
		exit
	}
}

if (-not ($path -match "\\$")) {
	$path = $path + "\"
}

# Prompt for the use of SQL Server credentials instead of Windows credentials (current user).
$prompt = $false
$promptForSqlCreds = Read-Host -Prompt "By default this script attempts to access the local SQL Server instances using the current user credentials. Alternatively, SQL credentials can be prompted for on a per instance basis. Prompt for SQL credentials? (Y/N)"
if ($promptForSqlCreds -ieq "Y" -or $promptForSqlCreds -ieq "YES") {
	$prompt = $true
}

# Create the directories for holding database assessments if they don't already exist.
$vulnDirectory = "\DbVulnAssessment\"
$generalDirectory = "\DbGeneralAssessment\"

try {
	if (-not (Test-Path ($path + $vulnDirectory))) {
		New-Item -ItemType Directory -Path ($path + $vulnDirectory) -ErrorAction Stop | Out-Null
	}
	
	if (-not (Test-Path ($path + $generalDirectory))) {
		New-Item -ItemType Directory -Path ($path + $generalDirectory) -ErrorAction Stop | Out-Null
	}
} catch {
	Write-Host "Unable to create scan result subdirectories. Script exiting."
	Write-Host $_
}

# Prompt to determine whether all instances or only a single instance should be scanned.
$userInstance = $null
$scanAll = $true
$promptForScanAll = Read-Host -Prompt "By default this script will scan all instances on the local machine. Scan all instances?  (Y/N)"
if ($promptForScanAll -ieq "N" -or $promptForScanAll -ieq "NO") {
	$scanAll = $false
	Get-ChildItem -Path "SQLSERVER:\SQL\$env:COMPUTERNAME"
	while ($null -eq $userInstance) {
		$instanceName = Read-Host -Prompt "Input the name of the instance to scan"
		if ($instanceName -ieq "EXIT") {
			exit
		} elseif ($instanceName -ieq "DEFAULT") {
			$instanceName = $env:COMPUTERNAME
		} else {
			$instanceName = $env:COMPUTERNAME + "\" + $instanceName
		}

		$userInstance = Get-SqlInstance -ServerInstance $instanceName -ErrorAction Ignore
		if ($null -eq $userInstance) {
			Write-Host ("Instance " + $instanceName + " not found, please try again. Alternatively, type `"exit`" to abort script execution.")
		}
	}
}

# Determine the proper scan collection based on user options.
$instances = $null
if ($scanAll) {
	$instances = Get-ChildItem -Path "SQLSERVER:\SQL\$env:COMPUTERNAME"
} else {
	$instances = $userInstance
}

if ($null -eq $instances) {
	Write-Host "No instances found/scanned. Either an error was encountered or no instances were found during script execution when the option to scan all instances was chosen."
	exit
}

# Perform general and vulnerability scans for all/select SQL Server instances and databases on the currrent machine.
$instances | ForEach-Object {
	$instance = Get-SqlInstance $_

	$instanceCreds = $null
	if ($prompt) {
		$instanceCreds = Get-Credential -Message ("Provide the SQL Server credentials for the following instance: " + $instance.Name)
	}
	
	# Instance scan
	try {
		Write-Host ("Executing general assessment scan for instance: " + $instance.InstanceName)
		$instance | Invoke-SqlAssessment -ErrorAction Stop | Out-File -FilePath ($path + $instance.InstanceName + "_GeneralAssessment.txt") -ErrorAction Stop
	}
	catch {
		Write-Host ("Scan execution failed for instance: " + $instance.InstanceName)
		Write-Host $_
		continue
	}

	# Database scans
	Get-SqlDatabase -ServerInstance $instance.Name | ForEach-Object {
		try {
			Write-Host ("Executing general assessment scan for database: " + $instance.InstanceName + "\" + $_.Name)
			Invoke-SqlAssessment $_ -ErrorAction Stop | Out-File -FilePath ($path + $generalDirectory + $instance.InstanceName + "_" + $_.Name + "_GeneralAssessment.txt") -ErrorAction Stop

			Write-Host ("Executing vulnerability assessment scan for database: " + $instance.InstanceName + "\" + $_.Name)
			$vulnScan = $null
			if ($prompt) {
				$vulnScan = Invoke-SqlVulnerabilityAssessmentScan -ServerInstance $instance -DatabaseName $_.Name -Credential $instanceCreds -ErrorAction Stop
			} else {
				$vulnScan = Invoke-SqlVulnerabilityAssessmentScan -ServerInstance $instance -DatabaseName $_.Name -ErrorAction Stop
			}
			$vulnScan | Export-SqlVulnerabilityAssessmentScan -FolderPath ($path + $vulnDirectory + $instance.InstanceName + "_" + $_.Name + "_VulnerabilityAssessment.xlsx") -ErrorAction Stop
		}
		catch {
			Write-Host ("Scan execution failed for database: " + $instance.InstanceName + "\" + $_.Name)
			Write-Host $_
		}
	}
}
