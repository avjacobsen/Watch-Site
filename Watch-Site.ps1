$LogDate = "$(Get-Date -Format "yyyy")$(Get-Date -Format "MM")$(Get-Date -Format "dd")"
$ScriptName = (Get-ChildItem $PSCommandPath).BaseName
$ConfigFileName = "$ScriptName.csv"
$LogFile = "$($LogDate)_$($ScriptName).log"
function Log-Message {
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]
        $MessageType,
        [Parameter()]
        [String]
        $Message
    )
    $MessagePrefix = "$(Get-Date -Format "yyyy").$(Get-Date -Format "MM").$(Get-Date -Format "dd") $(Get-Date -Format "hh"):$(Get-Date -Format "mm"):$(Get-Date -Format "ss") "
    Add-Content -Path $LogFile -Value "$($MessagePrefix)[$($MessageType)] $($Message)"
    "$($MessagePrefix)[$($MessageType)] $($Message)"
}
Log-Message -MessageType "INFO" -Message "******************************************************************"
Log-Message -MessageType "INFO" -Message "Script Started."
Log-Message -MessageType "INFO" -Message "Checking for elevated privileges."
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Log-Message -MessageType "ERROR" -Message "This script needs to be run with elevated privileges."
    exit
}
else {
    Log-Message -MessageType "INFO" -Message "Elevated privileges detected."
}

Log-Message -MessageType "INFO" -Message "Locating config file: $($ScriptName).csv"
$TestPath = Test-Path -Path $ConfigFileName
if ($TestPath -ne $true) {
    Log-Message -MessageType "ERROR" -Message "Config file ($($ScriptName).csv) not found."
    Log-Message -MessageType "INFO" -Message "Creating default config file: $($ScriptName).csv."
    Set-Content -Path $ConfigFileName -Value "`"SiteName`",`"SiteId`",`"URI`",`"CheckURI`",`"RestartSite`""
    Add-Content -Path $ConfigFileName -Value "`"MyDummySiteName1`",`"DUMMYIDNUMBER`",`"https://my.dummy.site.name.one`",`"0`",`"0`""
}
else
{
    Log-Message -MessageType "INFO" -Message "Config file ($($ScriptName).csv) located."
}

Log-Message -MessageType "INFO" -Message "Importing config."
$SitesToWatch = Import-Csv -Path $ConfigFileName -Encoding UTF8
if ($null -eq $SitesToWatch) {
    Log-Message -MessageType "ERROR" -Message "Import failed."
}
else
{
    Log-Message -MessageType "INFO" -Message "$($SitesToWatch.Count) sites imported from config file."
}

Log-Message -MessageType "INFO" -Message "Checking if WebAdministration Module is imported."
$modules = Get-Module | Where-Object {$_.Name -eq "WebAdministration"}
if ($null -eq $modules) {
    Log-Message -MessageType "INFO" -Message "WebAdministration Module is not imported. Importing."
    Import-Module WebAdministration
}
$modules = Get-Module | Where-Object {$_.Name -eq "WebAdministration"}
if ($null -eq $modules) {
    Log-Message -MessageType "ERROR" -Message "WebAdministration Module cannot be imported."
    exit
}
if ($modules.Name -eq "WebAdministration") {
    Log-Message -MessageType "INFO" -Message "WebAdministration Module imported."
}

