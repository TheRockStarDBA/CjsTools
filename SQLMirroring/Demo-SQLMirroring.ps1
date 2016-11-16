### SQLMirroring Demo

Remove-Module SQLMirroring -ErrorAction SilentlyContinue
Import-Module 'C:\Users\cjsommer\Documents\Git\sqlserver-automation-with-posh\SQLMirroring\SQLMirroring.psm1'
Get-Command -Module SQLMirroring

$ProgressPreference='SilentlyContinue'

Get-SQLServices | Format-Table -Auto

Create-SQLMirror -PrincipalServer 'BIGRED7\INST1' -MirrorServer 'BIGRED7\INST2' -DatabaseName 'AdventureWorks2012' -Verbose

Failover-SQLMirror -PrincipalServer 'BIGRED7\INST1' -DatabaseName 'AdventureWorks2012' -Verbose

Failover-SQLMirror -PrincipalServer 'BIGRED7\INST2' -DatabaseName 'AdventureWorks2012' -Verbose

Remove-SQLMirror -PrincipalServer 'BIGRED7\INST1' -DatabaseName 'AdventureWorks2012' -Verbose

Drop-SQLDatabase -SQLServer 'BIGRED7\INST1' -DatabaseName 'AdventureWorks2012' -Verbose