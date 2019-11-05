Function New-O365ExchangeSession()
{
    param(
    [parameter(mandatory=$true)]
    $365master)
    #close any old remote session
    Get-PSSession | Remove-PSSession -Confirm:$false
    #start a new office 365 remote session
    $365session = New-PSSession -ConfigurationName "Microsoft.Exchange" -ConnectionUri 'https://ps.outlook.com/powershell' -Credential $365master -Authentication Basic -AllowRedirection
    $office365 = Import-PSSession $365session
}

#Starting month
$mons = "08","09",10,11,12
$365master = get-credential chris.helmkamp@ahima.org
$WarningPreference = 'SilentlyContinue'
Write-Host "Conneting to Office 365 Exchange"
Write-Host ""
New-O365ExchangeSession $365master
Write-host "Starting Delete"
Write-host ""

foreach($mon_num in $mons) {
    Write-Host "Deleteing up to month $mon_num"
    $days = "05",10,15,20,25,30

    foreach ($day_num in $days) {
        write-host "Deleting up to day $day_num"
        Search-Mailbox -Identity aptifyo365relay@ahima.org `
        -SearchQuery "Received:01/01/2017..$mon_num/$day_num/2018" `
        -DeleteContent -Confirm:$false -Force -ErrorAction Stop 
        "------------------------------"
        #Call the office365 remote session function to close the current one and open a new session
        New-O365ExchangeSession $365master   
    } #end of day_num while loop
} #end of mon_num
Write-host ""
Write-Host "Done."