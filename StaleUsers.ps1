import-module ActiveDirectory

$MaxAge = 90
$Searchbase = "OU=Disabled Users,OU=Ahima,DC=ahima,DC=local"
$dc = "ch1dc1.ahima.local"

Get-AdUser -Filter * -SearchBase $Searchbase -Server $dc -Properties PasswordLastSet,LastLogonDate,department,mail | ? { 
     $_.PasswordLastSet -lt [DateTime]::Now.Subtract([TimeSpan]::FromDays($MaxAge)) -or 
     $_.LastLogonDate -lt [DateTime]::Now.Subtract([TimeSpan]::FromDays($MaxAge)) -or
     $_.Enabled -eq $false -or
     $_.PasswordExpired -eq $true
} | Select GivenName,Surname,Department,LastLogonDate,PasswordLastSet,mail | Sort Surname,DistinguishedName | Export-Csv -Path "C:\Temp\$((Get-Date).ToString('yyyy-MM-dd'))_StaleUsers.csv"