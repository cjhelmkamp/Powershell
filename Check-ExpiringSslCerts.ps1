[CmdletBinding(DefaultParametersetname="URLs in text file")]
Param(
  [ValidateSet('Text','Html','PSObject')]
  [string]$ReportType = 'Text',
  [int]$MinimumCertAgeDays = 60,
  [int]$TimeoutMilliseconds = 10000,
  [parameter(Mandatory=$false,ParameterSetName = "URLs in text file")]
  [string]$UrlsFile = '.\check-urls.txt',
  [parameter(Mandatory=$false,ParameterSetName = "List of URLs", 
        ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
  [string[]]$Urls
)
Begin 
{
    [string[]]$allUrls = @()
    $returnData = @()
    [bool]$ProcessedInputPipeLineByArrayItem = $false

    function CheckUrl ([string]$url, [array]$returnData)
    {
        [string]$details = $null
        if ($ReportType -eq "Html") 
        { 
            $stringHtmlEncoded = [System.Web.HttpUtility]::HtmlEncode($url)
            Write-Host "<tr><td>$stringHtmlEncoded</td>" 
        }
        if ($ReportType -eq "Text") { Write-Host Checking $url }
        $req = [Net.HttpWebRequest]::Create($url)
        $req.Timeout = $timeoutMilliseconds
        $req.AllowAutoRedirect = $false
        try 
        {
            $req.GetResponse() |Out-Null
            if ($req.ServicePoint.Certificate -eq $null) {$details = "No certificate in use for connection"}
        } 
        catch 
        {
            $details = "Exception while checking URL $url`: $_ "
        }
        if ($details -eq $null -or $details -eq "")
        {
            $certExpiresOnString = $req.ServicePoint.Certificate.GetExpirationDateString()
            #Write-Host "Certificate expires on (string): $certExpiresOnString"
            [datetime]$expiration = [System.DateTime]::Parse($req.ServicePoint.Certificate.GetExpirationDateString())
            #Write-Host "Certificate expires on (datetime): $expiration"
            [int]$certExpiresIn = ($expiration - $(get-date)).Days
            $certName = $req.ServicePoint.Certificate.GetName()
            $certPublicKeyString = $req.ServicePoint.Certificate.GetPublicKeyString()
            $certSerialNumber = $req.ServicePoint.Certificate.GetSerialNumberString()
            $certThumbprint = $req.ServicePoint.Certificate.GetCertHashString()
            $certEffectiveDate = $req.ServicePoint.Certificate.GetEffectiveDateString()
            $certIssuer = $req.ServicePoint.Certificate.GetIssuerName()
            if ($certExpiresIn -gt $minimumCertAgeDays)
            {
                if ($ReportType -eq "Html") 
                { 
                    Write-Host "<td>OKAY</td><td>$certExpiresIn</td><td>$expiration</td><td>&nbsp;</td></tr>"
                }
                if ($ReportType -eq "Text") 
                { 
                    Write-Host OKAY: Cert for site $url expires in $certExpiresIn days [on $expiration] -f Green 
                }
                if ($ReportType -eq "PSObject") 
                { 
                    $returnData += new-object psobject -property  @{Url = $url; CheckResult = "OKAY"; CertExpiresInDays = [int]$certExpiresIn; ExpirationOn = [datetime]$expiration; Details = [string]$null}
                }
            }
            else
            {
                $details = ""
                $details += "Cert for site $url expires in $certExpiresIn days [on $expiration]`n"
                $details += "Threshold is $minimumCertAgeDays days. Check details:`n"
                $details += "Cert name: $certName`n"
                $details += "Cert public key: $certPublicKeyString`n"
                $details += "Cert serial number: $certSerialNumber`n"
                $details += "Cert thumbprint: $certThumbprint`n"
                $details += "Cert effective date: $certEffectiveDate`n"
                $details += "Cert issuer: $certIssuer"
                if ($ReportType -eq "Html") 
                { 
                    Write-Host "<td>WARNING</td><td>$certExpiresIn</td><td>$expiration</td>"
                    $stringHtmlEncoded = [System.Web.HttpUtility]::HtmlEncode($details) -replace "`n", "<br />"
                    Write-Host "<tr><td>$stringHtmlEncoded</td></tr>" 
                }
                if ($ReportType -eq "Text") 
                { 
                    Write-Host WARNING: $details -f Red
                }
                if ($ReportType -eq "PSObject") 
                { 
                    $returnData += new-object psobject -property  @{Url = $url; CheckResult = "WARNING"; CertExpiresInDays = [int]$certExpiresIn; ExpirationOn = [datetime]$expiration; Details = $details}
                }
            rv expiration
            rv certExpiresIn
            }
        }
        else
        {
            if ($ReportType -eq "Html") 
            { 
                Write-Host "<td>ERROR</td><td>N/A</td><td>N/A</td>"
                $stringHtmlEncoded = [System.Web.HttpUtility]::HtmlEncode($details) -replace "`n", "<br />"
                Write-Host "<tr><td>$stringHtmlEncoded</td></tr>" 
            }
            if ($ReportType -eq "Text") 
            { 
                Write-Host ERROR: $details -f Red
            }
            if ($ReportType -eq "PSObject") 
            { 
                $returnData += new-object psobject -property  @{Url = $url; CheckResult = "ERROR"; CertExpiresInDays = $null; ExpirationOn = $null; Details = $details}
            }
        }
        if ($ReportType -eq "Text") { Write-Host }
        rv req
        return $returnData
    }

    #disabling the cert validation check. This is what makes this whole thing work with invalid certs...
    [Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

    if ($ReportType -eq "Html") 
    { 
        Write-Host "<table><tr><th>URL</th><th>Check result</th><th>Expires in days</th><th>Expires on</th><th>Details</th></tr>" 
        Add-Type -AssemblyName System.Web 
    }
}
Process
{
    if ($_ -ne $null)
    {
        CheckUrl $_ $returnData
        $ProcessedInputPipeLineByArrayItem = $true
    }
}
End
{
    if ($ProcessedInputPipeLineByArrayItem -eq $false)
    {
        if ($Urls -eq $null)
        {
            $allUrls = get-content $UrlsFile
        }
        else
        {
            $allUrls = $Urls
        }
        foreach ($url in $allUrls)
        {
            $returnData = CheckUrl $url $returnData
        }
    }
    if ($ReportType -eq "Html") { Write-Host "</table>" }
    if ($ReportType -eq "PSObject") { return $returnData }
}