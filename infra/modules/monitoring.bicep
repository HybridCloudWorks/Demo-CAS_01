// Observability: Log Analytics workspace + workspace-based Application Insights (R5).

@description('Azure region for all resources.')
param location string

@description('Log Analytics workspace name.')
param workspaceName string

@description('Application Insights component name.')
param appInsightsName string

@description('Tags applied to every resource.')
param tags object

@description('Log retention in days.')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

resource workspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspace.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

@description('Log Analytics workspace resource ID.')
output workspaceId string = workspace.id

@description('Application Insights resource ID.')
output appInsightsId string = appInsights.id

@description('Application Insights connection string (not a secret: it identifies the ingestion endpoint).')
output appInsightsConnection string = appInsights.properties.ConnectionString
