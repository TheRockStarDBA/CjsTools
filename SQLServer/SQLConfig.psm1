<#
 .Synopsis
 Get SQL Server Min and Max Memory Configurations

 .Parameter SQLServer
 SQL Server to query for Min and Max Memory Configurations
#>
function Get-SQLServerMemoryConfig
{
    [cmdletbinding()]
    param (
        [Parameter(Mandatory=$true)][string]$SQLServer 
    )   
    # Load the SMO object
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null

    $SQLObj = $null
    $SQLObj = new-object('Microsoft.SqlServer.Management.Smo.Server') $SQLServer 
    $SQLObj.ConnectionContext.Connect()
    $ObjProperties = [ordered]@{
        'SQLServer'      = $SQLServer ;
        'PhysicalMemory' = $SQLObj.information.physicalMemory ;
        'MaxSQLMemory'   = $SQLObj.configuration.maxServerMemory.ConfigValue ;
        'MinSQLMemory'   = $SQLObj.configuration.minServerMemory.ConfigValue  
    }
    $ServerConfig = New-Object PSObject -Property $ObjProperties
    # Return the object
    $ServerConfig 
} # End Get-SQLServerMemoryConfig 

<#
 .Synopsis
 Set SQL Server Max and Min Memory Settings

 .Parameter SQLServer
 SQL Server to run the script against

 .Parameter MaxSQLMemory
 The MaxSQLMemory configuration value (MB). Defaults to 90% physical RAM if not specified.
 
 .Parameter MinSQLMemory
 The MinSQLMemory configuration value (MB). Defaults to half the MaxServerMemory if not specified.
 
 .Parameter CommitChanges
 Commit changes to the database server?
#>
function Set-SQLServerMemoryConfig
{
    [cmdletbinding()]
    param (
        [Parameter(Mandatory=$true)][string]$SQLServer ,
        [int]$MaxSQLMemory ,
        [int]$MinSQLMemory ,
        [switch]$CommitChanges = $false
    )

    # Load the SMO object
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null

    $SQLObj = $null
    $SQLObj = new-object('Microsoft.SqlServer.Management.Smo.Server') $SQLServer 
    $SQLObj.ConnectionContext.Connect()
    
    # Set Max and Min SQL Memory values
    if ( ! $MaxSQLMemory ) {
        $MaxSQLMemory = $SQLOBJ.information.physicalMemory * .9
    }
    if ( ! $MinSQLMemory ) {
        $MinSQLMemory = $MaxSQLMemory / 2
    }
    Write-Verbose ("Server '$SQLServer' Physical Memory = " + $SQLOBJ.information.physicalMemory)
    Write-Verbose "Setting MaxServerMemory.ConfigValue = $MaxSQLMemory"
    Write-Verbose "Setting MinServerMemory.ConfigValue = $MinSQLMemory"

    $SQLObj.configuration.MaxServerMemory.ConfigValue = $MaxSQLMemory
    $SQLObj.configuration.MinServerMemory.ConfigValue = $MinSQLMemory
      
    if ($CommitChanges) {
        # Alter the configuration. Settings will take effect next SQL recycle
        Write-Verbose "Committing config changes on ${SQLServer}."
        $SQLObj.Configuration.Alter()
    } else {
        Write-Verbose "Changes not committed on ${SQLServer}. Rerun this script with '-CommitChanges flag' to commit changes."
    }
} # End Set-SQLServerMemoryConfig 