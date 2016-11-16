# Demo-SSRSReportDeploy

<# Init SSRS
Import-Module 'C:\Users\cjsommer\Documents\Git\sqlserver-automation-with-posh\SQLServer\SQLServiceManagement.psm1'
Set-SQLServiceStartMode -NewStartMode 'Manual' -ServiceName 'ReportServer$INST1' -ComputerName bigred7
Start-SQLServices
Get-SQLServices | Format-Table -AutoSize

$MyURL = "http://bigred7/ReportServer/ReportService2005.asmx?WSDL"
New-WebServiceProxy -Uri $MyURL -UseDefaultCredential | Out-Null
#>

# Web Service Definition Language (WSDL)
Remove-Module SSRSDeploy -ErrorAction SilentlyContinue
Import-Module 'C:\Users\cjsommer\Documents\Git\sqlserver-automation-with-posh\SSRSDeploy\SSRSDeploy.psm1'
Get-Command -Module SSRSDeploy



