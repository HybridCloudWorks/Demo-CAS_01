# Requirements — internal API baseline

## Business intent

> Create an internal API environment with managed identity, private data access, secrets management,
> observability, tags, and reviewable documentation.

## Scope

One resource group, one environment (`dev` first), one workload (`casapi`). Small enough to understand in a
90-minute session; rich enough to exercise identity, networking, access, and operations decisions.

## Functional requirements

| # | Requirement | Acceptance criteria |
|---|---|---|
| R1 | Host an internal HTTP API | Linux App Service (B1 is acceptable for `dev`) with **system-assigned managed identity**, `httpsOnly`, TLS 1.2 minimum, FTPS disabled |
| R2 | Reach data services privately | App Service is **VNet-integrated** into `snet-app`; all outbound traffic routes through the VNet (`vnetRouteAllEnabled`) |
| R3 | Store secrets | Key Vault with **RBAC authorization**, soft delete, purge protection; **public network access disabled**; reached via private endpoint in `snet-pe` with `privatelink.vaultcore.azure.net` DNS |
| R4 | Store application data | Storage account (StorageV2, LRS in `dev`); HTTPS only, TLS 1.2, no public blob access, **shared-key access disabled**, **public network access disabled**; blob private endpoint in `snet-pe` with `privatelink.blob.core.windows.net` DNS |
| R5 | Observe the application | Log Analytics workspace + Application Insights (workspace-based); App Service receives the connection string as an app setting; Key Vault sends diagnostic logs to the workspace |
| R6 | Least-privilege access | App Service identity gets **Key Vault Secrets User** on the vault and **Storage Blob Data Contributor** on the storage account — scoped to those resources only |
| R7 | Governance | Every taggable resource carries `workload`, `environment`, `owner`, `costCenter`, `managedBy` tags; names follow the `names` variable in `main.bicep` |
| R8 | Reviewable documentation | README, ADR-001 (private access decision), Mermaid architecture diagram, and validation evidence — all generated from the Bicep source |

## Non-functional constraints

- **No live deployment** during the session. Build, lint, what-if, document, review only.
- Bicep only. Modules under `infra/modules/`, one resource type each. `network.bicep` already exists and
  its interface is fixed.
- Stable API versions. No preview features.
- Cost-aware defaults for `dev`; `prod` sizing is out of scope but must not be blocked by the design.

## Open decisions (architect input required)

These are deliberately left open. The agent must **ask**, not assume:

1. Should the App Service itself be reachable publicly in `dev` (for smoke testing), or private-endpoint-only?
2. Key Vault soft-delete retention: 7 days (fast `dev` cleanup) or 90 days (default)?
3. Should Storage blob soft delete and versioning be enabled in `dev`?
4. Who owns DNS for `privatelink.*` zones if this moves into a hub-and-spoke landing zone later?
