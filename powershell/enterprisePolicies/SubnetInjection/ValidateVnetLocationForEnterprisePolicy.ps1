﻿$supportedVnetLocations = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$supportedVnetLocations.Add("centraluseuap", "eastus|westus")
$supportedVnetLocations.Add("eastus2euap", "eastus|westus")
$supportedVnetLocations.Add("unitedstateseuap", "eastus|westus")
$supportedVnetLocations.Add("unitedstates", "eastus|westus")
$supportedVnetLocations.Add("southafrica", "southafricanorth|southafricawest")
$supportedVnetLocations.Add("uk", "uksouth|ukwest")
$supportedVnetLocations.Add("japan", "japaneast|japanwest")
$supportedVnetLocations.Add("india", "centralindia|southindia")
$supportedVnetLocations.Add("france", "francecentral|francesouth")
$supportedVnetLocations.Add("europe", "westeurope|northeurope")
$supportedVnetLocations.Add("germany", "germanynorth|germanywestcentral")
$supportedVnetLocations.Add("switzerland", "switzerlandnorth|switzerlandwest")
$supportedVnetLocations.Add("canada", "canadacentral|canadaeast")
$supportedVnetLocations.Add("brazil", "brazilsouth|southcentralus")
$supportedVnetLocations.Add("australia", "australiasoutheast|australiaeast")
$supportedVnetLocations.Add("asia", "eastasia|southeastasia")
$supportedVnetLocations.Add("uae", "uaecentral|uaenorth")
$supportedVnetLocations.Add("korea", "koreasouth|koreacentral")
$supportedVnetLocations.Add("norway", "norwaywest|norwayeast")
$supportedVnetLocations.Add("singapore", "southeastasia")
$supportedVnetLocations.Add("sweden", "swedencentral")

function ValidateAndGetVnet($vnetId, $enterprisePolicylocation) {

    $vnetResource = Get-AzResource -ResourceId $vnetId
    if ($vnetResource.ResourceId -eq $null)
    {
        Write-Host "Error getting virtual network for $vnetId `n" -ForegroundColor Red
        return $null
    }

    $vnetLocation = $vnetResource.Location
    if ($supportedVnetLocations.ContainsKey($enterprisePolicylocation) -eq $false)
    {
        Write-Host "The location $enterprisePolicylocation of enterprise policy is not supported`n" -ForegroundColor Red
        $supportedEnterprisePolicyLocationsString = $supportedVnetLocations.Keys -join ","
        Write-Host "The supported enterprise policy locations are $supportedEnterprisePolicyLocationsString`n" -ForegroundColor Red
        return $null

    }
    $vnetLocationsAllowed = $supportedVnetLocations[$enterprisePolicylocation].Split("|")
    if ($vnetLocationsAllowed.Contains($vnetLocation))
    {
        return $vnetResource
    }

    Write-Host "The location of vnet $vnetLocation is not a supported for enterprise policy location $enterprisePolicylocation`n" -ForegroundColor Red
    $vnetLocationsAllowedString = $vnetLocationsAllowed -join ","
    Write-Host "The supported vnet location for enterprise policy location $enterprisePolicylocation are $vnetLocationsAllowedString`n" -ForegroundColor Red
    return $null
}