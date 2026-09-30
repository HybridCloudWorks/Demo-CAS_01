// Application data: StorageV2, HTTPS only, TLS 1.2, no public blob or shared-key access, public network off (R4).
// Network path is a private endpoint (blob) created by private-endpoint.bicep.

@description('Azure region for all resources.')
param location string

@description('Storage account name (3-24 lowercase alphanumeric, globally unique).')
@minLength(3)
@maxLength(24)
param name string

@description('Tags applied to every resource.')
param tags object

@description('Replication SKU. LRS for dev; architect decides for prod.')
@allowed(['Standard_LRS', 'Standard_ZRS', 'Standard_GRS'])
param skuName string = 'Standard_LRS'

@description('Blob soft-delete retention in days. Architect decision — see docs/requirements.md open decision 3.')
@minValue(1)
@maxValue(365)
param blobSoftDeleteDays int = 7

resource storage 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: name
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: skuName
  }
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' = {
  parent: storage
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: blobSoftDeleteDays
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: blobSoftDeleteDays
    }
  }
}

@description('Storage account resource ID.')
output id string = storage.id

@description('Storage account name.')
output name string = storage.name

@description('Primary blob endpoint (identity-based access, no key).')
output blobEndpoint string = storage.properties.primaryEndpoints.blob
