# Module for SQL Mirroring related cmdlets

### Public Functions
function Create-SQLMirror
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string]$DatabaseName ,
        [Parameter(Mandatory=$true)][string]$PrincipalServer ,
        [Parameter(Mandatory=$true)][string]$MirrorServer
    )
    Write-Verbose "BEGINNING Create-SQLMirror for database: '$DatabaseName' $(Get-Date -format 'yyyy-MM-dd hh:mm:ss')"
    Write-Verbose "PrincipalServer: $PrincipalServer"
    Write-Verbose "   MirrorServer: $MirrorServer"

    # Load libraries and set aliases
    Push-Location; Import-Module "SQLPS" -DisableNameChecking -Verbose:$false ; Pop-Location

    # Get host info for the principle and the mirror server
    [object]$pSQLHostInfo = Get-SQLHostInfo -SqlServer $PrincipalServer
    [object]$mSQLHostInfo = Get-SQLHostInfo -SqlServer $MirrorServer

    ### Get all of the information required to create the mirror      
    # Get primary and secondary backup, data and log file locations
    $PrincipleDefaultLocations = Get-SQLDefaultLocations -SQLServer $PrincipalServer
    $MirrorDefaultLocations = Get-SQLDefaultLocations -SQLServer $MirrorServer

    # Use the Principle Server backupdir as the WorkDir for creating the mirror.
    $WorkDir = ('\\' + $PrincipleDefaultLocations.NetName + '\' + ($PrincipleDefaultLocations.BackupDirectory).replace(':','$') + "\${DatabaseName}")
    if (! (Test-Path $WorkDir)) {
        New-Item -type directory -path $WorkDir
    }
    Write-Verbose "WorkDir: $WorkDir"

    # Validate endpoint on principle server
    $pEndpoint = Get-MirrorEndpoint -SQLServer $PrincipalServer
    Write-Verbose "Primary Endpoint: '$($pEndpoint.endpoint_name)' on port '$($pEndpoint.port)'"
    if ($pEndpoint.endpoint_name -eq "MISSING") {
        Throw ("Mirror Endpoint Missing on '$PrincipalServer'! Script Exiting!")
    }

    # Validate endpoint on mirror server
    $mEndpoint = Get-MirrorEndpoint -SQLServer $MirrorServer
    Write-Verbose "Secondary Endpoint: '$($mEndpoint.endpoint_name)' on port '$($mEndpoint.port)'"
    if ($mEndpoint.endpoint_name  -eq "MISSING") {
        Throw ("Mirror Endpoint Missing on '$MirrorServer'! Script Exiting!")
    }

    $CurrentDttm = Get-Date -format "yyyyMMdd_hhmm"
    # Set the full and log backup filenames.
    $DatabaseBackup = "${WorkDir}\${DatabaseName}_${CurrentDttm}_full.bak" 
    $LogBackup = "${WorkDir}\${DatabaseName}_${CurrentDttm}_log.trn" 

    # SQL Statement Timeout for the backup and restore operations
    $StatementTimeout = 3600

    ### Backup database on primary. Changed to using SQL Connection object so I can control the timeout.
    Write-Verbose "Backup database $(Get-Date -format 'yyyy-MM-dd hh:mm:ss')"
    $PrimaryServerConn = New-Object ("Microsoft.SqlServer.Management.Smo.Server") $PrincipalServer
    $PrimaryServerConn.ConnectionContext.StatementTimeout = $StatementTimeout 
    Backup-SqlDatabase -InputObject $PrimaryServerConn -Database $DatabaseName -BackupFile $DatabaseBackup -PassThru | Out-Null
    Backup-SqlDatabase -InputObject $PrimaryServerConn -Database $DatabaseName -BackupFile $LogBackup -BackupAction Log -PassThru | Out-Null

    # Create the file relocate object mappings
    Write-Verbose "Generating file mappings"
    $mDataLocation = $MirrorDefaultLocations.DefaultFile
    $mLogLocation = $MirrorDefaultLocations.DefaultLog
    [array]$RelocateFileArray = Get-RelocateFileArray -SQLServer $MirrorServer -BackupFile $DatabaseBackup -NewDataLoc $mDataLocation -NewLogLoc $mLogLocation

    ### Restore database on target replica with no recovery. Changed to using SQL Connection object so I can control the timeout.
    Write-Verbose "Restore database $(Get-Date -format 'yyyy-MM-dd hh:mm:ss')"
    $MirrorServerConn = New-Object ("Microsoft.SqlServer.Management.Smo.Server") $MirrorServer
    $MirrorServerConn.ConnectionContext.StatementTimeout = $StatementTimeout
    Restore-SqlDatabase -InputObject $MirrorServerConn -Database $DatabaseName -BackupFile $DatabaseBackup -RelocateFile $RelocateFileArray -NoRecovery -PassThru  | Out-Null
    Restore-SqlDatabase -InputObject $MirrorServerConn -Database $DatabaseName -BackupFile $LogBackup -RestoreAction Log -NoRecovery -PassThru | Out-Null

    ### Create mirror
    Write-Verbose "Configure database mirroring $(Get-Date -format 'yyyy-MM-dd hh:mm:ss')"
    $pHostname = ($pSQLHostInfo.SourceHostname).ToLower()
    $pTCPPort = $pEndpoint.port
    
    $mHostname = ($mSQLHostInfo.SourceHostname).ToLower()
    $mTCPPort = $mEndpoint.port

    $pSetPartnerSQL = "
    -- Run on the principle server
    ALTER DATABASE ${DatabaseName}
    SET PARTNER = 'TCP://${mHostname}:${mTCPPort}'"

    $mSetPartnerSQL = "
    -- Run on the mirror server
    ALTER DATABASE ${DatabaseName}
    SET PARTNER = 'TCP://${pHostname}:${pTCPPort}'"

    Invoke-Sqlcmd -ServerInstance $MirrorServer -Query $mSetPartnerSQL
    Invoke-Sqlcmd -ServerInstance $PrincipalServer -Query $pSetPartnerSQL

    Write-Verbose "COMPLETED Create-SQLMirror database: '$DatabaseName' $(Get-Date -format 'yyyy-MM-dd hh:mm:ss')"
}

