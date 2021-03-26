<#
.Synopsis
   Script to Automated Email Reminders when Users Passwords due to Expire.
.DESCRIPTION
   Script to Automated Email Reminders when Users Passwords due to Expire.
   Robert Pearman / WindowsServerEssentials.com
   Version 2.9 August 2018
   Requires: Windows PowerShell Module for Active Directory
   For assistance and ideas, visit the TechNet Gallery Q&A Page. http://gallery.technet.microsoft.com/Password-Expiry-Email-177c3e27/view/Discussions#content
   Alternativley visit my youtube channel, https://www.youtube.com/robtitlerequired
   Videos are available to cover most questions, some videos are based on the earlier version which used static variables, however most of the code
   can still be applied to this version, for example for targeting groups, or email design.
   Please take a look at the existing Q&A as many questions are simply repeating earlier ones, with the same answers!
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
param(
    # $smtpServer Enter Your SMTP Server Hostname or IP Address
    [Parameter(Mandatory=$True,Position=0)]
    [ValidateNotNull()]
    [string]$smtpServer,
    # Notify Users if Expiry Less than X Days
    [Parameter(Mandatory=$True,Position=1)]
    [ValidateNotNull()]
    [int]$expireInDays,
    # From Address, eg "IT Support <support@domain.com>"
    [Parameter(Mandatory=$True,Position=2)]
    [ValidateNotNull()]
    [string]$from,
    [Parameter(Position=3)]
    [switch]$logging,
    # Log File Path
    [Parameter(Position=4)]
    [string]$logPath,
    # Testing Enabled
    [Parameter(Position=5)]
    [switch]$testing,
    # Test Recipient, eg recipient@domain.com
    [Parameter(Position=6)]
    [string]$testRecipient,
    # Output more detailed status to console
    [Parameter(Position=7)]
    [switch]$status,
    # Log file recipient
    [Parameter(Position=8)]
    [string]$reportto,
    # Notification Interval
    [Parameter(Position=9)]
    [array]$interval
)
###################################################################################################################
# Time / Date Info
$start = [datetime]::Now
$midnight = $start.Date.AddDays(1)
$timeToMidnight = New-TimeSpan -Start $start -end $midnight.Date
$midnight2 = $start.Date.AddDays(2)
$timeToMidnight2 = New-TimeSpan -Start $start -end $midnight2.Date
# System Settings
$textEncoding = [System.Text.Encoding]::UTF8
$today = $start
# End System Settings

# Create password file as user that runs script
# $path = "c:\powershell\smtp.txt"
# read-host -assecurestring | convertfrom-securestring | out-file $path

# Import Credential
# $password = Get-Content -path C:\powershell\smtp.txt | ConvertTo-SecureString
$username = "support@ahima.org"
$password = ConvertTo-SecureString "EAT-the-cake-2019!"-AsPlainText -Force
$UserCredential = New-Object System.Management.Automation.PSCredential($username,$password)


