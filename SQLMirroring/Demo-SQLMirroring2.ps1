### SQLMirroring Demo

Remove-Module SQLMirroring -ErrorAction SilentlyContinue
Import-Module 'C:\Users\cjsommer\Documents\Git\sqlserver-automation-with-posh\SQLMirroring\SQLMirroring.psm1' -DisableNameChecking

$ProgressPreference='SilentlyContinue' # Supress progress bar

$SourceSQLServer = 'BIGRED7\INST1'
$TargetSQLServer = 'BIGRED7\INST2'

# Migrate each database from PrincipalServer to MirrorServer
foreach ($Database in (Get-MirrorDemo2Databases -SQLServer $SourceSQLServer)) {

    $DatabaseName = $Database.Name

    # Create the mirror
    Create-SQLMirror -PrincipalServer $SourceSQLServer -MirrorServer $TargetSQLServer -DatabaseName $DatabaseName -Verbose
    # Failover the mirror
    Failover-SQLMirror -PrincipalServer $SourceSQLServer -DatabaseName $DatabaseName -Verbose
    # Remove the mirror from the new principle
    Remove-SQLMirror -PrincipalServer $TargetSQLServer -DatabaseName $DatabaseName -Verbose
    # Drop the source database
    Drop-SQLDatabase -SQLServer $SourceSQLServer -DatabaseName $DatabaseName -Verbose
}