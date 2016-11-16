<#
.SYNOPSIS
    Installs an RDL file to SQL Reporting Server using Web Service
 
.DESCRIPTION
    Installs an RDL file to SQL Reporting Server using Web Service
 
.NOTES
    File Name: Install-SSRSRDL.ps1
    Author: Randy Aldrich Paulo
    Prerequisite: SSRS 2008, Powershell 2.0
    https://randypaulo.wordpress.com/2012/02/21/how-to-install-deploy-ssrs-rdl-using-powershell/
 
.PARAMETER reportName
    Name of report wherein the rdl file will be save as in Report Server.
    If this is not specified it will get the name from the file (rdl) exluding the file extension.
 
.PARAMETER force
    If force is specified it will create the report folder if not existing
    and overwrites the report if existing.
 
.EXAMPLE
    Install-SSRSRDL -webServiceUrl "http://[ServerName]/ReportServer/ReportService2005.asmx?WSDL" -rdlFile "C:\Report.rdl" -force
 
.EXAMPLE
    Install-SSRSRDL "http://[ServerName]/ReportServer/ReportService2005.asmx?WSDL" "C:\Report.rdl" -force
 
.EXAMPLE
    Install-SSRSRDL "http://[ServerName]/ReportServer/ReportService2005.asmx?WSDL" "C:\Report.rdl" -force -reportName "MyReport"
 
.EXAMPLE
    Install-SSRSRDL "http://[ServerName]/ReportServer/ReportService2005.asmx?WSDL" "C:\Report.rdl" -force -reportFolder "Reports" -reportName "MyReport"
#>
function Install-SSRSRDL
{
    [cmdletbinding()]
    param (
        [string]$webServiceUrl,
        [string]$rdlFile,
        [string]$reportFolder="",
        [string]$reportName="",
        [switch]$force
    )

	$ErrorActionPreference="Stop"
	
	#Create Proxy
	Write-Verbose "[Install-SSRSRDL()] Creating Proxy, connecting to : $webServiceUrl"
	$ssrsProxy = New-WebServiceProxy -Uri $webServiceUrl -UseDefaultCredential
	$reportPath = "/"
	
	if($force)
	{
		#Check if folder is existing, create if not found
		try
		{
			$ssrsProxy.CreateFolder($reportFolder, $reportPath, $null)
			Write-Verbose "[Install-SSRSRDL()] Created new folder: $reportFolder"
		}
		catch [System.Web.Services.Protocols.SoapException]
		{
			if ($_.Exception.Detail.InnerText -match "[^rsItemAlreadyExists400]")
			{
				Write-Verbose "[Install-SSRSRDL()] Folder: $reportFolder already exists."
			}
			else
			{
				$msg = "[Install-SSRSRDL()] Error creating folder: $reportFolder. Msg: '{0}'" -f $_.Exception.Detail.InnerText
				Write-Error $msg
			}
		}
		
	}
	
	#Set reportname if blank, default will be the filename without extension
	if($reportName -eq "") { $reportName = [System.IO.Path]::GetFileNameWithoutExtension($rdlFile);}
	Write-Verbose "[Install-SSRSRDL()] Report name set to: $reportName"
	
	try
	{
		#Get Report content in bytes
		Write-Verbose "[Install-SSRSRDL()] Getting file content (byte) of : $rdlFile"			
		$byteArray = gc $rdlFile -encoding byte
		$msg = "[Install-SSRSRDL()] Total length: {0}" -f $byteArray.Length			
		Write-Verbose $msg

		$reportFolder = $reportPath + $reportFolder
		Write-Verbose "[Install-SSRSRDL()] Uploading to: $reportFolder"			
		
		#Call Proxy to upload report
		$warnings = $ssrsProxy.CreateReport($reportName,$reportFolder,$force,$byteArray,$null)
		if($warnings.Length -eq $null) { Write-Verbose "[Install-SSRSRDL()] Upload Success." }
		else { $warnings | % { Write-Warning "[Install-SSRSRDL()] Warning: $_" }}
	}
	catch [System.IO.IOException]
	{
		$msg = "[Install-SSRSRDL()] Error while reading rdl file : '{0}', Message: '{1}'" -f $rdlFile, $_.Exception.Message
		Write-Error msg
	}
	catch [System.Web.Services.Protocols.SoapException]
	{
		$msg = "[Install-SSRSRDL()] Error while uploading rdl file : '{0}', Message: '{1}'" -f $rdlFile, $_.Exception.Detail.InnerText
		Write-Error $msg
	}
	
}

<#
.SYNOPSIS
    Set SSRS report data source

.DESCRIPTION
    Initial script found at http://stackoverflow.com/users/1194945/eghetto
#>
function Set-SSRSDataSource {
    [cmdletbinding()]
    param(
        $WebServiceUrl ,
        $DataSourcePath ,
        $DataSourceName ,
        $ReportFolderPath ,
        $ReportName
    )
    
    $ssrs = New-WebServiceProxy -uri $WebServiceUrl -UseDefaultCredential

    # Add the folder and the report name to create the report path
    $reportPath = "/$ReportFolderPath/$ReportName"
    
    Write-Verbose "[Set-SSRSDataSource()] Report: $reportPath"
    $dataSources = $ssrs.GetItemDataSources($reportPath)
    $dataSources | ForEach-Object {
        $proxyNamespace = $_.GetType().Namespace
        $myDataSource = New-Object ("$proxyNamespace.DataSource")
        $myDataSource.Name = $DataSourceName
        $myDataSource.Item = New-Object ("$proxyNamespace.DataSourceReference")
        $myDataSource.Item.Reference = $DataSourcePath

        $_.item = $myDataSource.Item

        $ssrs.SetItemDataSources($reportPath, $_)
        Write-Verbose "[Set-SSRSDataSource()] Report's DataSource Reference ($($_.Name)): $($_.Item.Reference)"
        Write-Verbose "[Set-SSRSDataSource()] ------------------------"
    }
 
}
