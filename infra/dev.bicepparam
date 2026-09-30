using 'main.bicep'

param environment = 'dev'
param workload = 'casapi'
param owner = 'platform-team'
param costCenter = 'CC-1234'

// Open decisions, resolved for dev (see docs/adr/ADR-001-private-access.md):
param appPublicNetworkAccess = 'Enabled' // smoke-testable from the presenter laptop; data stays private
param keyVaultSoftDeleteDays = 7 // fast cleanup in dev; prod uses the 90-day default
