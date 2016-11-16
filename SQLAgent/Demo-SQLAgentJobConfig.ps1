# Demo SQL Agent Job Configuration

Remove-Module SQLAgentJobConfig -ErrorAction SilentlyContinue
Import-Module 'C:\Users\cjsommer\Documents\Git\sqlserver-automation-with-posh\SQLAgent\SQLAgentJobConfig.psm1'
Get-Command -Module SQLAgentJobConfig



### Configurations
$SQLServers = @('BIGRED7\inst1','BIGRED7\inst2')



### Get JobOwner 
$Result = $null
foreach ($SQLServer in $SQLServers) {
    $Result += Get-SQLAgentJobOwner  -SQLServer $SQLServer
}
$Result |Format-Table -AutoSize

# SET JobOwner 
foreach ($SQLServer in $SQLServers) {
    Set-SQLAgentJobOwner -SQLServer $SQLServer -OwnerName 'BIGRED7\cjsommer'
}



### Get CompletionAction
$Result = $null
foreach ($SQLServer in $SQLServers) {
    $Result += Get-SQLAgentJobCompletionAction -SQLServer $SQLServer
}
$Result |Format-Table -AutoSize

# Set CompletionAction
foreach ($SQLServer in $SQLServers) {
    Set-SQLAgentJobCompletionAction -SQLServer $SQLServer -CompletionAction OnFailure
}



### Get JobOutputFile
$Result = $null
foreach ($SQLServer in $SQLServers) {
    $Result += Get-SQLAgentJobOutputFile -SQLServer $SQLServer
}
$Result |Format-Table -AutoSize

# Set JobOutputFile
Set-SQLAgentJobOutputFile -SQLServer 'BIGRED7\inst1' -SQLAgentOutputLocation 'C:\SQL\MSSQL11.INST1\MSSQL\SQLAgentJobLogs'
Set-SQLAgentJobOutputFile -SQLServer 'BIGRED7\inst2' -SQLAgentOutputLocation 'C:\SQL\MSSQL11.INST2\MSSQL\SQLAgentJobLogs'