function Failover-SQLMirror
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string]$DatabaseName ,
        [Parameter(Mandatory=$true)][string]$PrincipalServer
    )
    # Load libraries and set aliases
    Push-Location; Import-Module "SQLPS" -DisableNameChecking -Verbose:$false ; Pop-Location

    Write-Verbose "BEGINNING Failover-SQLMirror $(Get-Date -format 'yyyy-MM-dd hh:mm:ss')"
    "{0,20}: {1,-20}" -f "Database Name",$DatabaseName | Write-Verbose 
    "{0,20}: {1,-20}" -f "Principal Server",$PrincipalServer | Write-Verbose 

    [bool]$SafeToFailover = $false
    # Multiple SleepMilliseconds * $WaitMaxCount to get the total number of millisecods it will wait
    # 500ms * 120 = 60 second wait total
    [int]$SleepMilliseconds = 500
    [int]$WaitMaxCount = 600
    [int]$WaitCounter = 1

    while (!$SafeToFailover -and $WaitCounter -le $WaitMaxCount)
    {
        $DBStateObj = Get-DatabaseMirrorState -SQLServer $PrincipalServer -DatabaseName $DatabaseName
        [string]$DBState = $DBStateObj.Status
        [bool]$DBIsMirrored = $DBStateObj.IsMirroringEnabled
        [string]$DBMirroringStatus = $DBStateObj.MirroringStatus

        # Output the current state 
        "{0,20}: {1,-20}" -f "Database State",$DBState | Write-Verbose 
        "{0,20}: {1,-20}" -f "Database Mirrored",$DBIsMirrored | Write-Verbose 
        "{0,20}: {1,-20}" -f "Mirroring Status",$DBMirroringStatus | Write-Verbose 

        # If database is not mirrored and the state is RESTORING it is safe to drop. Otherwise sleep and check again.
        if ( $DBIsMirrored -eq $true -and $DBMirroringStatus -eq "Synchronized" ) {
            $SafeToFailover = $true
        } else {
            # Database not Synchronized, sleep and increment the Wait counter          
            Start-Sleep -Milliseconds $SleepMilliseconds
            $WaitCounter ++
        }
    }  
    # If the mirror is synchronized it is safe to fail over.
    if ($SafeToFailover) {
        $pFailoverSQL = "
        use [master];
        ALTER DATABASE ${DatabaseName} SET SAFETY FULL;
        ALTER DATABASE ${DatabaseName} SET PARTNER FAILOVER;"
        # Increased the query timeout for the failover to 5 minutes. We have had a couple timeout errors on failover.
        Invoke-Sqlcmd -ServerInstance $PrincipalServer -Query $pFailoverSQL -QueryTimeout 300

    } else {
        Throw "${ScriptName}: Database mirror for '$DatabaseName' is not synchronized and cannot be failed over."
    }
    Write-Verbose "COMPLETED Failover-SQLMirror $(Get-Date -format 'yyyy-MM-dd hh:mm:ss')"
} 

