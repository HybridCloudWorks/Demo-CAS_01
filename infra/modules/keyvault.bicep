// Secrets management: Key Vault with RBAC, soft delete, purge protection, public access off (R3).
// Network path is a private endpoint created by private-endpoint.bicep.

@description('Azure region for all resources.')
param location string

@description('Key Vault name (3-24 chars, globally unique).')
@minLength(3)
@maxLength(24)
param name string

@description('Tags applied to every resource.')
param tags object

@description('Log Analytics workspace ID for diagnostic logs.')
param workspaceId string

@description('Soft-delete retention in days (7-90). Architect decision — see docs/requirements.md open decision 2.')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 7

resource vault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: tenant().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}

// 2021-05-01-preview is the current API for diagnosticSettings; no stable version exists yet.
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'to-log-analytics'
  scope: vault
  properties: {
    workspaceId: workspaceId
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

@description('Key Vault resource ID.')
output id string = vault.id

@description('Key Vault name.')
output name string = vault.name

@description('Key Vault URI for the application (identity-based access, no secret).')
output uri string = vault.properties.vaultUri
