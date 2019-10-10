Function HideDisabledAccountsGAL {

##########################################################################################################
<#
.SYNOPSIS
    Finds potentially stale user and computer accounts. Can also disable and move accounts if instructed.

.DESCRIPTION

    Uses the lastLogonTimeStamp and pwdLastSet attributes to find user or computer accounts that are potentially
    stale. Evaluates the value of lastLogonTimeStamp and pwdLastSet aganst a supplied stale threshold: 60, 90,
    120, 150, 180 days. Where the value of either lastLogonTimeStamp and pwdLastSet is older than today minus 
    the stale threshold an account is consider stale.

    Can search for stale accounts in a specific OU or in the whole domain.

    Can also disable any stale accounts and move them to a specified, target OU.

    
    IMPORTANT: * Consider searching in specific OUs rather than the whole domain
               * Use the function WITHOUT the -Hide option to produce a report of potentially stale accounts
               * Evaluate the report... this is essential!
               * When using -Hide consider using the -WhatIf and -Confirm parameters

.EXAMPLE

    Disable-ADStaleAccount -Domain fabrikam.com -StaleThreshold 90 -AccountType User
                           
    List user accounts that have a lastLogonTimeStamp and pwdLastSet value older than today minus 90
    days for the fabrikam.com domain.

.EXAMPLE

    Disable-ADStaleAccount -Domain contoso 
                           -TargetOu "OU=Computer Accounts,DC=contoso,DC=com"
                           
    List computer accounts, from the Computer Accounts OU, that have a lastLogonTimeStamp and pwdLastSet 
    value older than today minus 120 days for the contoso domain.

.NOTES
    THIS CODE-SAMPLE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED 
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR 
    FITNESS FOR A PARTICULAR PURPOSE.

    This sample is not supported under any Microsoft standard support program or service. 
    The script is provided AS IS without warranty of any kind. Microsoft further disclaims all
    implied warranties including, without limitation, any implied warranties of merchantability
    or of fitness for a particular purpose. The entire risk arising out of the use or performance
    of the sample and documentation remains with you. In no event shall Microsoft, its authors,
    or anyone else involved in the creation, production, or delivery of the script be liable for 
    any damages whatsoever (including, without limitation, damages for loss of business profits, 
    business interruption, loss of business information, or other pecuniary loss) arising out of 
    the use of or inability to use the sample or documentation, even if Microsoft has been advised 
    of the possibility of such damages, rising out of the use of or inability to use the sample script, 
    even if Microsoft has been advised of the possibility of such damages. 

#>
##########################################################################################################

Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010

try{
    Import-Module ActiveDirectory -ErrorAction Stop
}
catch
{
    throw "Module ActiveDirectory not Installed"
    exit
}

#Requires -version 3
#Requires -modules ActiveDirectory

    #Define and validate parameters
    [CmdletBinding(SupportsShouldProcess)]
    Param(
          #The target domain
          [parameter(Mandatory,Position=1)]
          [ValidateScript({Get-ADDomain -Server $_})] 
          [String]$Domain,
          
          #The number of days before which accounts are considered stale
          #[parameter(Mandatory,Position=2)]
          #[ValidateSet(60,90,120,150,180)] 
          #[Int32]$StaleThreshold,

          #The OU we use as the basis of our search
          #[parameter(Position=4)]
          #[ValidateScript({Get-ADOrganizationalUnit -Identity $_ -Server $Domain})] 
          #[String]$SourceOu,

          #The OU to where we Hide accounts
          [parameter(Position=5)]
          [ValidateScript({Get-ADOrganizationalUnit -Identity $_ -Server $Domain})] 
          [String]$TargetOu,
          
          #Whether to disable and move the accounts
          [switch]
          $Hide
          )
    
    #Obtain a datetime object before which accounts are considered stale
    #$DaysAgo = (Get-Date).AddDays(-$StaleThreshold) 


    #Check whether we have a source OU for our search
    if ($TargetOU) {

        #Find disabled users that do not have the msExchHideFromAddressLists property and add it
        #Get-ADUser -Filter {(mail -like "*") -and(enabled -eq $false) -and(msExchHideFromAddressLists -notlike "*")} | Set-adUser -Add @{msExchHideFromAddressLists="TRUE"}

        #Search for stale accounts in our source OU and assign any resultant objects to a variable
        $DisabledAccounts = &"Get-ADUser" -Filter {(mail -like "*") -and(enabled -eq $false) -and(msExchHideFromAddressLists -eq $false) -and(msExchResourceMetaData -notlike"*Room")} `
                                               -Properties msExchHideFromAddressLists,Description `
                                               -SearchBase $TargetOu `
                                               -Server $Domain
    }
    else {

        #Search for stale accounts and assign any resultant objects to a variable
        $DisabledAccounts = &"Get-ADUser" -Filter {(mail -like "*") -and(enabled -eq $false) -and(msExchHideFromAddressLists -eq $false) -and(msExchResourceMetaData -notlike"*Room")} `
                                               -Properties PwdLastSet,LastLogonTimeStamp,Description `
                                               -Server $Domain

    }   #end of else ($TargetOU)


    #Check whether we have the disable switch activated
    if ($Hide) {

        #Now check we have a targetOU
        if ($TargetOu) {

            #Loop through the stale accounts
            foreach ($DisabledAccount in $DisabledAccounts) {

                #Activate the -WhatIf and -Confirm risk mitigation common parameters
                if ($PSCmdlet.ShouldProcess($DisabledAccount, "Hide from the GAL")) {

                    #Hide the account
                    &"Set-ADUser" -Identity $DisabledAccount -Replace @{msExchHideFromAddressLists="TRUE"}

                    #Check whether the hide (last action) was successful
                    if ($?) {

                        #Move the disable account
                        #Move-ADObject -Identity $DisabledAccount -TargetPath $TargetOu -Server $Domain

                        #Check whether the move (last action) was successful
                        #if ($?) {

                        #Write a message to screen
                        Write-Host "$DisabledAccount has been hidden from the GAL"

                        }   #end of if ($?) - move

                    else {

                            Write-Warning "$DisabledAccount has not been hidden"


                        }   #end of else ($?) - move


                    #}   #end of if ($?) - disable

                    Else {

                        #Write an error message
                        Write-Error "Unable to hide $DisabledAccount from GAL"

                    }   #end of else ($?) - disable


                }   #end of if ($PSCmdlet.ShouldProcess($DisabledAccount, "DISABLED and MOVED to $TargetOU"))


            }   #end of foreach ($DisabledAccount in $DisabledAccounts)


        }   #end of if ($targetOu)

        else { 

            #Write an error message
            Write-Error "If you use the -Hide switch you must specifiy a target OU." 


        }   #end of else ($targetOu)


    }   #end of if ($Hide)

    #If we don't have the disabled switch activated perform the following action
    else {

        #Output the stale accounts found with human-readable properties
        $DisabledAccounts | Select-Object -Property DistinguishedName,Name,Enabled,Description, `
                         @{Name="PwdLastSet";Expression={[datetime]::FromFileTime($_.PwdLastSet)}}, `
                         @{Name="LastLogonTimeStamp";Expression={[datetime]::FromFileTime($_.LastLogonTimeStamp)}} 


    }   #end of else ($Hide)


}   #end of Function Disable-ADStaleAccount
