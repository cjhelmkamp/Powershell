<#
.SYNOPSIS
    Send admins an email when a user gets locked out
.Description
    This script will run when an event in task scheduler trips this to be run.
    It will pull information from the event and send an email to Admins
    alerting them to a locked out account. This should provide visability 
    for security and admin purposes.
.Notes
    Powershell User Account locked out Maxzor1908 *16/4/2013* 
    From https://gallery.technet.microsoft.com/scriptcenter/User-account-locked-out-2e3c3ec3

    Modified by Chris Helmkamp 2016.08.09
    Added csv log for weekly report

    This script is triggered by a scheduled task looking for Log: Security, Event ID: 4740
    account lockout.

#>
 
$Report= "c:\powershell\html.html" 
 
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
<title>Account locked out Report</title> 
<!--mce:0--> 
"@ 
 
$Account_Name = @{n='Account Name';e={$_.ReplacementStrings[-1]}} 
$Account_domain = @{n='Account Domain';e={$_.ReplacementStrings[-2]}} 
$Caller_Computer_Name = @{n='Caller Computer Name';e={$_.ReplacementStrings[-1]}} 
 
             
$event= Get-EventLog -LogName Security -InstanceId 4740 -Newest 1 | 
   Select TimeGenerated,ReplacementStrings,"Account Name","Account Domain","Caller Computer Name" | 
   % { 
     New-Object PSObject -Property @{ 
      "Account Name" = $_.ReplacementStrings[-7] 
      "Account Domain" = $_.ReplacementStrings[5] 
      "Caller Computer Name" = $_.ReplacementStrings[1] 
      Date = $_.TimeGenerated 
    } 
   } 
    
  $event | ConvertTo-Html -Property "Account Name","Account Domain","Caller Computer Name",Date -head $HTML -body  "<H3> User is locked in the Active Directory</H3>"| 
     Out-File $Report -Append 

$event | Export-Csv -Path C:\powershell\log\UserAccountLockedOut.log -Append #-ErrorAction SilentlyContinue
 
#Write-Host (Get-Content $Report)

$MailBody= Get-Content $Report 
$MailSubject= "User Account locked out" 
$SmtpClient = New-Object system.net.mail.smtpClient 
$SmtpClient.host = "smtp.mailserver.net" 
$MailMessage = New-Object system.net.mail.mailmessage 
$MailMessage.from = "Account.Locked.Out@domain.biz" 
$MailMessage.To.add("lockout@place.local") 
$MailMessage.Subject = $MailSubject 
$MailMessage.IsBodyHtml = 1 
$MailMessage.Body = $MailBody 
$SmtpClient.Send($MailMessage) 

del c:\powershell\html.html