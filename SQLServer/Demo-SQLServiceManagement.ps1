### SQL Service Management Demo

# Load our SQLServiceManagement module
Remove-Module SQLServiceManagement -ErrorAction SilentlyContinue
Import-Module 'C:\Users\cjsommer\Documents\Git\sqlserver-automation-with-posh\SQLServer\SQLServiceManagement.psm1'
Get-Command -Module SQLServiceManagement

# How do we use the Get-SQLServices cmdlet
Get-Help Get-SQLServices -Full

# What SQL Services are on this local machine?
Get-SQLServices | Format-Table -AutoSize

### Failover Demo 
# INST1 will be the PRIMARY
# INST2 will be the SECONDARY

Get-SQLServices -ComputerName bigred7 | Format-Table -AutoSize

# Stop SQL Services
Stop-SQLServices -ComputerName bigred7
Get-SQLServices -ComputerName bigred7 | Format-Table -AutoSize

# Disable SQL Services on Primary
Set-SQLServiceStartMode -NewStartMode 'Disabled' -ServiceName 'MSSQL$INST1' -ComputerName bigred7
Set-SQLServiceStartMode -NewStartMode 'Disabled' -ServiceName 'SQLAgent$INST1' -ComputerName bigred7
Get-SQLServices -ComputerName bigred7 | Format-Table -AutoSize

## Another group fails over storage

# Check for storage failover. All disks should go from primary to secondary.
Get-DiskSpace -ServerName bigred7 | Format-Table -AutoSize

# Enable SQL Servives on Secondary
Set-SQLServiceStartMode -NewStartMode 'Manual' -ServiceName 'MSSQL$INST2' -ComputerName bigred7
Set-SQLServiceStartMode -NewStartMode 'Manual' -ServiceName 'SQLAgent$INST2' -ComputerName bigred7
Get-SQLServices -ComputerName bigred7 | Format-Table -AutoSize

# Start SQL Services on secondary
Start-SQLServices  -ComputerName bigred7
Get-SQLServices -ComputerName bigred7 | Format-Table -AutoSize



<# Cleanup for the rest of the demos
Set-SQLServiceStartMode -OriginalStartMode 'Disabled' -NewStartMode 'Manual'
Start-SQLServices -ComputerName bigred7
Get-SQLServices -ComputerName bigred7 | Format-Table -AutoSize
#
# Init SSRS
$URL = 'http://bigred7/Reports/Pages/Folder.aspx'
Invoke-WebRequest -Uri $URL -UseDefaultCredentials | Out-Null
#>