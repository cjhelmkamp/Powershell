<# 
.SYNOPSIS 
	Auto-archives user email.
.DESCRIPTION 
    This script is designed to auto-archive user email from exchange 2010 to a fileshare.
.NOTES 
    File Name  : EmailArchiver.ps1
    Author     : Chris Helmkamp 
    Licenced under GPLv3  
.LINK 
	https://github.com
    License: http://www.gnu.org/copyleft/gpl.html
.PARAMETER EmailAddress
    Mandatory. Email address of the users mailbox. Ex: First.Lastname@email.com
.PARAMETER Remove
    Optional. Remove the account from AD and delete the mailbox from Exchange

.EXAMPLE 
	EmailArchiver -EmailAddress first.lastname@email.com -Remove
      ./EmailArchiver -EmailAddress firs.lastname@ahima.org 
#> 

Param
(
	[parameter(Mandatory=$true)]
	[alias("Email")] 
	[string]$EmailAddress,
		
	[parameter(Mandatory=$false)]
	[switch]$Remove
) #End Parameters

Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010

try{
    Import-Module ActiveDirectory -ErrorAction Stop
}
catch
{
    throw "Module ActiveDirectory not Installed"
    exit
}

#Check if the mailbox exsists
Try
{
    $mailbox = get-mailbox $EmailAddress -ErrorAction Stop
}
catch
{
    Throw "Unable to retrive mailbox for $EmailAddress"
}

# Static Variables
$ArchiveDir="\\SERVERNAME\Archive\"
$logdir = Split-Path $MyInvocation.MyCommand.Path
$incFunctions = $logdir + "\Logging_Functions.ps1"
$DebugPreference = "Continue"
$ts = date -f "yyyy-MM-dd_hh.mm.ss_"
$Usrlogname = "$ts"+"EmailArchiver.log"
$sam = $mailbox.SamAccountName
$UserArchiveDir = $ArchiveDir+$mailbox.SamAccountName+"\"

# use the . syntax to include the functions file
.$incFunctions

# Check if the folder exsists
try{
    $FileExists = Test-Path $UserArchiveDir -PathType Container
    if ($FileExists)
    {
        Write-host " "
        Write-host "User Archive Dir $UserArchiveDir Found."
        Write-host " "
    }
    Else
    {
        Write-host " "
        write-host "Archive folder $UserArchiveDir Not found."
        write-host "Createing folder...."
        Write-host " "
        New-Item -Path "$UserArchiveDir" -ItemType directory -ErrorAction Stop
        Write-host " "
    }
}
Catch
{
    Throw "Failed to create the folder $UserArchiveDir $($_.Exception.GetType().FullName) $($_.Exception.Message)"
}

# Start loggin in user archive dir
Try{
    $Usrlogfile = $UserArchiveDir+$Usrlogname
    Log-Start -LogDir $UserArchiveDir -LogName $Usrlogname -ScriptVersion ".01" 
}
Catch{
    Throw "Logging failed to start"
    exit 1
}

#Collect Size and DB location of mailbox
Log-Write -LogPath $Usrlogfile -LineValue "= = = Mailbox Stats for $EmailAddress = = ="
Log-Write -LogPath $Usrlogfile -LineValue " "
$mbstats = get-mailboxstatistics $EmailAddress
$Name=$mbstats.Displayname
$Database=$mbstats.Database
$ItemCount=$mbstats.ItemCount
$DeletedSize=$mbstats.TotalDeletedItemSize
$TotalItemSize=$mbstats.TotalItemSize

Log-Write -LogPath $Usrlogfile -LineValue "         Name: $Name"
Log-Write -LogPath $Usrlogfile -LineValue “        Email: $EmailAddress"
Log-Write -LogPath $Usrlogfile -LineValue “     Database: $Database"
Log-Write -LogPath $Usrlogfile -LineValue “    ItemCount: $ItemCount"
Log-Write -LogPath $Usrlogfile -LineValue “  DeletedSize: $DeletedSize"
Log-Write -LogPath $Usrlogfile -LineValue “TotalItemSize: $TotalItemSize"
Log-Write -LogPath $Usrlogfile -LineValue " "

# List out all smtp address in the log
for ($i=0;$i -lt $mailbox.EmailAddresses.Count; $i++)
 {
    $address = $mailbox.EmailAddresses[$i]
 
    if ($address.IsPrimaryAddress)
    { 
    	Log-Write -LogPath $Usrlogfile -LineValue "Primary Address: $($address.AddressString.ToString())"
    }
   else
   {
    	Log-Write -LogPath $Usrlogfile -LineValue "          Alias: $($address.AddressString.ToString())"
    }
   
 }
 Log-Write -LogPath $Usrlogfile -LineValue " "

# Export User mailbox
try
{
    $pstFile = $UserArchiveDir+$ts+$sam+"_mailbox.pst"
    Log-Write -LogPath $Usrlogfile -LineValue "Exporting to $pstFile"
    New-MailboxExportRequest -Mailbox $EmailAddress -FilePath $pstFile -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Log-Write -LogPath $Usrlogfile -LineValue "Export started..."
    Log-Write -LogPath $Usrlogfile -LineValue " "
}
catch
{
   Log-Error -LogPath $Usrlogfile -ErrorDesc “Caught an exception:” -ExitGracefully $false
   Log-Error -LogPath $Usrlogfile -ErrorDesc “Exception Type: $($_.Exception.GetType().FullName)” -ExitGracefully $false
   Log-Error -LogPath $Usrlogfile -ErrorDesc “Exception Message: $($_.Exception.Message)” -ExitGracefully $true
}

# Monitor the status of the export every 60 seconds
$exreq = Get-MailboxExportRequest -Mailbox $EmailAddress
$exstatus = $exreq.status
#write-host "Status: $exstatus"
While ($exstatus -eq "InProgress" -OR $exstatus -eq "Queued" ) {
    $Per = Get-MailboxExportRequest -Mailbox $EmailAddress | Get-MailboxExportRequestStatistics | Select -ExpandProperty PercentComplete
    Log-Write -LogPath $Usrlogfile -LineValue "$Per precent complete"
    Sleep 60
	$exreq = Get-MailboxExportRequest -Mailbox $EmailAddress
    $exstatus = $exreq.status
}

if ($exstatus -eq "Complete")
{
    Log-Write -LogPath $Usrlogfile -LineValue "Export Complete"
    Log-Write -LogPath $Usrlogfile -LineValue " "
}


# Remove the Mailbox if flag is set
if ($Remove)
{
    Log-Write -LogPath $Usrlogfile -LineValue "Removeing Mailbox and deleteing user..."
    Log-Write -LogPath $Usrlogfile -LineValue " "
    Remove-Mailbox $EmailAddress -Confirm:$false -WarningAction SilentlyContinue
}

#finally{
#do something even if the script fails and ends
#} #end finally
#>

Log-Finish -LogPath $Usrlogfile -NoExit $True

Log-Email -LogPath $Usrlogfile -EmailFrom "EmailArchiver@name.net" -EmailTo "YOUREMAIL@name.net" -EmailSubject "EmailArchiver Done"
