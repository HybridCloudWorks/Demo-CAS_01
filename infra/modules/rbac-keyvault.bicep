// Least privilege (R6): Key Vault Secrets User for one principal, scoped to the vault — not the resource group.

@description('Existing Key Vault name in this resource group.')
param keyVaultName string

@description('Principal (object) ID of the identity receiving the role.')
param principalId string

@description('Principal type for the assignment.')
@allowed(['ServicePrincipal', 'User', 'Group'])
param principalType string = 'ServicePrincipal'

// Built-in role: Key Vault Secrets User
var keyVaultSecretsUserRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4633458b-17de-408a-b874-0445c86b69e6'
)

resource vault 'Microsoft.KeyVault/vaults@2024-11-01' existing = {
  name: keyVaultName
}

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vault.id, principalId, keyVaultSecretsUserRoleId)
  scope: vault
  properties: {
    principalId: principalId
    principalType: principalType
    roleDefinitionId: keyVaultSecretsUserRoleId
  }
}

@description('Role assignment resource ID.')
output id string = assignment.id
