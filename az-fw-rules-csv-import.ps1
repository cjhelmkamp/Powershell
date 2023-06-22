##########################################################################################################
<#
.SYNOPSIS
    Imports rules from CSV to Azure Firewall Policy

.DESCRIPTION

    Import Network rules from a CSV to build Rule collecetion, add rule collection to Rule collection Group
    and deploy RCG to Firewall Polciy

    The rule sets are setup for Filter rules but could be modified to nat, dnat, app.

.EXAMPLE
    Example CSV layout

    "RuleCollectionName","RulePriority","ActionType","RUleConnectionType","Name","protocols","SourceAddresses","DestinationAddresses","SourceIPGroups","DestinationIPGroups","DestinationPorts","DestinationFQDNs"
    "P-APP-OUT-01","700","Allow","FirewallPolicyFilterRuleCollection","RS-CERT-TCP","TCP","10.0.0.0/24","172.16.0.10/32","","","135",""
    "P-APP-OUT-01","700","Allow","FirewallPolicyFilterRuleCollection","RS-FANO-NTP-UDP","UDP","10.0.0.0/24","","","/subscriptions/UUID/resourceGroups/prod-ncus-rg/providers/Microsoft.Network/ipGroups/IPG-ADDS","123",""
    "P-APP-OUT-DENY-01","710","Deny","FirewallPolicyFilterRuleCollection","Deny-All-Private","Any","10.5.4.0/24","10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16","","","*",""
    "P-APP-OUT-02","720","Allow","FirewallPolicyFilterRuleCollection","iNET-DNS","UDP","10.0.0.0/24","*","","","53",""
    "P-APP-OUT-02","720","Allow","FirewallPolicyFilterRuleCollection","iNET-WEB","TCP","10.0.0.0/24","*","","","80, 443",""
    "P-APP-IN-01","800","Allow","FirewallPolicyFilterRuleCollection","APP-WEB-TCP","TCP","*","10.0.0.0/24","","","80, 443",""

.NOTES
    THIS CODE-SAMPLE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED 
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR 
    FITNESS FOR A PARTICULAR PURPOSE.

    This sample is not supported under any Microsoft standard support program or service. 
    The script is provided AS IS without warranty of any kind. Microsoft further disclaims all
    implied warranties including, without limitation, any implied warranties of merchantability
    or of fitness for a particular purpose. The entire risk arising out of the use or performance
    of the sample and documentation remains with you. In no event shall Microsoft, its authors,
    or anyone else involved in the creation, production, or delivery of the script be liable for 
    any damages whatsoever (including, without limitation, damages for loss of business profits, 
    business interruption, loss of business information, or other pecuniary loss) arising out of 
    the use of or inability to use the sample or documentation, even if Microsoft has been advised 
    of the possibility of such damages, rising out of the use of or inability to use the sample script, 
    even if Microsoft has been advised of the possibility of such damages. 

#>
##########################################################################################################


#Provide Input. Firewall Policy Name, Firewall Policy Resource Group & Firewall Policy Rule Collection Group Name
$fpname = "FW-POL-01"
$fprg = "prod-ncus-rg"
$fprcgname = "P-APP-RCG-01"
$fprcgpriority = "700"
$fSubName = "ORG Infrastructure"
$overwrite = "Yes"

Set-Item -Path Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true
Set-Item -Path Env:\SuppressAzureRmModulesRetiringWarning -Value $true

Select-AzSubscription -Subscription $fSubName

if($overwrite -match "Yes"){
    Remove-AzFirewallPolicyRuleCollectionGroup -Name $fprcgname -ResourceGroupName $fprg -AzureFirewallPolicyName $fpname
    New-AzFirewallPolicyRuleCollectionGroup  -Name $fprcgname -Priority $fprcgpriority -ResourceGroupName $fprg -FirewallPolicyName $fpname
}

# $targetfp = Get-AzFirewallPolicy -Name $fpname -ResourceGroupName $fprg
# $targetrcg = Get-AzFirewallPolicyRuleCollectionGroup -Name $fprcgname -AzureFirewallPolicy $targetfp
# $targetrcg = New-AzFirewallPolicyRuleCollectionGroup -Name $fprcgname -Priority 200 -FirewallPolicyObject $targetfp
$natrulecollectiongroup = Get-AzFirewallPolicyRuleCollectionGroup -Name $fprcgname -ResourceGroupName $fprg -AzureFirewallPolicyName $fpname
$existingrulecollection = $natrulecollectiongroup.Properties.RuleCollection
$rcNameList = $existingrulecollection.Name

