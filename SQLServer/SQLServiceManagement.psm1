<#
.Synopsis 
  Get SQL Server services

.Parameter ComputerName
  Name of the computer to get SQL Services from
#>
function Get-SQLServices
{
    [cmdletbinding()]
    param (
        [string]$ComputerName
    )
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement") | Out-Null

    $ServerObj = New-Object "Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer" $ComputerName
    $ServerObj.Services | Select-Object -Property Name, Type, ServiceState, StartMode, ServiceAccount
}

<#
.Synopsis 
  Start SQL Server services

.Parameter ComputerName
  Name of the computer to start services on
#>
function Start-SQLServices
{
    [cmdletbinding()]
    param (
        [string]$ComputerName 
    )
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement") | Out-Null

    $ServerObj = New-Object "Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer" $ComputerName
    # SqlServer
    $ServerObj.Services | Where-Object {$_.ServiceState -eq 'Stopped' -and $_.StartMode -ne 'Disabled' -and $_.Type -eq 'SqlServer'} | Start-Service

    # SqlAgent
    $ServerObj.Services | Where-Object {$_.ServiceState -eq 'Stopped' -and $_.StartMode -ne 'Disabled' -and $_.Type -eq 'SqlAgent'} | Start-Service

    # All Other Sql Services
    $ServerObj.Services | Where-Object {$_.ServiceState -eq 'Stopped' -and $_.StartMode -ne 'Disabled'} | Start-Service

}

<#
.Synopsis 
  Stop SQL Server services

.Parameter ComputerName
  Name of the computer to stop services on
#>
function Stop-SQLServices
{
[cmdletbinding()]
    param (
        [string]$ComputerName 
    )
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement") | Out-Null

    $ServerObj = New-Object "Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer" $ComputerName

    # All Other Sql Services
    $ServerObj.Services | Where-Object {$_.ServiceState -eq 'Running'} | Stop-Service -Force

}

<#
.Synopsis 
  Set SQL Server service Startup Modes

.Parameter ComputerName
  Name of the computer to stop services on

.Parameter OriginalStartMode
  When switching multiple services you need to provide the original startup mode 

.Parameter NewStartMode
  This is the new start mode

.Parameter ServiceName
  Use this to set the start mode for a specific SQL Service
#>
function Set-SQLServiceStartMode
{
    [cmdletbinding()]
    param (
        [string]$ComputerName ,
        [ValidateSet("Disabled","Manual","Auto")][string]$OriginalStartMode ,
        [ValidateSet("Disabled","Manual","Auto")][string]$NewStartMode ,
        [string]$ServiceName = $null
    )

    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement") | Out-Null

    $ServerObj = New-Object "Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer" $ComputerName

    Write-Verbose ("ServiceName = '$SeviceName'")
    if ($ServiceName -ne "$null") {
        foreach ($ServiceName in ($ServerObj.Services | Where {$_.Name -eq "$ServiceName"} |  Select-Object -ExpandProperty Name) ) {
            Write-Verbose ("Setting $ServiceName to $NewStartMode")
            Set-Service -Name $ServiceName -StartupType $NewStartMode
        }
    } else {
        foreach ($ServiceName in ($ServerObj.Services | Where {$_.StartMode -eq "$OriginalStartMode"} | Select-Object -ExpandProperty Name) ) {
            Write-Verbose ("Setting $ServiceName to $NewStartMode")
            Set-Service -Name $ServiceName -StartupType $NewStartMode
        }
    }
}

<#
 .Synopsis
 Get disk space listing.

 .PARAMETER ServerName
 Name of the Server to run this cmdlet against. Default to localhost.
#>
function Get-DiskSpace {
    [cmdletbinding()]
    param (
        [string]$ServerName = 'localhost'
    )
    $unit = "MB"
    $measure = "1$unit"

    Get-WmiObject -ComputerName $ServerName -query "
    select SystemName, Name, DriveType, FileSystem, FreeSpace, Capacity, Label
    from Win32_Volume
    where DriveType = 2 or DriveType = 3" `
    | select SystemName `
            , Name `
            , @{Label="SizeIn$unit";Expression={"{0:n2}" -f($_.Capacity/$measure)}} `
            , @{Label="FreeIn$unit";Expression={"{0:n2}" -f($_.freespace/$measure)}} `
            , @{Label="PercentFree";Expression={"{0:n2}" -f(($_.freespace / $_.Capacity) * 100)}} `
            ,  Label    
}