// Least privilege (R6): Storage Blob Data Contributor for one principal, scoped to the storage account.

@description('Existing storage account name in this resource group.')
param storageAccountName string

@description('Principal (object) ID of the identity receiving the role.')
param principalId string

@description('Principal type for the assignment.')
@allowed(['ServicePrincipal', 'User', 'Group'])
param principalType string = 'ServicePrincipal'

// Built-in role: Storage Blob Data Contributor
var blobDataContributorRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
)

resource storage 'Microsoft.Storage/storageAccounts@2024-01-01' existing = {
  name: storageAccountName
}

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, principalId, blobDataContributorRoleId)
  scope: storage
  properties: {
    principalId: principalId
    principalType: principalType
    roleDefinitionId: blobDataContributorRoleId
  }
}

@description('Role assignment resource ID.')
output id string = assignment.id
