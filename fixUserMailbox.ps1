#Specify who we're working with
$UPN = "Andrew.Szczurek@ahima.org"
#Local exchange server
$ExServer = "chi-vm-excas.ahima.local"
#365 Domain - for remote routing address
$RoutingDomain = "ahimaorg.mail.onmicrosoft.com"

#Connect to 365 Exchange - only import select cmdlets so they don't conflict with the Exchange On Premise session
$RemoteSession = Connect-ExchangeOnline -UserPrincipalName chris.helmkamp@ahima.org
Import-PSSession $RemoteSession -CommandName Get-Mailbox

#Connect to local exchange - only import select cmdlets so they don't conflict with the Exchange Online session
$LocalSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "http://$ExServer/PowerShell/" `
      -Credential helmkampc_admin
Import-PSSession $LocalSession -CommandName Enable-RemoteMailbox, Set-RemoteMailbox

#Get the Alias and ExchangeGuid from 365
$Mailbox = Get-Mailbox $UPN
$Alias = $Mailbox.Alias
$ExchangeGUID = $Mailbox.ExchangeGuid

$Mailbox
$Alias
$ExchangeGUID

#Create a remote mailbox
Enable-RemoteMailbox $UPN -Alias $Alias -RemoteRoutingAddress "$Alias@$RoutingDomain"
#Set the Remote Mailbox GUID to match the 365 mailbox GUID
Set-RemoteMailbox $Alias -ExchangeGuid $ExchangeGUID

Get-Mailbox $Alias

#Remove sessions
Get-PSSession | Remove-PSSession