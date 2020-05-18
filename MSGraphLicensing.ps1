# add manifest and require Microsoft.Graph module(s) to be installed
#Get all Subscribed SKUs
#Import-Module Microsoft.Graph
#user must connect to Microsoft Graph using Connect-Graph and have sufficient access rights

#get the Skus and the ServicePlans
$Skus = Get-MgSubscribedSku
$ServicePlans = $Skus.ServicePlans | Select-Object -Unique ServicePlanID, ServicePlanName, ProvisioningStatus, AppliesTo

#get the Skus to ServicePlans Hash
$SkuToServicePlanHash = @{ }
$Skus.foreach( {
    $SkuToServicePlanHash.$($_.skuID) = @($_.ServicePlans.ServicePlanID)
  })

#create and populate a hashtable with the skus by key skuID
$SkuHash = @{ }
$Skus.foreach( { $SkuHash.$($_.SkuID) = $_ })

#create and populate a hashtable with the servicePlans by key ServicePlanID
$ServicePlanHash = @{ }
$ServicePlans.foreach( { $ServicePlanHash.$($_.ServicePlanID) = $_ })

#Get the groups that are assigned licenses
$Groups = Get-MgGroup -Select DisplayName, AssignedLicenses, ID, Description | Where-Object -FilterScript { $_.AssignedLicenses.Count -gt 0 } | Select-Object ID, DisplayName, Description, AssignedLicenses

#Get a 'Friendly' view of enabled skus and serviceplans for each group

foreach ($g in $Groups)
{
  [PSCustomObject]@{
    ID                       = $g.ID
    DisplayName              = $g.DisplayName
    Description              = $g.Description
    AssignedSkuIDs           = @($g.AssignedLicenses.skuid)
    AssignedSkuNames         = @($g.AssignedLicenses.skuid.foreach( { $SkuHash.$_.SkuPartNumber }))
    EnabledServicePlanNames  = @(
      foreach ($l in $g.AssignedLicenses)
      {
        $AvailableServicePlans = $SkuToServicePlanHash.$($l.SkuID)
        $EnabledServicePlans = $AvailableServicePlans |
          Where-Object { $l.DisabledPlans -notcontains $_ }
        $EnabledServicePlans.foreach( { $ServicePlanHash.$_.ServicePlanName })
      }
    )
    DisabledServicePlanNames = @(
      foreach ($l in $g.AssignedLicenses)
      {
        $l.DisabledPlans.foreach( { $ServicePlanHash.$_.ServicePlanName })
      }
    )
  }
}