<#  
.SYNOPSIS 
    Get all mailboxes and find the ones that are not being used or mismanaged

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

$sharedMB = Get-Mailbox -OrganizationalUnit "ahima.local/Ahima/Administrative/Email/Mailboxes" -WarningAction SilentlyContinue #-ResultSize 10

foreach ($mb in $sharedMB)
{
    #write-host $mb
            
    $mbstats = get-mailboxstatistics $mb | where {$_.ItemCount -lt 100 -OR $_.ItemCount -gt 9999} #| select identity,User,Accessrights,isinherited | ft
    
        
    if ($mbStats -ne $null)
    {
        # Write-Host $mb " is poorly managed"
        
        $aduser = Get-ADUser $mb.SamAccountName -Properties description
        
        write-host $($aduser.description)

        $contactObject = new-object PSObject            
        #Add our data to $contactObject as attributes using the add-member commandlet
        $contactObject | add-member -membertype NoteProperty -name "Share Mailbox" -Value $mb.Name
        $contactObject | add-member -membertype NoteProperty -name "PrimarySMTP" -Value $mb.PrimarySmtpAddress
        $contactObject | add-member -membertype NoteProperty -name "Items" -Value $mbstats.ItemCount
        $contactObject | add-member -membertype NoteProperty -name "Del Items" -Value $mbstats.TotalDeletedItemSize
        $contactObject | add-member -membertype NoteProperty -name "Tot Items" -Value $mbstats.TotalItemSize
        $contactObject | add-member -membertype NoteProperty -name "Description" -Value $aduser.description
        
        # Save the current $contactObject by appending it to $resultsArray ( += means append a new element to ‘me’)
        $resultsarray += $contactObject
    }

} 

$resultsarray | Export-csv $ts"_BadMailboxes.csv" -notypeinformation