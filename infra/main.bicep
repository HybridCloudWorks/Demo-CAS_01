// agentic-azure-api — small secure Azure API baseline
// Composition root. Resources live in infra/modules/*; this file only wires them together.
//
// STARTING STATE for the session: the shared network module is in place.
// Demo 01 adds the remaining modules (monitoring, keyvault, storage, app, private endpoints, RBAC).
// See docs/requirements.md for the acceptance criteria and .github/copilot-instructions.md for the rules.

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

// ---------------------------------------------------------------- modules

module network 'modules/network.bicep' = {
  name: 'network'
  params: {
    location: location
    vnetName: names.vnet
    tags: tags
  }
}

// TODO (Demo 01): compose the remaining modules here.
//   monitoring  → Log Analytics + Application Insights          (R5)
//   keyVault    → RBAC, soft delete, purge protection, private  (R3)
//   storage     → HTTPS/TLS1.2, no public/shared-key access     (R4)
//   app         → Linux plan + site, system identity, VNet int. (R1, R2)
//   private endpoints for Key Vault (vault) and Storage (blob)   (R3, R4)
//   role assignments scoped to vault + storage account           (R6)
//
// network outputs available: network.outputs.appSubnetId, network.outputs.peSubnetId,
//                            network.outputs.keyVaultDnsZoneId, network.outputs.blobDnsZoneId

// ---------------------------------------------------------------- outputs

@description('Virtual network resource ID.')
output vnetId string = network.outputs.vnetId

@description('Resource names used by this deployment (for docs and diagrams).')
output resourceNames object = names
