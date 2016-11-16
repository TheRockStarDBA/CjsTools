### SQL Memory Configuration Demo

# Script Module for managing SQL Memory Configurations
Remove-Module SQLConfig -ErrorAction SilentlyContinue
Import-Module 'C:\Users\cjsommer\Documents\Git\sqlserver-automation-with-posh\SQLServer\SQLConfig.psm1'
Get-Command -Module SQLConfig

# How do we use it?  
Get-Help Get-SQLServerMemoryConfig -Full

# Get memory configs for all SQL Servers on this machine
$SQLServers = @('bigred7\inst1','bigred7\inst2')
[array]$Results = $null
foreach ($SQLServer in $SQLServers)
{
    $Results += Get-SQLServerMemoryConfig -SQLServer $SQLServer
} 

$Results | Format-Table -AutoSize


# Set memory settings for the 2 local instances 

Get-Help Set-SQLServerMemoryConfig -Full
  
$SQLServers = @('bigred7\inst1','bigred7\inst2')
foreach ($SQLServer in $SQLServers)
{
    Set-SQLServerMemoryConfig -SQLServer $SQLServer -MaxSQLMemory 256 -CommitChanges
} 