function Remove-SQLMirror
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string]$DatabaseName ,
        [Parameter(Mandatory=$true)][string]$PrincipalServer
    )
    Write-Verbose "BEGINNING Remove-SQLMirror $(Get-Date -format 'yyyy-MM-dd hh:mm:ss')"
    # Load libraries and set aliases
    Push-Location; Import-Module "SQLPS" -DisableNameChecking -Verbose:$false ; Pop-Location

    "{0,20}: {1,-20}" -f "Database Name",$DatabaseName | Write-Verbose
    "{0,20}: {1,-20}" -f "Principal Server",$PrincipalServer | Write-Verbose

    $pRemoveSQL = "
    ALTER DATABASE ${DatabaseName} SET PARTNER OFF;"
    Invoke-Sqlcmd -ServerInstance $PrincipalServer -Query $pRemoveSQL

    Write-Verbose "COMPLETED Remove-SQLMirror $(Get-Date -format 'yyyy-MM-dd hh:mm:ss')"
}

function Drop-SQLDatabase
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string]$SQLServer ,
        [Parameter(Mandatory=$true)][string]$DatabaseName
    )

    Write-Verbose "BEGINNING Drop-SQLDatabase $(Get-Date -format 'yyyy-MM-dd hh:mm:ss')"
    # Load libraries and set aliases
    Push-Location; Import-Module "SQLPS" -DisableNameChecking -Verbose:$false ; Pop-Location

    "{0,20}: {1,-20}" -f "SQL Server",$SQLServer | Write-Verbose 
    "{0,20}: {1,-20}" -f "Database Name",$DatabaseName | Write-Verbose 

    # Get the current database state, and wait until it goes to RESTORING.
    [bool]$SafeToDrop = $false

    # Multiple SleepMilliseconds * $WaitMaxCount to get the total number of millisecods it will wait
    # 500ms * 120 = 60 second wait total
    [int]$SleepMilliseconds = 500
    [int]$WaitMaxCount = 120
    [int]$WaitCounter = 1

    while (!$SafeToDrop -and $WaitCounter -le $WaitMaxCount)
    {
        $DBStateObj = Get-DatabaseState -SQLServer $SQLServer -DatabaseName $DatabaseName
        [string]$DBState = $DBStateObj.Status
        [bool]$DBIsMirrored = $DBStateObj.IsMirroringEnabled

        # Output the current state 
        Write-Verbose "Checking database state $(Get-Date -format 'yyyy-MM-dd hh:mm:ss')"
        "{0,20}: {1,-20}" -f "Database State",$DBState | Write-Verbose 
        "{0,20}: {1,-20}" -f "Database Mirrored",$DBIsMirrored | Write-Verbose 

        # If database is not mirrored and the state is RESTORING it is safe to drop. Otherwise sleep and check again.
        if ( $DBIsMirrored -eq $false -and $DBState -eq "RESTORING" ) {
            $SafeToDrop = $true
        } else {
            # Database not RESTORING, sleep and increment the Wait counter          
            Start-Sleep -Milliseconds $SleepMilliseconds
            $WaitCounter ++
        }
    }  

    # If the database is safe to drop, do it!
    if ($SafeToDrop) {
        "`tSafe to drop database. Dropping Database!"| Write-Verbose 
        $DropDatabaseSQL = "
        USE [master];
        DROP DATABASE [${DatabaseName}];"

        Invoke-Sqlcmd -ServerInstance $SQLServer -Query $DropDatabaseSQL
    } else {
        Throw "${ScriptName}: Database must not be mirrored and in RESTORING state to DROP."
    }

    Write-Verbose "COMPLETED Drop-SQLDatabase $(Get-Date -format 'yyyy-MM-dd hh:mm:ss')"
}


