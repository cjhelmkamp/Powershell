
if (Test-ComputerSecureChannel){
	write-host "Connecting to Active Directory..."
	Import-Module ActiveDirectory
	write-host ""
}
else {
	write-host "DC server not found."
	write-host "Connect to corporate network and run"
	write-host -ForegroundColor Green "Import-Module ActiveDirectory"
	write-host ""
}

Import-Module ExchangeOnlineManagement

Connect-ExchangeOnline -UserPrincipalName chris.helmkamp@ahima.org

$OU = "OU=Administrative,OU=Ahima,DC=ahima,DC=local"
$properties=@("userprincipalname")

$upnnames = (Get-AdUser -Filter {userprincipalname -like '*'} -Properties $properties  -SearchBase $OU).userprincipalname

foreach ($upn in $upnnames) {
    $status = (Get-UserBriefingConfig -Identity $upn).IsEnabled
    write-host "Cortana is $status for $upn"
    if($status){
        write-host "Disabling Cortana for $upn"
        try {
            set-UserBriefingConfig -Identity $upn -Enabled $false
        }
        catch {
            Write-Host -ForegroundColor Red "Disabled failed for $upn"
        }
        
    } else {
        write-host "Cortana is disabled for $upn"
    }
} 


<#
Get-UserBriefingConfig -Identity BIG.FAX@ahima.org | Where-Object {$_.IsEnabled -eq $true}


if(Get-UserBriefingConfig -Identity chris.helmkamp@ahima.org | Where-Object {$_.IsEnabled -eq $true}){
    write-host "Cortana is enabled"
} else {
    write-host "Cortana is disabled"
}
#>