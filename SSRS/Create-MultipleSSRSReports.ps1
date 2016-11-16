
# Create a bunch of copies of the RDL report in the Reports folder.

# Setup pathing and environment based on the script location
$Invocation = (Get-Variable MyInvocation -Scope 0).Value
$ScriptLocation = Split-Path $Invocation.MyCommand.Path
$ScriptName = $Invocation.MyCommand.Name.Replace(".ps1","")
$ScriptFullPath = $Invocation.MyCommand.Path

# Where the report files are staged
$ReportDirectory = "$ScriptLocation\Reports"
$RDLToClone = "$ScriptLocation\Employee_Emails.rdl"

# Loop through each report in the staging folder and deploy. Details of any failures will be contained in the output.
for ($i = 1; $i -le 50; $i++)
{
    $NewReportName = 'Employee_Emails_' + $i.tostring("00") + ".rdl"
    copy-item "$RDLToClone" "$ReportDirectory\$NewReportName"
    Write-Host $NewReportName
                       
}
