<# 
.SYNOPSIS 
	Compare two directories and send a notification of changes. 
.DESCRIPTION 
    This script will compare two directories or store the value of a diriecoty in a file for coparaeison. 
.NOTES 
    File Name  : DirCompare.ps1
    Author     : Chris Helmkamp 
    Licenced under GPLv3  
.LINK 
	https://github.com/cjhelmkamp/Powershell/blob/master/DirCompare.ps1
    License: http://www.gnu.org/copyleft/gpl.html
.PARAMETER EmailAddress
    Mandatory. Email address of the users mailbox. Ex: First.Lastname@email.com
.PARAMETER Remove
    Optional. Remove the account from AD and delete the mailbox from Exchange

.EXAMPLE 
	EmailArchiver -EmailAddress first.lastname@email.com -Remove
      ./EmailArchiver -EmailAddress firs.lastname@ahima.org 
#> 

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



if (test-path reflist.txt)
{
$refbase = Get-Content reflist.txt 
} else {
$base = Get-ChildItem -Recurse -path $refpath
Set-Content reflist.txt -Value $base
$refbase = Get-Content reflist.txt
}

$diff = Get-ChildItem -Recurse -path $diffpath

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
<#
write-host "--- Side indicatiors ---"
write-host "<= Reference  Side $refpath"
write-host "=> Difference Side $diffpath"
write-host "------------------------"#>

$results = Compare-Object -ReferenceObject $base -DifferenceObject $diff
$results | ConvertTo-Html -head $header -body $body | Out-File $Report

if ($results){
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


#del $Report

#Get-ChildItem -Recurse -path C:\inetpub\wwwroot\backup\2020-07-22-11-27-myAhima -Include 32sbuse.aspx
#Get-ChildItem -Recurse -path $diffpath -Include RadUploadTestFile