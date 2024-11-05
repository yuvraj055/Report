Import-Module PSWindowsUpdate
# Create report file with timestamp
$reportPath = "SecurityAudit_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').txt"

function Write-ReportSection {
    param (
        [string]$Title,
        [string]$Content
    )
    Add-Content -Path $reportPath -Value "`n`n=== $Title ===`n"
    Add-Content -Path $reportPath -Value $Content
}

# Initialize a hash table to store the results
$auditResults = @{}

# System Information
$auditResults["System Information"] = @"
Computer Name: $env:COMPUTERNAME
Date: $(Get-Date)
Auditor: $env:USERNAME

Basic System Info:
$(systeminfo | Select-String "OS Name","OS Version","System Type","Total Physical Memory")
"@

# User Accounts Analysis
$userInfo = net user
$auditResults["User Accounts"] = @"
Local Users:
$userInfo

Administrator Account Status:
$(net user Administrator)

Admin Group Members:
$(net localgroup Administrators)
"@

# Password Policy
$passPolicy = net accounts
$auditResults["Password Policy"] = @"
Current Password Policy:
$passPolicy
"@

# Running Services
$services = Get-Service | Where-Object {$_.Status -eq "Running"} | Format-Table Name, DisplayName, Status -AutoSize | Out-String
$auditResults["Running Services"] = $services

# Network Connections
$netConnections = netstat -ano | Out-String
$auditResults["Network Connections"] = $netConnections

# Firewall Status
$firewallRules = netsh advfirewall show allprofiles | Out-String
$auditResults["Firewall Status"] = $firewallRules

# Startup Programs
$startupProgs = Get-CimInstance Win32_StartupCommand | Select-Object Name, Command, Location | Format-Table -AutoSize | Out-String
$auditResults["Startup Programs"] = $startupProgs

# Scheduled Tasks
$tasks = schtasks /query /fo LIST | Out-String
$auditResults["Scheduled Tasks"] = $tasks

# Recent Security Events
# Ensure PowerShell is running as Administrator for this command to work
try {
    $secEvents = Get-EventLog -LogName Security -Newest 50 | 
        Where-Object {$_.EntryType -eq "FailureAudit"} |
        Format-Table TimeGenerated, EventID, Message -AutoSize |
        Out-String
    $auditResults["Recent Security Events"] = $secEvents
} catch {
    $auditResults["Recent Security Events"] = "Access denied or no events found."
}

# Shared Folders
$shares = net share | Out-String
$auditResults["Shared Folders"] = $shares

# Installed Software
$software = Get-WmiObject -Class Win32_Product | 
    Select-Object Name, Version, Vendor |
    Format-Table -AutoSize |
    Out-String
$auditResults["Installed Software"] = $software

# Check for Windows Updates
# Import the PSWindowsUpdate module
Import-Module PSWindowsUpdate

try {
    $updates = Get-WindowsUpdate | Select-Object Title, Description, Date, Size | Out-String
    $auditResults["Windows Updates"] = $updates
} catch {
    $auditResults["Windows Updates"] = "No updates found or module not available."
}

# Check for Antivirus Software
$antivirus = Get-WmiObject -Namespace "root\SecurityCenter2" -Class AntiVirusProduct | Select-Object displayName | Out-String
$auditResults["Antivirus Software"] = $antivirus

# Network Adapter Information
$networkAdapters = Get-NetAdapter | Select-Object Name, Status, LinkSpeed | Format-Table -AutoSize | Out-String
$auditResults["Network Adapter Information"] = $networkAdapters

# Create a single output string from the hash table
$outputString = ""
foreach ($key in $auditResults.Keys) {
    $outputString += "=== $key ===`n" + $auditResults[$key] + "`n"
}

# Write the full output to the report file
$outputString | Out-File -FilePath $reportPath

# Output the structured data for the server to parse
$outputString
Write-Host "Report generated at: $reportPath"

