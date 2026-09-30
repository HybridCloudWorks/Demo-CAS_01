// Generic private endpoint + private DNS zone group. One instance per (target resource, groupId).

@description('Azure region for all resources.')
param location string

@description('Private endpoint name.')
param name string

@description('Tags applied to every resource.')
param tags object

@description('Subnet ID for the private endpoint NIC (snet-pe).')
param subnetId string

@description('Resource ID of the target service (Key Vault, Storage account, ...).')
param targetResourceId string

@description('Sub-resource group ID, e.g. vault, blob, file, sqlServer.')
param groupId string

@description('Private DNS zone ID matching the group ID (privatelink.vaultcore.azure.net, privatelink.blob.*, ...).')
param privateDnsZoneId string

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${name}-conn'
        properties: {
          privateLinkServiceId: targetResourceId
          groupIds: [groupId]
        }
      }
    ]
  }
}

resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: groupId
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

@description('Private endpoint resource ID.')
output id string = privateEndpoint.id

@description('Private endpoint name.')
output name string = privateEndpoint.name
