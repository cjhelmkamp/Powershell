<#
.SYNOPSIS
    Send admins an email to summerize accounts that keep getting locked
.Description
    This script will read and cound the number of accounts locked out
    from the log file of the user account locked out script and then it
    will roll the logs. Its currntly setup for a weekly email 
.Notes
    Modified by Chris Helmkamp 2016.08.10

    The script it triggered by a schedualed task timer
    

#>
if (!(Test-Path C:\powershell\log\UserAccountLockedOut.log)) { exit 1 }
else
{

$SummeryEmail = "C:\powershell\SummeryEmail.htm"

$css = @”
<style type=’text/css’>
div {font-family: tahoma,verdana,arial;font-size: 11px;color: #38465A;}
div.1 {font-family: tahoma,verdana,arial;font-size: 13px;color: #38465A;}
th {font-family: tahoma,verdana,arial;font-size: 13px;color: #000000;}
td {font-family: tahoma,verdana,arial;font-size: 11px;color: #38465A;}
a {color: #38465A;}
.dt {background-color: #DDE1E8;color: #556988;font-weight: bold;padding-left: 4px;}
.dt1 {background-color: #F1F3F6;}
.dt2 {background-color: #F8F9FA;}
</style>
“@

$HTML=@"
$css 
<div class="1">
<title>Account locked out Summery</title> 
<!--mce:0--> 
"@



Import-Csv "C:\powershell\log\UserAccountLockedOut.log"|
Group-Object "Account Name","Caller Computer Name"|
Sort-Object Count -Descending | 
Select-Object count,name | ForEach-Object{
    [PSCustomObject]@{
    'Account Name' = ($_.Name -split ", ")[0]
    'Caller Computer Name' = ($_.Name -split ", ")[1]
    'Count' = $_.Count
    }
} | ConvertTo-Html -Property "Account Name","Caller Computer Name","Count" -head $HTML -body  "<H3> Summery of locked accounts in the Past Week</H3>"| 
     Out-File $SummeryEmail -Append

$MailBody= Get-Content $SummeryEmail 
$MailSubject= "Account locked out Summery" 
$SmtpClient = New-Object system.net.mail.smtpClient 
$SmtpClient.host = "smtp.mail.net" 
$MailMessage = New-Object system.net.mail.mailmessage 
$MailMessage.from = "Account.Locked.Out@gov.us" 
$MailMessage.To.add("lockout@fbi.net") 
$MailMessage.Subject = $MailSubject 
$MailMessage.IsBodyHtml = 1 
$MailMessage.Body = $MailBody 
$SmtpClient.Send($MailMessage) 

del $SummeryEmail

Move-Item "C:\powershell\log\UserAccountLockedOut.log" "C:\powershell\log\$(get-date -f yyyyMMdd)UserAccountLockedOut.log" -Force
}

$logpath = 'C:\powershell\log'
$daysToDelete = 30
 
# Define the starting point for deleting files
$fileAging = (Get-Date).AddDays(-$daysToDelete)
 
# Scan directory and get objects to be removed
$filesBuffer = Get-ChildItem -Path $logpath -ErrorAction 'Stop' | Where-Object {$_.lastWriteTime -lt $fileAging}
 
if ($filesBuffer -eq $null)	{ exit 1 }
else {
	foreach ($tmpFile in $filesBuffer) {
	# The force switch is used to workaround the permissions related error in PowerShell
	Remove-Item $tmpFile.fullname -Recurse -Force
	}
}
