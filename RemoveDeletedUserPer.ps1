<#  
.SYNOPSIS 
    Grabs all of the accounts in the disabled user OU and then searches though the Shared mailbox OU 
    checking each mailbox for permissions. If it finds the user has permissions to a mailbox it logs 
    the occurance and then removes those permissions.
.NOTES 
    Author: Chris Helmkamp
    
    The script are provided “AS IS” with no guarantees, no warranties, and they confer no rights.     
#>

Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010

try{
    Import-Module ActiveDirectory -ErrorAction Stop
}
catch
{
    throw "Module ActiveDirectory not Installed"
    exit
}

$ts = date -f "yyyy-MM-dd_hh.mm.ss_"
# Declare an array to collect our result objects
$resultsarray =@()

$OU = "DOMAIN/OUNAME/PATH/Email/Mailboxes"

$sharedMB = Get-Mailbox -OrganizationalUnit $OU -WarningAction SilentlyContinue
foreach ($mb in $sharedMB)
{
    #  write-host "Checking MB: "$mb.Name
    #  Get-MailboxPermission purchace | where {$_.User -Like "S-1-5-21-14*" -and $_.IsInherited -eq $false} | select identity,User,Accessrights,IsInherited | ft        
    $mbPer = Get-MailboxPermission $mb | where {$_.User -Like "S-1-5-21-14*" -and $_.IsInherited -eq $false}
        
    if ($mbPer -ne $null)
    {
        write-host "Mailbox Name: "$mb.Name
        
        foreach ($Per in $mbPer)
        {
            $contactObject = new-object PSObject            
            #Add our data to $contactObject as attributes using the add-member commandlet
            $contactObject | add-member -membertype NoteProperty -name "Share Mailbox" -Value $mb.Name
            $contactObject | add-member -membertype NoteProperty -name "Deleted User" -Value $Per.User 
            $contactObject | add-member -membertype NoteProperty -name "AccessRights" -Value $($Per.AccessRights)

            # Save the current $contactObject by appending it to $resultsArray ( += means append a new element to ‘me’)
            $resultsarray += $contactObject

            #write-host $Per.User
            
            Remove-MailboxPermission -Identity $mb.identity -User $Per.User -AccessRights $Per.AccessRights -Confirm:$false -inheritancetype all -Deny:$True
        }
    }
}

$resultsarray | Export-csv $ts"_DeletedUserPer.csv" -notypeinformation
