<#
 .Synopsis
 Get disk space listing.

 .Description
 This script gets a disk space listing for the local machine. 

 .Example 
 .\Get-DiskSpace.ps1
 Run on the local computer.

 .Example 
 Invoke-Command -Computer MyServerName .\Get-DiskSpace.ps1
 Run against a remote computer. Must have WinRM enabled on the remote computer.

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

Get-DiskSpace | Format-Table -AutoSize