$RulesfromCSV = @()
# Change the folder where the CSV is located
$readObj = import-csv ./rules.csv
foreach ($entry in $readObj)
{
    $properties = [ordered]@{
        RuleCollectionName = $entry.RuleCollectionName;
        RulePriority = $entry.RulePriority;
        ActionType = $entry.ActionType;
        Name = $entry.Name;
        protocols = $entry.protocols -split ", ";
        SourceAddresses = $entry.SourceAddresses -split ", ";
        DestinationAddresses = $entry.DestinationAddresses -split ", ";
        SourceIPGroups = $entry.SourceIPGroups -split ", ";
        DestinationIPGroups = $entry.DestinationIPGroups -split ", ";
        DestinationPorts = $entry.DestinationPorts -split ", ";
        DestinationFQDNs = $entry.DestinationFQDNs -split ", ";
    }
    $obj = New-Object psobject -Property $properties
    $RulesfromCSV += $obj
}
#$RulesfromCSV
$groupRCN = $RulesfromCSV | Group-Object RuleCollectionName
#$groupRCN
foreach ($rcentry in $groupRCN)
{
$rcentry.name
Clear-Variable rules
Clear-Variable NetworkRuleCategoryCollections
$rules = @()
foreach ($entry in $rcentry.Group)
{
    $entry.Name;
    if ([string]::IsNullOrEmpty($entry.SourceAddresses))
    {
        if ([string]::IsNullOrEmpty($entry.DestinationAddresses))
        {
            $RuleParameter = @{
                Name = $entry.Name;
                Protocol = $entry.protocols;
                DestinationPort = $entry.DestinationPorts;
                SourceIPGroup = $entry.SourceIPGroups;
                DestinationIPGroup = $entry.DestinationIPGroups;
            }
        }else{
            $RuleParameter = @{
                Name = $entry.Name;
                Protocol = $entry.protocols;
                DestinationAddress = $entry.DestinationAddresses;
                DestinationPort = $entry.DestinationPorts;
                SourceIPGroup = $entry.SourceIPGroups;
            }
        }
    }else{
        if ([string]::IsNullOrEmpty($entry.DestinationAddresses))
        {
            $RuleParameter = @{
                Name = $entry.Name;
                Protocol = $entry.protocols;
                sourceAddress = $entry.SourceAddresses;
                DestinationPort = $entry.DestinationPorts;
                DestinationIPGroup = $entry.DestinationIPGroups;
            }
        }else{
            $RuleParameter = @{
                Name = $entry.Name;
                Protocol = $entry.protocols;
                sourceAddress = $entry.SourceAddresses;
                DestinationAddress = $entry.DestinationAddresses;
                DestinationPort = $entry.DestinationPorts;
            }
        }
    }
    $rule = New-AzFirewallPolicyNetworkRule @RuleParameter
    $NetworkRuleCollection = @{
        Name = $entry.RuleCollectionName
        Priority = $entry.RulePriority
        ActionType = $entry.ActionType
        Rule       = $rules += $rule
    }
}
$NetworkRuleCategoryCollection = New-AzFirewallPolicyFilterRuleCollection @NetworkRuleCollection

Write-Host "`n"

    if($rcNameList -contains $NetworkRuleCollection.Name){
        Write-Host "Rule Collection Group: "$fpRCGname" containes Rule Collection: " $NetworkRuleCollection.Name"`n"
        $updateRC= $existingrulecollection | Where-Object {$_.Name -match $NetworkRuleCollection.Name}
        Write-Host "Adding new rules to Rule Collection: " $NetworkRuleCollection.Name"`n"
        foreach($rcRule in $NetworkRuleCollection.Rule){
            $rcRule.Name
            $updateRC.Rules.Add($rcRule)
        }
    }else{
        Write-Host "Adding Rule Collection "$NetworkRuleCollection.Name" to Rule Collection Group: "$fpRCGname"`n"
        $existingrulecollection.Add($NetworkRuleCategoryCollection) 
    }
}
Write-Host "`n"
$existingrulecollection.Name

$NetworkCollections = @{
    Name = $natrulecollectiongroup.Name
    Priority = "800"
    FirewallPolicyName = $fpname
    ResourceGroupName = $fprg
    RuleCollection = $natrulecollectiongroup.Properties.RuleCollection
    } 

# Deploy to created rule collection group
Set-AzFirewallPolicyRuleCollectionGroup @NetworkCollections
#Set-AzFirewallPolicyRuleCollectionGroup -Name $natrulecollectiongroup.Name -Priority 800 -FirewallPolicyObject $targetfp -RuleCollection $natrulecollectiongroup.Properties.RuleCollection #-Debug