# Load AD Module
try{
    Import-Module ActiveDirectory -ErrorAction Stop
}
catch{
    Write-Warning "Unable to load Active Directory PowerShell Module"
}
# Set Output Formatting - Padding characters
$padVal = "20"
Write-Output "Script Loaded"
Write-Output "*** Settings Summary ***"
$smtpServerLabel = "SMTP Server".PadRight($padVal," ")
$expireInDaysLabel = "Expire in Days".PadRight($padVal," ")
$fromLabel = "From".PadRight($padVal," ")
$testLabel = "Testing".PadRight($padVal," ")
$testRecipientLabel = "Test Recipient".PadRight($padVal," ")
$logLabel = "Logging".PadRight($padVal," ")
$logPathLabel = "Log Path".PadRight($padVal," ")
$reportToLabel = "Report Recipient".PadRight($padVal," ")
$interValLabel = "Intervals".PadRight($padval," ")
# Testing Values
if($testing)
{
    if(($testRecipient) -eq $null)
    {
        Write-Output "No Test Recipient Specified"
        Exit
    }
}
# Logging Values
if($logging)
{
    if(($logPath) -eq $null)
    {
        $logPath = $PSScriptRoot
    }
}
# Output Summary Information
Write-Output "$smtpServerLabel : $smtpServer"
Write-Output "$expireInDaysLabel : $expireInDays"
Write-Output "$fromLabel : $from"
Write-Output "$logLabel : $logging"
Write-Output "$logPathLabel : $logPath"
Write-Output "$testLabel : $testing"
Write-Output "$testRecipientLabel : $testRecipient"
Write-Output "$reportToLabel : $reportto"
Write-Output "$interValLabel : $interval"
Write-Output "*".PadRight(25,"*")
# Get Users From AD who are Enabled, Passwords Expire and are Not Currently Expired
# To target a specific OU - use the -searchBase Parameter -https://docs.microsoft.com/en-us/powershell/module/addsadministration/get-aduser
# You can target specific group members using Get-AdGroupMember, explained here https://www.youtube.com/watch?v=4CX9qMcECVQ 
# based on earlier version but method still works here.
$users = get-aduser -filter {(Enabled -eq $true) -and (PasswordNeverExpires -eq $false)} -properties Name, PasswordNeverExpires, PasswordExpired, PasswordLastSet, EmailAddress | where { $_.passwordexpired -eq $false }
# Count Users
$usersCount = ($users | Measure-Object).Count
Write-Output "Found $usersCount User Objects"
# Collect Domain Password Policy Information
$defaultMaxPasswordAge = (Get-ADDefaultDomainPasswordPolicy -ErrorAction Stop).MaxPasswordAge.Days 
Write-Output "Domain Default Password Age: $defaultMaxPasswordAge"
# Collect Users
$colUsers = @()
# Process Each User for Password Expiry
Write-Output "Process User Objects"
foreach ($user in $users)
{
    # Store User information
    $Name = $user.Name
    $emailaddress = $user.emailaddress
    $passwordSetDate = $user.PasswordLastSet
    $samAccountName = $user.SamAccountName
    $pwdLastSet = $user.PasswordLastSet
    # Check for Fine Grained Password
    $maxPasswordAge = $defaultMaxPasswordAge
    $PasswordPol = (Get-AduserResultantPasswordPolicy $user) 
    if (($PasswordPol) -ne $null)
    {
        $maxPasswordAge = ($PasswordPol).MaxPasswordAge.Days
    }
    # Create User Object
    $userObj = New-Object System.Object
    $expireson = $pwdLastSet.AddDays($maxPasswordAge)
    $daysToExpire = New-TimeSpan -Start $today -End $Expireson
    # Round Expiry Date Up or Down
    if(($daysToExpire.Days -eq "0") -and ($daysToExpire.TotalHours -le $timeToMidnight.TotalHours))
    {
        $userObj | Add-Member -Type NoteProperty -Name UserMessage -Value "today."
    }
    if(($daysToExpire.Days -eq "0") -and ($daysToExpire.TotalHours -gt $timeToMidnight.TotalHours) -or ($daysToExpire.Days -eq "1") -and ($daysToExpire.TotalHours -le $timeToMidnight2.TotalHours))
    {
        $userObj | Add-Member -Type NoteProperty -Name UserMessage -Value "tomorrow."
    }
    if(($daysToExpire.Days -ge "1") -and ($daysToExpire.TotalHours -gt $timeToMidnight2.TotalHours))
    {
        $days = $daysToExpire.TotalDays
        $days = [math]::Round($days)
        $userObj | Add-Member -Type NoteProperty -Name UserMessage -Value "in $days days."
    }
    $daysToExpire = [math]::Round($daysToExpire.TotalDays)
    $userObj | Add-Member -Type NoteProperty -Name UserName -Value $samAccountName
    $userObj | Add-Member -Type NoteProperty -Name Name -Value $Name
    $userObj | Add-Member -Type NoteProperty -Name EmailAddress -Value $emailAddress
    $userObj | Add-Member -Type NoteProperty -Name PasswordSet -Value $pwdLastSet
    $userObj | Add-Member -Type NoteProperty -Name DaysToExpire -Value $daysToExpire
    $userObj | Add-Member -Type NoteProperty -Name ExpiresOn -Value $expiresOn
    # Add userObj to colusers array
    $colUsers += $userObj
}
# Count Users
$colUsersCount = ($colUsers | Measure-Object).Count
Write-Output "$colusersCount Users processed"
# Select Users to Notify
$notifyUsers = $colUsers | where { $_.DaysToExpire -le $expireInDays}
$notifiedUsers = @()
$notifyCount = ($notifyUsers | Measure-Object).Count
Write-Output "$notifyCount Users with expiring passwords within $expireInDays Days"
# Process notifyusers
foreach ($user in $notifyUsers)
{
    # Email Address
    $samAccountName = $user.UserName
    $emailAddress = $user.EmailAddress
    # Set Greeting Message
    $name = $user.Name
    $messageDays = $user.UserMessage
    # Subject Setting
    $subject="Your password will expire $messageDays"
    # Email Body Set Here, Note You can use HTML, including Images.
    # examples here https://youtu.be/iwvQ5tPqgW0 
    $body=@"
    <html>
    <head>
    <style type='text/css'>
        body {margin: 0in;font-size: 15px;font-family: Calibri,sans-serif;}
        p {margin: 0in;font-size: 15px;font-family: Calibri,sans-serif;}
        li {margin-top:0in;margin-right:0in;margin-bottom:0in;margin-left:0in;font-size:15px;font-family:"Calibri",sans-serif;}
    </style>
    </head>
    <body>
        Dear $name,
        <p>&nbsp;</p>
        <p> Your Password will expire $messageDays. Please follow the below process to change your password before it expires.</p>
        <p>&nbsp;</p>
    <p><strong>From your Ahima Windows laptop</strong></p>
    <ol start="1" style="margin-bottom:0in;margin-top:0in;" type="1">
        <li>Log onto your computer as usual and make sure you are connected to the internet.</li>
        <li>If you are <strong>not in the office</strong>, logon and <strong>connect to VPN</strong>.</li>
        <li>Press <strong>Ctrl-Alt-Del</strong> and click on &quot;<strong>Change Password</strong>&quot;.</li>
        <li>Fill in your old password and set a new password (password requirements below).</li>
        <li>Press OK to return to your desktop.</li>
    </ol>
    <p>&nbsp;</p>
    <p><strong>Password change from Microsoft.com (MAC and Contract Users)</strong></p>
    <ol start="1" style="margin-bottom:0in;margin-top:0in;" type="1">
        <li>Go to: <a href="https://account.activedirectory.windowsazure.com/ChangePassword.aspx">https://account.activedirectory.windowsazure.com/ChangePassword.aspx</a></li>
        <li>Login with your ahima.org email address</li>
        <li>Enter your new password</li>
        <li>Update your password for Microsoft Apps and VPN</li>
    </ol>
    <p>&nbsp;</p>
    <p><strong>Password Policy</strong></p>
    <ul style="margin-bottom:0in;margin-top:0in;" type="disc">
        <li>Must be changed every 90 days</li>
        <li>Not the previous 10 passwords</li>
        <li>Password Requirements<ul style="margin-bottom:0in;margin-top:0in;" type="circle">
                <li>Cannot use the account name</li>
                <li>At least 8 characters</li>
                <li>3 types of symbols must be used in the password<ul style="margin-bottom:0in;margin-top:0in;" type="square">
                        <li>Numbers (0&ndash;9)</li>
                        <li>Uppercase letters (A-Z)</li>
                        <li>Lowercase letters (a-z)</li>
                        <li>Special characters ($, #, %, etc.)</li>
                    </ul>
                </li>
            </ul>
        </li>
        <li>Recommendation: Use a passphrase&nbsp;<ul style="margin-bottom:0in;margin-top:0in;" type="circle">
                <li>CantStopBeliving!</li>
                <li>MyKidsLoveCookies3</li>
            </ul>
        </li>
    </ul>
    <p>&nbsp;</p>
    <p>For immediate help call the helpdesk at <strong>312.233.1071</strong></p>
    <p>&nbsp;</p>
    <p>Thanks,</p>
    <p>&nbsp;</p>
    <p>IT Support</p>
    <p><a href="mailto:support@ahima.org">support@ahima.org</a></p>
    <p><strong>312.233.1071</strong></p>
    </body>
    </html>
"@
    # If Testing Is Enabled - Email Administrator
    if($testing)
    {
        $emailaddress = $testRecipient
    } # End Testing
    # If a user has no email address listed
    if(($emailaddress) -eq $null)
    {
        $emailaddress = $testRecipient    
    }# End No Valid Email
    $samLabel = $samAccountName.PadRight($padVal," ")
    try{
        # If using interval paramter - follow this section
        if($interval)
        {
            $daysToExpire = [int]$user.DaysToExpire
            # check interval array for expiry days
            if(($interval) -Contains($daysToExpire))
            {
                # if using status - output information to console
                if($status)
                {
                    Write-Output "Sending Email : $samLabel : $emailAddress"
                }
                # Send message - if you need to use SMTP authentication watch this video https://youtu.be/_-JHzG_LNvw
                # send-mailmessage is depreciated
                # Send-Mailmessage -smtpServer $smtpServer -from $from -to $emailaddress -subject $subject -body $body -bodyasHTML -priority High -Encoding $textEncoding -ErrorAction Stop

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

                $user | Add-Member -MemberType NoteProperty -Name SendMail -Value "OK"
            }
            else
            {
                # if using status - output information to console
                # No Message sent
                if($status)
                {
                    Write-Output "Sending Email : $samLabel : $emailAddress : Skipped - Interval"
                }
                $user | Add-Member -MemberType NoteProperty -Name SendMail -Value "Skipped - Interval"
            }
        }
        else
        {
            # if not using interval paramter - follow this section
            # if using status - output information to console
            if($status)
            {
                Write-Output "Sending Email : $samLabel : $emailAddress"
            }
            # send-mailmessage is depreciated
            # Send-Mailmessage -smtpServer $smtpServer -from $from -to $emailaddress -subject $subject -body $body -bodyasHTML -priority High -Encoding $textEncoding -ErrorAction Stop
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
            
            $user | Add-Member -MemberType NoteProperty -Name SendMail -Value "OK"
        }
    }
    catch{
        # error section
        $errorMessage = $_.exception.Message
        # if using status - output information to console
        if($status)
        {
           $errorMessage
        }
        $user | Add-Member -MemberType NoteProperty -Name SendMail -Value $errorMessage    
    }
    $notifiedUsers += $user
}
if($logging)
{
    # Create Log File
    Write-Output "Creating Log File"
    $day = $today.Day
    $month = $today.Month
    $year = $today.Year
    $date = "$day-$month-$year"
    $logFileName = "$date-PasswordLog.csv"
    if(($logPath.EndsWith("\")))
    {
       $logPath = $logPath -Replace ".$"
    }
    $logFile = $logPath, $logFileName -join "\"
    Write-Output "Log Output: $logfile"
    $notifiedUsers | Export-CSV $logFile

    $head = @"
    <head>
    <style type='text/css'>
        body {margin: 0in;font-size: 15px;font-family: Calibri,sans-serif;}
        p {margin: 0in;font-size: 15px;font-family: Calibri,sans-serif;}
        li {margin-top:0in;margin-right:0in;margin-bottom:0in;margin-left:0in;font-size:15px;font-family:"Calibri",sans-serif;}
    </style>
    </head>
"@
    $notifiedUsers | ConvertTo-Html -Property "UserName","Name","EmailAddress","PasswordSet","DaysToExpire","ExpiresOn" -head $head -body "<h3> $reportSubject </h3>" | Out-File -FilePath $logPath SummaryEmail.html
    if($reportTo)
    {
        $reportSubject = "[INFO] Password Expiry Report"
        #$reportBody = "Password Expiry Report Attached"
        $reportBody = $notifiedUsers | ConvertTo-Html -Property "UserName","Name","EmailAddress","PasswordSet","DaysToExpire","ExpiresOn" -head $head -body "<h3> $reportSubject </h3>"
        try{
            #Send-Mailmessage -smtpServer $smtpServer -from $from -to $reportTo -subject $reportSubject -body $reportbody -bodyasHTML -priority High -Encoding $textEncoding -Attachments $logFile -ErrorAction Stop 

            $SmtpClient = New-Object system.net.mail.smtpClient 
            $SmtpClient.host = $smtpServer #"smtp.office365.com" 
            $SmtpClient.Credentials = $UserCredential
            $SmtpClient.EnableSsl = "true"
            $SmtpClient.Port = "587"

            $MailMessage = New-Object system.net.mail.mailmessage
            $MailMessage.from = $username
            $MailMessage.To.add($reportTo)
            $MailMessage.Subject = $reportSubject
            $MailMessage.IsBodyHtml = 1 
            $MailMessage.Body = $reportbody
            
            $SmtpClient.Send($MailMessage) 
        }
        catch{
            $errorMessage = $_.Exception.Message
            Write-Output $errorMessage
        }
    }
}
$notifiedUsers | select UserName,Name,EmailAddress,PasswordSet,DaysToExpire,ExpiresOn | sort DaystoExpire | FT -autoSize

$stop = [datetime]::Now
$runTime = New-TimeSpan $start $stop
Write-Output "Script Runtime: $runtime"
# End