### Private Functions
function Get-SQLHostInfo
{
    param (
        [Parameter(Mandatory=$true)][string]$SqlServer
    )

    # Extract all server and database info for the source and target from the CSV file
    $HostStringOfUnknownType = ($SqlServer.Split("\"))[0]  
    $InstanceName = ($SqlServer.Split("\"))[1]    

    # Determine IP and Hostname. This block will determine if it's a valid IP address automatically.
    [System.Net.IPAddress]$IPAddressObject = $null            
    if([System.Net.IPAddress]::tryparse($HostStringOfUnknownType,[ref]$IPAddressObject) -and $HostStringOfUnknownType -eq $IPAddressObject.tostring()) {
        # Write-Host "$HostStringOfUnknownType appears to be a valid IP address"
        $SourceIPaddress = $HostStringOfUnknownType
        $hostinfo = [System.Net.Dns]::GetHostByAddress($SourceIPaddress)
        $SourceHostName = $($hostinfo.HostName.split('.'))[0].ToUpper()
    } else {
        # Write-Host "$HostStringOfUnknownType does not appear to be a valid IP address. Treating it as a hostname."
        $SourceIPaddress = ([System.Net.Dns]::GetHostAddresses($HostStringOfUnknownType)) | Select-Object -ExpandProperty IPAddressToString
        $SourceHostname = $HostStringOfUnknownType
    }
    $ObjProps = @{  
                'SourceHostname' =  $SourceHostname ;
                'SourceIPaddress' = $SourceIPaddress ;
                'InstanceName' = $InstanceName ;
                'SQLServer_Hostname' = ($SourceHostname + "\" + $InstanceName) ;
                'SQLServer_IP' =  ($SourceIPaddress + "\" + $InstanceName)
    }
                
    $ReturnObj = New-Object psobject -Property $ObjProps
    $ReturnObj
}

function Get-MirrorEndpoint
{
    param (
        [string]$SQLServer 
    )
    $sql1 = "
    -- Return endpoint data. If no endpoint exists return ERROR,ERROR,ERROR
    IF EXISTS (	SELECT * FROM sys.database_mirroring_endpoints )
	    SELECT e.NAME AS endpoint_name
		    ,e.state_desc
		    ,t.port
	    FROM sys.database_mirroring_endpoints e
	    INNER JOIN sys.tcp_endpoints t ON e.endpoint_id = t.endpoint_id
	    ORDER BY e.NAME
    ELSE
	    SELECT 'MISSING' AS endpoint_name
		    ,'MISSING' AS state_desc
		    ,'MISSING' AS port
    "
    $result = Invoke-Sqlcmd -ServerInstance $SQLServer -Query $sql1
    # Should return 1 row ( Mirroring,STARTED,5022). If no endpoint exists it will return (MISSING,MISSING,MISSING)
    $result
}

function Get-SQLDefaultLocations
{
    # Get default data, log and backup locations from SQL Server using SMO
    param (
        $SQLServer
    )
        
    $Result = $null
    $Result = new-object Microsoft.SqlServer.Management.Smo.Server $SQLServer
    $Result |Select-Object -Property NetName,DefaultFile,DefaultLog,BackupDirectory     
}

function Get-RelocateFileArray
{
    param (
        [string]$SQLServer ,
        [string]$BackupFile ,
        [string]$NewDataLoc ,
        [string]$NewLogLoc 
    )
    $FilelistSQL = "RESTORE FILELISTONLY FROM DISK = '${BackupFile}';"
    $Filelist = Invoke-Sqlcmd -ServerInstance $SQLServer -Query $FilelistSQL
    [array]$ReturnResult = $null
    
    foreach ($File in $Filelist) {
        Switch ($File.Type){
            "D" {
                $FileName = ($File.PhysicalName).split("\")[((($File.PhysicalName).Split("\")).Count)-1]
                $ReturnResult += New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($File.LogicalName,"${NewDataLoc}\${FileName}")
            }
            "L" {
                $FileName = ($File.PhysicalName).split("\")[((($File.PhysicalName).Split("\")).Count)-1]
                $ReturnResult += New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($File.LogicalName,"${NewLogLoc}\${FileName}")
            }
        }
    }
    $ReturnResult
}

function Get-DatabaseStateTSQL
{
    param (
        [string]$SQLServer ,
        [string]$DatabaseName
    )

    $StateSQL = "
    SELECT state_desc
    FROM sys.databases
    WHERE NAME = '${DatabaseName}'
    "
    $result = Invoke-Sqlcmd -ServerInstance $SQLServer -Query $StateSQL -QueryTimeout 120
    $result | Select-Object -ExpandProperty state_desc
}

function Get-DatabaseState
{
    param (
        [string]$SQLServer ,
        [string]$DatabaseName
    )
    # Get database state using SMO. This will return the database state and the mirroring state
    $DBObject = $null
    $DBObject = (New-Object Microsoft.SqlServer.Management.Smo.Server $SQLServer).Databases | Where {$_.name -eq "$DatabaseName"} | Select -Property Status,IsMirroringEnabled
    $DBObject
}

function Get-DatabaseMirrorState
{
    param (
        [string]$SQLServer ,
        [string]$DatabaseName
    )
    # Get database state using SMO. This will return the database state and the mirroring state
    $DBObject = $null
    $DBObject = New-Object Microsoft.SqlServer.Management.Smo.Server $SQLServer
    $DBObject.ConnectionContext.Connect()
    $DBObject.Databases | Where {$_.name -eq "$DatabaseName"} | Select -Property Status,IsMirroringEnabled,MirroringStatus
}

function Get-MirrorDemo2Databases
{
    param (
        [string]$SQLServer
    )
    # Get database state using SMO. This will return the database state and the mirroring state
    $DBObject = $null
    $DBObject = New-Object Microsoft.SqlServer.Management.Smo.Server $SQLServer
    $DBObject.ConnectionContext.Connect()
    [array]$Databases = $DBObject.Databases | Where {$_.name -like "MirrorDemo*"} | Select-Object -Property id, name | Sort-Object id
    $Databases
}

Export-ModuleMember -Function *