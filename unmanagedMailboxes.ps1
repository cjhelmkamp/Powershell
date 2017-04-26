<#  
.SYNOPSIS 
    Go though an OU of shared mailboxes and find the ones without users managing them.

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

$ts = date -f "yyyy-MM-dd"
# Declare an array to collect our result objects
$resultsarray =@()

$sharedMB = Get-Mailbox -OrganizationalUnit "ahima.local/Ahima/Administrative/Email/Mailboxes" -WarningAction SilentlyContinue

foreach ($mb in $sharedMB)
{
    #write-host $mb
            
    $mbPer = Get-MailboxPermission $mb | where {$_.IsInherited -eq $false -and $_.user -notlike "NT AUTHORITY\SELF"} #| select identity,User,Accessrights,isinherited | ft 
        
    if ($mbPer -eq $null)
    {
        # Write-Host $mb " is not managed"
        $mbstats = get-mailboxstatistics $mb

        $contactObject = new-object PSObject            
        #Add our data to $contactObject as attributes using the add-member commandlet
        $contactObject | add-member -membertype NoteProperty -name "Share Mailbox" -Value $mb.Name
        $contactObject | add-member -membertype NoteProperty -name "PrimarySMTP" -Value $mb.PrimarySmtpAddress
        $contactObject | add-member -membertype NoteProperty -name "Items" -Value $mbstats.ItemCount
        $contactObject | add-member -membertype NoteProperty -name "Del Items" -Value $mbstats.TotalDeletedItemSize
        $contactObject | add-member -membertype NoteProperty -name "Tot Items" -Value $mbstats.TotalItemSize
        
        # Save the current $contactObject by appending it to $resultsArray ( += means append a new element to ‘me’)
        $resultsarray += $contactObject
    }

} 

$resultsarray | Export-csv $ts"_UnmanagedMailboxes.csv" -notypeinformation

exit 0