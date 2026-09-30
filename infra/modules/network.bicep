// Shared platform piece: VNet, two subnets, and the private DNS zones the data services need.
// INTERFACE IS FIXED — other modules consume the outputs below. Do not change parameter or output names.

@description('Azure region for all resources.')
param location string

@description('Virtual network name.')
param vnetName string

@description('Tags applied to every resource.')
param tags object

@description('VNet address space.')
param addressPrefix string = '10.20.0.0/16'

@description('Subnet for App Service regional VNet integration (delegated to Microsoft.Web/serverFarms).')
param appSubnetPrefix string = '10.20.1.0/24'

@description('Subnet for private endpoints.')
param peSubnetPrefix string = '10.20.2.0/24'

var appSubnetName = 'snet-app'
var peSubnetName = 'snet-pe'

var privateDnsZones = [
  'privatelink.vaultcore.azure.net'
  'privatelink.blob.${environment().suffixes.storage}'
]

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [addressPrefix]
    }
    subnets: [
      {
        name: appSubnetName
        properties: {
          addressPrefix: appSubnetPrefix
          delegations: [
            {
              name: 'appservice'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      {
        name: peSubnetName
        properties: {
          addressPrefix: peSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource zones 'Microsoft.Network/privateDnsZones@2024-06-01' = [
  for zone in privateDnsZones: {
    name: zone
    location: 'global'
    tags: tags
  }
]

resource zoneLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [
  for (zone, i) in privateDnsZones: {
    parent: zones[i]
    name: '${vnetName}-link'
    location: 'global'
    tags: tags
    properties: {
      virtualNetwork: {
        id: vnet.id
      }
      registrationEnabled: false
    }
  }
]

@description('Resource ID of the virtual network.')
output vnetId string = vnet.id

@description('Subnet ID for App Service VNet integration.')
output appSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, appSubnetName)

@description('Subnet ID for private endpoints.')
output peSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, peSubnetName)

@description('Private DNS zone ID for Key Vault (privatelink.vaultcore.azure.net).')
output keyVaultDnsZoneId string = zones[0].id

@description('Private DNS zone ID for Blob storage (privatelink.blob.*).')
output blobDnsZoneId string = zones[1].id
