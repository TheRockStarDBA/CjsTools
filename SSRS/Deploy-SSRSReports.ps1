<#
.SYNOPSIS
	Installs an RDL file to SQL Reporting Server using Web Service and sets the data source.

.NOTES
	File Name: Deploy-SSRSReports.ps1
	Author: Chris Sommer
	Prerequisite: SSRS 2008 (or greater), Powershell 2.0
	
    Install-SSRSRDL function original code found here:
    https://randypaulo.wordpress.com/2012/02/21/how-to-install-deploy-ssrs-rdl-using-powershell/
    
    Set-SSRSDataSource code and ideas originally found here:
    http://stackoverflow.com/questions/9178685/change-datasource-of-ssrs-report-with-powershell
    
    The rest of the wrapper and deployment automation is custom.
    
.EXAMPLE
	Deploy-SSRSReports
#>
[cmdletbinding()]
param (
    [string]$WebServiceURL = "http://bigred7/ReportServer/ReportService2005.asmx?WSDL",
    [string]$SSRSReportFolder = "AdventureWorks2012",
    [string]$DataSourcePath = "/AdventureWorks2012/AW2012",
    [string]$DataSourceName = "ProdDS",
    [string]$ReportStagingFolder = 'C:\Users\cjsommer\Documents\Git\sqlserver-automation-with-posh\SSRSDeploy\Reports'
)

### Main program body
# Setup pathing and environment based on the script location
$Invocation = (Get-Variable MyInvocation -Scope 0).Value
$ScriptLocation = Split-Path $Invocation.MyCommand.Path
$ScriptName = $Invocation.MyCommand.Name.Replace(".ps1","")
$ScriptFullPath = $Invocation.MyCommand.Path

Import-Module "$ScriptLocation\SSRSDeploy.psm1"

# Deploy each report in the staging folder
foreach ($report in (Get-ChildItem $ReportStagingFolder *.rdl|Select-Object -First 10))
{
    $ReportFileName = $report.name
    $ReportFileFullname = "$ReportStagingFolder\$ReportFileName"
    $ReportName = $ReportFileName.Replace(".rdl","")
 
    # Deploy the report
    Write-Verbose "Deploying '$ReportName'"
    Install-SSRSRDL -webServiceUrl $WebServiceURL -reportName $ReportName -rdlFile $ReportFileFullname `
        -reportFolder $SSRSReportFolder -force -Verbose
    
    # Set the data source
    Write-Verbose "Setting data source for '$ReportName'"
    Set-SSRSDataSource -WebServiceURL $WebServiceUrl -DataSourcePath $DataSourcePath -DataSourceName $DataSourceName `
        -ReportFolderPath $SSRSReportFolder -ReportName $ReportName -Verbose       
}
