Function New-O365ExchangeSession()
{
    param(
    [parameter(mandatory=$true)]
    $365master)
    #close any old remote session
    Get-PSSession | Remove-PSSession -Confirm:$false
    #start a new office 365 remote session
    $365session = New-PSSession -ConfigurationName "Microsoft.Exchange" -ConnectionUri 'https://ps.outlook.com/powershell' -Credential $365master -Authentication Basic
    -AllowRedirection
    $office365 = Import-PSSession $365session
}

 
#Main
$Offset=0;
$PageSize=1000;
$mbxMax=(import-csv users.csv).count
$file = "office365$((get-date).tostring("yyyyMMdd")).csv"
$365master = get-credential ashour@mylab.onmicrosoft.com
New-O365ExchangeSession $365master # call the office365 remote connection function
do{   
    #Load the list of users from a csv file limited with the pageSize 1000 starting from the line $Offset + 1
    $mbxlist=@(import-csv users.csv|select-object -skip $Offset -First $PageSize)
    "Start at offset $($Offset) till $($Offset+$PageSize)"
    ForEach($mbx in $mbxlist)
       {
        "Start Processing $($mbx.alias)"
        $deviceinfo = Get-mobileDeviceStatistics -mailbox $mbx.alias | select @{name="mailbox"; expression={$_}},devicetype, devicemodel, devicefriendlyname, deviceos, lastsuccesssync
        If ($deviceinfo -ne $null)
            { 
            If (Test-Path $file)
                {
                $mbx.alias + ”,” + ($deviceinfo | ConvertTo-Csv)[2] | Out-File $file –Append
                #You can use –Encoding Unicode if you deal with Unicode characters like Arabic
                }
            Else
                {
                $deviceinfo | Export-Csv $file -Encoding ASCII -notypeinformation
                }
            $deviceinfo = $null
            }
      }
    "------------------------------"
    #Increase the start point for the next chunk
    $Offset+=$PageSize
    #Call the office365 remote session function to close the current one and open a new session
    New-O365ExchangeSession $365master
} while($offset -lt $mbxMax)