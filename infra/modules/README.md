# Modules

One resource type per file. `main.bicep` composes them; it declares no resources directly.

| Module | Status | Provides | Consumed by |
|---|---|---|---|
| `network.bicep` | **present — interface fixed** | VNet, `snet-app` (delegated to App Service), `snet-pe`, `privatelink.vaultcore.azure.net`, `privatelink.blob.*` zones + links | everything below |
| `monitoring.bicep` | present | Log Analytics workspace, workspace-based App Insights | `app`, `keyvault` (diagnostics) |
| `keyvault.bicep` | present | Vault: RBAC, soft delete, purge protection, public access off, diagnostics → workspace | `private-endpoint`, `rbac-keyvault` |
| `storage.bicep` | present | StorageV2: HTTPS, TLS 1.2, no public/shared-key access | `private-endpoint`, `rbac-storage` |
| `app.bicep` | present | Linux plan + site: system identity, VNet integration, hardened siteConfig | `rbac-*` (principalId) |
| `private-endpoint.bicep` | present | Generic PE + DNS zone group (`groupId` = `vault` or `blob`) | — |
| `rbac-keyvault.bicep` | present | Key Vault Secrets User for a principal, scoped to the vault | — |
| `rbac-storage.bicep` | present | Storage Blob Data Contributor for a principal, scoped to the account | — |

Every module: `@description()` on each param, `location` + `tags` in, `id`/`name` (+ endpoint) out, no secrets in outputs.
