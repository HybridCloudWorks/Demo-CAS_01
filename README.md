# agentic-azure-api

Demo repository for **From Cloud Architect to Agentic Architect** — The Cloud & AI Summit 2026,
St. Charles, MO · Saul Patino.

> `main` is the **complete build** — the expected end state of the three live demos. The session starts
> from the `starting-state` branch (rules, requirements, network module only) and the agent builds the rest
> live: `git checkout starting-state`.

## Purpose

A small, secure Azure API baseline for an internal API: Linux App Service with a system-assigned managed
identity, VNet-integrated, reaching Key Vault and Storage over private endpoints only, observed through
Log Analytics and Application Insights, tagged and named consistently, and documented from source.

## Architecture

See [`docs/diagrams/environment.md`](docs/diagrams/environment.md) (Mermaid) and
[ADR-001 — private access](docs/adr/ADR-001-private-access.md).

| Resource (name for `casapi`/`dev`) | Module | Key properties (from source) |
|---|---|---|
| `vnet-casapi-dev` · `snet-app` · `snet-pe` | `network.bicep` | 10.20.0.0/16; app subnet delegated to `Microsoft.Web/serverFarms`; PE subnet network policies disabled |
| `privatelink.vaultcore.azure.net`, `privatelink.blob.core.windows.net` | `network.bicep` | linked to the VNet, registration off |
| `log-casapi-dev` | `monitoring.bicep` | PerGB2018, 30-day retention |
| `appi-casapi-dev` | `monitoring.bicep` | workspace-based Application Insights |
| `kv-casapi-dev-<sfx>` | `keyvault.bicep` | RBAC auth, soft delete (7d dev), purge protection, public access **Disabled**, ACL default Deny, audit logs → workspace |
| `stcasapidev<sfx>` | `storage.bicep` | StorageV2 LRS, HTTPS only, TLS 1.2, no public blob, **no shared key**, public access **Disabled**, blob soft delete 7d |
| `pe-kv-casapi-dev` (vault) · `pe-st-casapi-dev` (blob) | `private-endpoint.bicep` | in `snet-pe`, each with a `privateDnsZoneGroups` child |
| `asp-casapi-dev` · `app-casapi-dev-<sfx>` | `app.bicep` | Linux B1; **SystemAssigned** identity; httpsOnly; TLS 1.2; FTPS off; VNet-integrated; route-all; app settings carry Key Vault URI + storage name only |
| Role assignments | `rbac-keyvault.bicep`, `rbac-storage.bicep` | Key Vault Secrets User on the vault; Storage Blob Data Contributor on the account — **resource-scoped** |

## Prerequisites

- VS Code with the Bicep and GitHub Copilot extensions (`.vscode/extensions.json`).
- Azure CLI with Bicep (`az bicep install`). `jq` for `validate.sh`; `validate.ps1` needs nothing extra.
- Azure login only for the optional, read-only `--what-if`.

## Parameters (`infra/main.bicep`)

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `location` | string | resource group location | never hardcode a region |
| `environment` | `dev` · `test` · `prod` | — | drives names and tags |
| `workload` | string (3–10) | `casapi` | used in every resource name |
| `owner` | string | — | `owner` tag |
| `costCenter` | string | — | `costCenter` tag |
| `appPublicNetworkAccess` | `Enabled` · `Disabled` | `Enabled` | open decision 1 — App Service inbound; data services are always private |
| `keyVaultSoftDeleteDays` | int 7–90 | `7` | open decision 2 |

`infra/dev.bicepparam` resolves the open decisions for `dev` and says why.

## Validate

```bash
scripts/validate.sh                              # build · lint · secrets scan · policy checks
scripts/validate.sh --what-if rg-casapi-dev      # + read-only what-if
```

```powershell
./scripts/validate.ps1
./scripts/validate.ps1 -WhatIf -ResourceGroup rg-casapi-dev
```

Record the output in [`docs/validation-evidence.md`](docs/validation-evidence.md). The scripts never deploy.

## Deploy safely (outside the session)

1. `az group create -n rg-casapi-dev -l <region> --tags workload=casapi environment=dev owner=<you> costCenter=<cc>`
2. `scripts/validate.sh --what-if rg-casapi-dev` — expect only `Create` on a first run.
3. `az deployment group create -g rg-casapi-dev -f infra/main.bicep -p infra/dev.bicepparam`
4. Open a PR with the evidence file filled in. The PR is the control plane.

> **Assumption:** Nothing on this branch has been deployed. Every property above is read from the Bicep
> source, not from a live environment.

## Documentation index

- [Requirements](docs/requirements.md)
- [ADR index](docs/adr/README.md) · [ADR-001 private access](docs/adr/ADR-001-private-access.md)
- [Environment diagram](docs/diagrams/environment.md)
- [Validation evidence](docs/validation-evidence.md)
- [Copilot instructions](.github/copilot-instructions.md)
