#dircompworker.ps1


Start-Transcript -Path C:\powershell\log\dircompare.log -Append


# load PS functions 
. C:\Powershell\Compare-Directory.ps1

$hostname = hostname
$Report= "c:\powershell\dircomp.html" 
$refpath = "C:\inetpub\wwwroot\deployment\my.ahima.org"
$diffpath = "C:\inetpub\wwwroot\my.ahima.org"

$css = @"
<style type="text/css">
div {font-family: tahoma,verdana,arial;font-size: 11px;color: #38465A;}
div.1 {font-family: tahoma,verdana,arial;font-size: 13px;color: #38465A;}
th {font-family: tahoma,verdana,arial;font-size: 13px;color: #000000;}
td {font-family: tahoma,verdana,arial;font-size: 11px;color: #38465A;}
a {color: #38465A;}
.dt {background-color: #DDE1E8;color: #556988;font-weight: bold;padding-left: 4px;}
.dt1 {background-color: #F1F3F6;}
.dt2 {background-color: #F8F9FA;}
</style>
"@

$header=@"
$css 
<div class="1">
<title>New File Found $hostname </title> 
<!--mce:0--> 
"@

$body = @"
<h1>New File Found $hostname </h1>
<p>The following report was run on $(get-date).</p>
<p>
--- Side indicatiors ---</br>
<= Reference  Side $refpath</br>
=> Difference Side $diffpath</br>
------------------------</br>
</p>
"@

Try{

$result = Compare-Directory -ReferenceDirectory $refpath  -DifferenceDirectory $diffpath -Recurse
$result | ConvertTo-Html -head $header -body $body | Out-File $Report
$result

#roll the referance file forward
#del C:\Powershell\reflist.txt
#$base = Get-ChildItem -Recurse -path $diffpath
#Set-Content C:\Powershell\reflist.txt -Value $base

if ($result){
$MailBody= Get-Content $Report 
$MailSubject= "New File Found $hostname" 
$SmtpClient = New-Object system.net.mail.smtpClient 
$SmtpClient.host = "smtp.ahima.org" 
$MailMessage = New-Object system.net.mail.mailmessage 
$MailMessage.from = "$hostname@ahima.org" 
$MailMessage.To.add("chris.helmkamp@ahima.org") 
$MailMessage.Subject = $MailSubject 
$MailMessage.IsBodyHtml = 1 
$MailMessage.Body = $MailBody 
$SmtpClient.Send($MailMessage) 
}


del $Report

#Get-ChildItem -Recurse -path C:\inetpub\wwwroot\backup\2020-07-22-11-27-myAhima -Include 32sbuse.aspx
#Get-ChildItem -Recurse -path $diffpath -Include RadUploadTestFile

} catch {
write-output "$(get-date) Script failed to execute" >> C:\powershell\log\dircompare.log

$body = @"
<h1>Script failed $hostname </h1>
<p>The following report was run on $(get-date).</p>
<p>
"@
ConvertTo-Html -head $header -body $body | Out-File $Report

$MailBody= Get-Content $Report 
$MailSubject= "Script failed $hostname" 
$SmtpClient = New-Object system.net.mail.smtpClient 
$SmtpClient.host = "smtp.ahima.org" 
$MailMessage = New-Object system.net.mail.mailmessage 
$MailMessage.from = "$hostname@ahima.org" 
$MailMessage.To.add("chris.helmkamp@ahima.org") 
$MailMessage.Subject = $MailSubject 
$MailMessage.IsBodyHtml = 1 
$MailMessage.Body = $MailBody 
$SmtpClient.Send($MailMessage) 

del $Report

}
Stop-Transcript