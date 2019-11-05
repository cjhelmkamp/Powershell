#######################
###
### Creates a Security & Compliance object based on the timestamp of running this script
### Prompts for the subject line of the email and the senders email address
### Searches through all mailboxes for emails matching these criteria and purges them from the mailboxes
### Must be run by a global administrator!
### Assumes you have already got the Security and Compliance module in Powershell running.
### Sleep-Start times may need increasing for larger organisations
###
#######################
# Find email address of currently logged on user

$userName = $env:UserName

$domain = "@domain.com" #Edit this to your email domain!

$emailAddress = -join("$userName","$domain")

# Connect to the Security and Compliance module with those details
Connect-IPPSSession -userprincipalname $emailAddress

# Get basic info for report - Report Name (based on timestamp) Subject Line and Sender
$compSearchName = Get-Date -format "yyyyMMdd-HHmmss"

#$sentAfterDate = Read-Host "Enter the date to search from in format dd/mm/yy"
$emailSubjectLine = Read-Host "Enter the subject line of the offending email"

$emailSender = Read-Host "Enter the email address of the sender"

# Create new search with above criteria
New-ComplianceSearch -Name $compSearchName -ExchangeLocation all -ContentMatchQuery From:"$emailSender",Subject:"$emailSubjectLine"

# Run the search
Start-ComplianceSearch -Identity $compSearchName

# Add in a delay to allow the search to complete
Start-Sleep -Seconds 120

# Get the results
Get-ComplianceSearch -Identity $compSearchName #Show count
Get-ComplianceSearch -Identity $compSearchName | fl #Show mailboxes

# Show the results
Get-ComplianceSearch -Identity $compSearchName | Select Items

# Purge emails from all mailboxes
New-ComplianceSearchAction -SearchName $compSearchName -Purge -PurgeType SoftDelete -Confirm:$False

# Wait for the process to complete
Start-Sleep -Seconds 120

#Confirm it's completed
Get-ComplianceSearchAction -Identity "$($compSearchName)_Purge"