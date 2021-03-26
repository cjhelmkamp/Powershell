<# 
.SYNOPSIS 
	Grab a webpage and put it in a directory
.DESCRIPTION 
    This script is designed to download an html file from a site and place it in a directory.
.NOTES 
    File Name  : getFile.ps1
    Author     : Chris Helmkamp 
    Licenced under GPLv3  
.LINK 
	https://github.com/cjhelmkamp/Powershell/blob/master/getFile.ps1
    License: http://www.gnu.org/copyleft/gpl.html
#> 


$webAddress = "http://p.i.wkregs.com/external_wir/ahima.html"
$outFile = "C:\inetpub\wwwroot\my.ahima.org\library\documents\mediregs.html"

#
Try
{
    wget $webAddress -OutFile $outFile
}
catch
{
    Throw "Unable to retrive $webAddress"
}
