import-module ActiveDirectory

$MaxAge = 90
$OU = "OU=Users,OU=Ahima,DC=ahima,DC=local"
$properties=@("givenname","surname","userprincipalname","samaccountname","department","title","manager")

Get-AdUser -Filter * -Properties $properties  -SearchBase $OU | ? { 
     $_.Enabled -eq $true
     
}   | select $properties `
    | Sort Surname `
    | Export-Csv -Path "$((Get-Date).ToString('yyyy-MM-dd'))_UsersList.csv"