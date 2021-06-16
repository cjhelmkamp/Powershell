<#

.EXAMPLE
  PasswordChangeNotification.ps1 -smtpServer mail.domain.com -expireInDays 21 -from "IT Support <support@domain.com>" -Logging -LogPath "c:\logFiles" -testing -testRecipient support@domain.com
  
  This example will use mail.domain.com as an smtp server, notify users whose password expires in less than 21 days, send mail from support@domain.com
  Logging is enabled, log path is c:\logfiles
  Testing is enabled, and test recipient is support@domain.com
.EXAMPLE
  PasswordChangeNotification.ps1 -smtpServer mail.domain.com -expireInDays 21 -from "IT Support <support@domain.com>" -reportTo myaddress@domain.com -interval 1,2,5,10,15
  
  This example will use mail.domain.com as an smtp server, notify users whose password expires in less than 21 days, send mail from support@domain.com
  Report is enabled, reports sent to myaddress@domain.com
  Interval is used, and emails will be sent to people whose password expires in less than 21 days if the script is run, with 15, 10, 5, 2 or 1 days remaining untill password expires.

#>

.\PasswordChangeNotification.ps1 `
-smtpServer smtp.office365.com `
-expireInDays 14 `
-from "AHIMA Support <support@example.net>" `
-Logging -LogPath "c:\tmp" `
-testing -testRecipient dude@example.net `
-reportTo support@example.net `
-interval 1,2,3,5,7,11

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
<#
$username = "support@example.net"
$password = ConvertTo-SecureString "SuperSecurePass!!"-AsPlainText -Force
$UserCredential = New-Object System.Management.Automation.PSCredential($username,$password)

$smtpServer = "smtp.office365.com"
$emailaddress = "dude@example.net"
$subject = "Test Email PS"
$body = @"
<html>
<head>
<style type='text/css'>
    body {margin: 0in;font-size: 15px;font-family: Calibri,sans-serif;}
    p {margin: 0in;font-size: 15px;font-family: Calibri,sans-serif;}
    li {margin-top:0in;margin-right:0in;margin-bottom:0in;margin-left:0in;font-size:15px;font-family:"Calibri",sans-serif;}
</style>
</head>
<body>
This is a test
</body>
</html>
"@

$SmtpClient = New-Object system.net.mail.smtpClient
$SmtpClient.host = $smtpServer #"smtp.office365.com" 
$SmtpClient.Credentials = $UserCredential
$SmtpClient.EnableSsl = "true"
$SmtpClient.Port = "587"

$MailMessage = New-Object system.net.mail.mailmessage 
$MailMessage.from = $username
$MailMessage.To.add($emailaddress)
$MailMessage.Subject = $subject
$MailMessage.IsBodyHtml = 1 
$MailMessage.Body = $body
$SmtpClient.Send($MailMessage) 
#>
