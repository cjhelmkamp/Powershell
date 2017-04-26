<# 
.SYNOPSIS 
	Bulk create Users in AD

.DESCRIPTION 
    This script is designed to read a CSV file and create OU, Group, and genearic user accounts for Lab environment.

.NOTES 
    File Name  : createLabUsers.ps1
    Author     : Chris Helmkamp 
    Licenced under GPLv3

.LINK 
	https://github.com
    License: http://www.gnu.org/copyleft/gpl.html

.PARAMETER CSVPath
    Mandatory. Filepath to CSV file of accounts to create.

.EXAMPLE 
	./createLabUsers.ps1 -CSVPath "C:\Temp\createLabUsers.csv"

.EXAMPLE
    Example of the CSV file layout that the script is expecting

    SchoolName,AbbrName,MaxUsers,Password
    American Career College,ACC,2,Welcome@2017!
    American College for Medical Careers,ACMC,2,Welcome@2017!
#> 

[CmdletBinding(DefaultParametersetName="Set1")]
Param (

    [parameter(Mandatory=$True,ParameterSetName = "Set1")]
    [ValidateNotNullOrEmpty()]
	[alias("csv")]
	[string]$CSVPath

)

try{
    Import-Module ActiveDirectory -ErrorAction Stop
}
catch
{
    throw "Module ActiveDirectory not Installed"
    exit 1
}

################################################################################################################################
# 											OU Creation	  																       #
################################################################################################################################

# Verify CSV Path
$testCSVPath = Test-Path $CSVPath -ErrorAction stop
if ($testCSVPath -eq $False) 
{
    Write-Host "CSV File Not Found. Please verify the path and retry" -ForegroundColor Red
	Exit 1
}
else
{
    # Continue if CSV is found						
    Write-host "Creating Required OU's" -ForegroundColor Cyan

    # Import CSV and only read lines that have an entry in createOUName column
    $csv = @()
    $csv = Import-Csv -Path $CSVPath |
    Where-Object {$_.SchoolName}

    # Loop through all items in the CSV
	ForEach ($item in $csv) 
    {
        # Check if the OU exists
        $Name = $item.SchoolName
		$ouName = "OU=" + $item.SchoolName
		$ouExists = [ADSI]::Exists("LDAP://$($ouName),$($createOUPath)")
  		If ($ouExists -eq $true)
		{
            Write-Host "OU $ouName,$createOUPath already exists! OU creation skipped!" -ForegroundColor Yellow
	    }
        Else
        {	  
            # Create The OU
            $createOU = New-ADOrganizationalUnit -Name $Name -Path $createOUPath
            Write-Host "OU $ouName,$createOUPath created!" -ForegroundColor Green
        }
	}
}
Write-Host "OU Creation Complete" -ForegroundColor Green 

################################################################################################################################
# 											Group Creation	  																   #
################################################################################################################################	
Write-host "Creating Required Groups" -ForegroundColor Cyan

# Get Domain Base Path
$searchbase = Get-ADDomainController | ForEach {  $_.DefaultPartition }
  
# Import CSV and only read lines that have an entry in createGroup column
$csv = @()
$csv = Import-Csv -Path $CSVPath |
Where-Object {$_.AbbrName}

ForEach ($item In $csv)
{
    # Check if the Group already exists
    $gName = "EM_" + $item.AbbrName
    $ouName = "OU=" + $item.SchoolName
	$gPath = "$ouName,$createOUPath"
    $groupName = "CN=" + $gName + "," + $gPath
    $groupExists = [ADSI]::Exists("LDAP://$($groupName)")

    if ($groupExists -eq $true)
	{
		Write-Host "Group $groupName already exists! Group creation skipped!" -ForegroundColor Yellow
	}
    else
    {
        # Create the group if it doesn't exist
        $createGroup = New-ADGroup -Name $gName -GroupScope Global -Path $gPath
        Write-Host "Group $gName,$gPath created!" -ForegroundColor Green
    }
}
Write-Host "Group Creation Complete" -ForegroundColor Green 

################################################################################################################################
# 											User Creation	  																   #
################################################################################################################################
# Creating Users from csv
Write-Host "Creating EHC Users and Adding to Security Groups" -ForegroundColor Cyan

# Import CSV
$csv = @()
$csv = Import-Csv -Path $CSVPath 

# Loop through all items in the CSV
ForEach ($item In $csv)
{
    $i = 1
    While ($i -le $item.MaxUsers)
    {
        #Check if the User exists
        $uNum = $i.ToString("0000")
        $samAccountName = $item.AbbrName + "_" + $uNum
        $gName = "EM_" + $item.AbbrName
        $ouName = "OU=" + $item.SchoolName
	    $uPath = "$ouName,$createOUPath"
        $userName = "CN=" + $samAccountName + "," + $uPath
        
	    $userExists = [ADSI]::Exists("LDAP://$userName")
        
	    If ($userExists -eq $true)
	    {
	        Write-Host "User $samAccountName Already Exists. User creation skipped!" -ForegroundColor Yellow
	    }
	    else
	    {
            # Create The User  
            $uDomain = $searchbase = Get-ADDomainController | ForEach {  $_.Domain }
	        $userPrincinpal = $samAccountName + "@" + $uDomain
	        New-ADUser -Name $samAccountName `
	        -Path  $uPath `
	        -SamAccountName  $samAccountName `
	        -UserPrincipalName  $userPrincinpal `
	        -AccountPassword (ConvertTo-SecureString $item.Password -AsPlainText -Force) `
	        -ChangePasswordAtLogon $false `
	        -PasswordNeverExpires $True `
	        -Enabled $true
		
            Write-Host "User $samAccountName created!" -ForegroundColor Green
	    }

        # Check if the User is already a member of the group
	    $userIsMember = (Get-ADGroupMember -Identity $gName).name -contains "$samAccountName"
		If ($userIsMember -eq $true)
		{
            Write-Host "User $samAccountName is already a member of $gName. Add to Group skipped!" -ForegroundColor Yellow
		}
	    else
		{
	        Add-ADGroupMember -Identity $gName -Member $samAccountName
	        Write-Host "User $samAccountName added to group $gName!" -ForegroundColor Green
		}
        $i = $i+1
    }
}
Write-host "Creating Users and Adding to Security Groups Complete" -ForegroundColor Green