Log-Message -MessageType "INFO" -Message "Importing websites from IIS."
$IISWebsites = Get-Website | select *
if ($null -eq $IISWebsites) {
    Log-Message -MessageType "ERROR" -Message "No IIS websites found."
}
else {
    Log-Message -MessageType "INFO" -Message "$($IISWebsites.Count) IIS websites found."
}
foreach ($SiteToWatch in $SitesToWatch) {
    if ($SiteToWatch.CheckURI -eq "1") {
        Log-Message -MessageType "INFO" -Message "Checking site id $($SiteToWatch.SiteId)"
        $IISWebsite = $IISWebsites | Where-Object { $_.id -eq $($SiteToWatch.SiteId) }
        if ($null -eq $IISWebsite) {
            Log-Message -MessageType "ERROR" -Message "No IIS Website found with site id $($SiteToWatch.SiteId)."
        }
        else {
            Log-Message -MessageType "INFO" -Message "Found IIS Website with site id $($SiteToWatch.SiteId). Checking site names for match."
            if ($IISWebsite.Name -ne $SiteToWatch.SiteName) {
                Log-Message -MessageType "ERROR" -Message "Sites names do not match: $($SiteToWatch.SiteName) != $($IISWebsite.Name)"
            }
            else {
                Log-Message -MessageType "INFO" -Message "Sites names match: $($SiteToWatch.SiteName) = $($IISWebsite.Name)"
                Log-Message -MessageType "INFO" -Message "IIS Site id $($IISWebsite.id): name:$($IISWebsite.name), serverAutoStart:$($IISWebsite.serverAutoStart), state:$($IISWebsite.state)"
                Log-Message -MessageType "INFO" -Message "IIS Site id $($IISWebsite.id): Checking url: $($SiteToWatch.URI)"
                # Need to reset the variable because Invoke-WebRequest failures don't return anything, not even null.
                $SiteURIStatus = $null
                $SiteURIStatus = Invoke-WebRequest -UseBasicParsing -Uri $SiteToWatch.URI
                if ($SiteURIStatus.StatusCode -eq "200") {
                    Log-Message -MessageType "INFO" -Message "IIS Site id $($IISWebsite.id): StatusCode $($SiteURIStatus.StatusCode) $($SiteURIStatus.StatusDescription)."
                }
                else {
                    Log-Message -MessageType "ERROR" -Message "IIS Site id $($IISWebsite.id): StatusCode not 200."
                    if ($SiteToWatch.RestartSite -eq "1") {
                        Log-Message -MessageType "INFO" -Message "IIS Site id $($IISWebsite.id): Site is set to restart."
                        if ($IISWebsite.state -eq "Started") {
                            Log-Message -MessageType "INFO" -Message "IIS Site id $($IISWebsite.id): Site is started. Attempting to stop website."
                            Stop-WebSite -Name $($IISWebsite.name)
                            Log-Message -MessageType "INFO" -Message "IIS Site id $($IISWebsite.id): Checking site state."
                            $iiswebsitestatus = Get-Website -Name $($IISWebsite.name) | select *
                            if ($iiswebsitestatus.state -eq "Stopped") {
                                Log-Message -MessageType "INFO" -Message "IIS Site id $($IISWebsite.id): Website successfully stopped."
                            }
                            else {
                                Log-Message -MessageType "ERROR" -Message "IIS Site id $($IISWebsite.id): Failed to stop website."
                            }
                        }
                        else {
                            Log-Message -MessageType "INFO" -Message "IIS Site id $($IISWebsite.id): Attempting to start website."
                            Start-WebSite -Name $($IISWebsite.name)
                            Log-Message -MessageType "INFO" -Message "IIS Site id $($IISWebsite.id): Checking site state."
                            $iiswebsitestatus = Get-Website -Name $($IISWebsite.name) | select *
                            if ($iiswebsitestatus.state -eq "Stopped") {
                                Log-Message -MessageType "ERROR" -Message "IIS Site id $($IISWebsite.id): Failed to start website."
                            }
                            else {
                                Log-Message -MessageType "INFO" -Message "IIS Site id $($IISWebsite.id): Website successfully started."
                                Log-Message -MessageType "INFO" -Message "IIS Site id $($IISWebsite.id): Checking url: $($SiteToWatch.URI)"
                                # Need to reset the variable because Invoke-WebRequest failures don't return anything, not even null.
                                $SiteURIStatus = $null
                                $SiteURIStatus = Invoke-WebRequest -UseBasicParsing -Uri $SiteToWatch.URI
                                if ($SiteURIStatus.StatusCode -eq "200") {
                                    Log-Message -MessageType "INFO" -Message "IIS Site id $($IISWebsite.id): StatusCode $($SiteURIStatus.StatusCode) $($SiteURIStatus.StatusDescription)."
                                }
                                else {
                                    Log-Message -MessageType "ERROR" -Message "IIS Site id $($IISWebsite.id): StatusCode not 200."
                                }
                            }
                        }
                    }
                    else {
                        Log-Message -MessageType "INFO" -Message "IIS Site id $($IISWebsite.id): Site is not set to restart."
                    }
                }
            }
        }
    }
    else {
        Log-Message -MessageType "INFO" -Message "Site id $($SiteToWatch.SiteId) set to not check URI. Skipping."
    }
}
Log-Message -MessageType "INFO" -Message "Script stopped."
Log-Message -MessageType "INFO" -Message "******************************************************************"
