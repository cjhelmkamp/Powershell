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
# Create a new custom object to hold our result.

$disUsers = Get-ADUser -filter{Enabled -eq $false} -SearchBase "OU=Disabled Users,OU=Domain,DC=DOMAIN,DC=local"

foreach ($user in $disUsers)
{
    $uSam = $user.SamAccountName
    write-host "Checking Disabled User: $uSam"
     
    $sharedMB = Get-Mailbox -OrganizationalUnit "DOMAIN/Administrative/Email/Mailboxes" -WarningAction SilentlyContinue

    foreach ($mb in $sharedMB)
    {
        $contactObject = new-object PSObject
        
        $mbPer = Get-MailboxPermission $mb| where {$_.User -like "AHIMA_CHICAGO\$uSam"} #| select identity,User,Accessrights | ft
        
        if ($mbPer -ne $null)
        {
            #write-host "Mailbox Name: "$mb.Name
            
            #Add our data to $contactObject as attributes using the add-member commandlet
            $contactObject | add-member -membertype NoteProperty -name "Share Mailbox" -Value $mb.Name
            $contactObject | add-member -membertype NoteProperty -name "Disabled User" -Value $uSam 
            $contactObject | add-member -membertype NoteProperty -name "AccessRights" -Value $($mbPer.AccessRights)

            # Save the current $contactObject by appending it to $resultsArray ( += means append a new element to ‘me’)
            $resultsarray += $contactObject

            Remove-MailboxPermission -Identity $mb.identity -User "AHIMA_CHICAGO\$uSam" -AccessRights $mbPer.AccessRights -Confirm:$false -WarningAction SilentlyContinue
        }
    }
}
$resultsarray | Export-csv $ts"_DisabledPermissions.csv" -notypeinformation
