// Compute: Linux App Service plan + web app with system-assigned identity and VNet integration (R1, R2).
// No secrets in app settings: Key Vault URI and storage account name only; access is identity-based.

@description('Azure region for all resources.')
param location string

@description('App Service plan name.')
param planName string

@description('Web app name (globally unique).')
param appName string

@description('Tags applied to every resource.')
param tags object

@description('Subnet ID for regional VNet integration (delegated to Microsoft.Web/serverFarms).')
param appSubnetId string

@description('Application Insights connection string.')
param appInsightsConnection string

@description('Key Vault URI the app reads secrets from with its identity.')
param keyVaultUri string

@description('Storage account name the app accesses with its identity.')
param storageAccountName string

@description('Plan SKU. B1 is acceptable for dev.')
@allowed(['B1', 'B2', 'P0v3', 'P1v3'])
param skuName string = 'B1'

@description('Runtime stack for the Linux app.')
param linuxFxVersion string = 'DOTNETCORE|8.0'

@description('Public reachability of the app itself. Architect decision — see docs/requirements.md open decision 1.')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Enabled'

resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: planName
  location: location
  tags: tags
  kind: 'linux'
  sku: {
    name: skuName
  }
  properties: {
    reserved: true
  }
}

resource site 'Microsoft.Web/sites@2024-04-01' = {
  name: appName
  location: location
  tags: tags
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    publicNetworkAccess: publicNetworkAccess
    virtualNetworkSubnetId: appSubnetId
    vnetRouteAllEnabled: true
    clientAffinityEnabled: false
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      alwaysOn: false // B1 supports it, but keep dev cheap; prod should set true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      http20Enabled: true
      vnetRouteAllEnabled: true
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnection
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'KEY_VAULT_URI'
          value: keyVaultUri
        }
        {
          name: 'STORAGE_ACCOUNT_NAME'
          value: storageAccountName
        }
      ]
    }
  }
}

@description('Web app resource ID.')
output id string = site.id

@description('Web app name.')
output name string = site.name

@description('System-assigned identity principal ID, used for resource-scoped role assignments.')
output principalId string = site.identity.principalId

@description('Default hostname.')
output defaultHostName string = site.properties.defaultHostName
