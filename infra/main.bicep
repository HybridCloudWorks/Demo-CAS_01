// agentic-azure-api — small secure Azure API baseline
// Composition root. Resources live in infra/modules/*; this file only wires them together.
//
// REFERENCE SOLUTION — the expected end state of all three live demos (see README). Requirements: docs/requirements.md.

targetScope = 'resourceGroup'

// ---------------------------------------------------------------- parameters

@description('Azure region. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Deployment environment.')
@allowed(['dev', 'test', 'prod'])
param environment string

@description('Short workload name used in resource names (lowercase letters and digits).')
@minLength(3)
@maxLength(10)
param workload string = 'casapi'

@description('Owning team or person, for the owner tag.')
param owner string

@description('Cost center code, for the costCenter tag.')
param costCenter string

@description('Public reachability of the App Service itself (data services are always private). Open decision 1.')
@allowed(['Enabled', 'Disabled'])
param appPublicNetworkAccess string = 'Enabled'

@description('Key Vault soft-delete retention in days. Open decision 2.')
@minValue(7)
@maxValue(90)
param keyVaultSoftDeleteDays int = 7

// ---------------------------------------------------------------- naming + tags

var suffix = take(uniqueString(resourceGroup().id), 6)

// Every module receives these tags and applies them to every taggable resource.
var tags = {
  workload: workload
  environment: environment
  owner: owner
  costCenter: costCenter
  managedBy: 'bicep'
}

// Single source of truth for names. Documentation and diagrams use these labels.
var names = {
  vnet: 'vnet-${workload}-${environment}'
  plan: 'asp-${workload}-${environment}'
  app: 'app-${workload}-${environment}-${suffix}'
  keyVault: 'kv-${workload}-${environment}-${suffix}' // <= 24 chars
  storage: toLower('st${workload}${environment}${suffix}') // <= 24 chars, alphanumeric
  logAnalytics: 'log-${workload}-${environment}'
  appInsights: 'appi-${workload}-${environment}'
  keyVaultPe: 'pe-kv-${workload}-${environment}'
  storagePe: 'pe-st-${workload}-${environment}'
}

// ---------------------------------------------------------------- platform

module network 'modules/network.bicep' = {
  name: 'network'
  params: {
    location: location
    vnetName: names.vnet
    tags: tags
  }
}

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    location: location
    workspaceName: names.logAnalytics
    appInsightsName: names.appInsights
    tags: tags
  }
}

// ---------------------------------------------------------------- data services (private by default)

module keyVault 'modules/keyvault.bicep' = {
  name: 'keyvault'
  params: {
    location: location
    name: names.keyVault
    tags: tags
    workspaceId: monitoring.outputs.workspaceId
    softDeleteRetentionInDays: keyVaultSoftDeleteDays
  }
}

module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    location: location
    name: names.storage
    tags: tags
  }
}

module keyVaultPrivateEndpoint 'modules/private-endpoint.bicep' = {
  name: 'pe-keyvault'
  params: {
    location: location
    name: names.keyVaultPe
    tags: tags
    subnetId: network.outputs.peSubnetId
    targetResourceId: keyVault.outputs.id
    groupId: 'vault'
    privateDnsZoneId: network.outputs.keyVaultDnsZoneId
  }
}

module storagePrivateEndpoint 'modules/private-endpoint.bicep' = {
  name: 'pe-storage-blob'
  params: {
    location: location
    name: names.storagePe
    tags: tags
    subnetId: network.outputs.peSubnetId
    targetResourceId: storage.outputs.id
    groupId: 'blob'
    privateDnsZoneId: network.outputs.blobDnsZoneId
  }
}

// ---------------------------------------------------------------- compute

module app 'modules/app.bicep' = {
  name: 'app'
  params: {
    location: location
    planName: names.plan
    appName: names.app
    tags: tags
    appSubnetId: network.outputs.appSubnetId
    appInsightsConnection: monitoring.outputs.appInsightsConnection
    keyVaultUri: keyVault.outputs.uri
    storageAccountName: storage.outputs.name
    publicNetworkAccess: appPublicNetworkAccess
  }
}

// ---------------------------------------------------------------- least-privilege access (resource-scoped)

module appToKeyVault 'modules/rbac-keyvault.bicep' = {
  name: 'rbac-app-keyvault'
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: app.outputs.principalId
  }
}

module appToStorage 'modules/rbac-storage.bicep' = {
  name: 'rbac-app-storage'
  params: {
    storageAccountName: storage.outputs.name
    principalId: app.outputs.principalId
  }
}

// ---------------------------------------------------------------- outputs

@description('Virtual network resource ID.')
output vnetId string = network.outputs.vnetId

@description('Web app default hostname.')
output appHostName string = app.outputs.defaultHostName

@description('Web app system-assigned identity principal ID.')
output appPrincipalId string = app.outputs.principalId

@description('Key Vault URI.')
output keyVaultUri string = keyVault.outputs.uri

@description('Primary blob endpoint.')
output blobEndpoint string = storage.outputs.blobEndpoint

@description('Resource names used by this deployment (for docs and diagrams).')
output resourceNames object = names
