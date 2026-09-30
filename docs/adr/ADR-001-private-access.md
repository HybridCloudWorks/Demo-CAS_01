# ADR-001: Data services are private-endpoint-only with public network access disabled

- **Status:** Accepted
- **Date:** 2026-09-30
- **Deciders:** Saul Patino (architect)
- **Source files:** `infra/main.bicep`, `infra/modules/keyvault.bicep`, `infra/modules/storage.bicep`,
  `infra/modules/private-endpoint.bicep`, `infra/modules/network.bicep`, `infra/modules/app.bicep`

## Context

Requirements R3 and R4 (`docs/requirements.md`) call for secrets and application data to be reached
privately from an internal API. The App Service must still reach both services after public access is
turned off, and developers and CI must still be able to validate the template without network access to
the data plane.

## Decision

Key Vault and the Storage account set `publicNetworkAccess: 'Disabled'` and
`networkAcls.defaultAction: 'Deny'` (bypass `AzureServices`). Each is reached through a private endpoint
in `snet-pe` (`pe-kv-casapi-dev` → groupId `vault`, `pe-st-casapi-dev` → groupId `blob`), with a
`privateDnsZoneGroups` child linking the matching zone (`privatelink.vaultcore.azure.net`,
`privatelink.blob.core.windows.net`) that `network.bicep` creates and links to `vnet-casapi-dev`.

The App Service is VNet-integrated into `snet-app` with `vnetRouteAllEnabled: true`, so its outbound
calls resolve the `privatelink.*` names through the linked zones and land on the private endpoints.

Access is identity-based: the app's system-assigned identity holds **Key Vault Secrets User** on the
vault and **Storage Blob Data Contributor** on the account, each scoped to that single resource
(`rbac-keyvault.bicep`, `rbac-storage.bicep`). Storage additionally disables shared-key access.

The App Service itself stays publicly reachable in `dev` (`appPublicNetworkAccess = 'Enabled'` in
`dev.bicepparam`) so the presenter can smoke-test it; this is an explicit, parameterized exception.

## Alternatives considered

| Alternative | Why not (for this environment) |
|---|---|
| Service endpoints + VNet rules on the data services | Traffic still exits to the public service IP; no private DNS story; weaker fit for a "private by default" baseline |
| Firewall IP allow-lists | Brittle for App Service outbound IPs, which change; does not meet "public access disabled" |
| Public access enabled with RBAC only | Meets identity requirement but not R3/R4 network posture |
| Private endpoint for the App Service too (fully private) | Correct for prod; in `dev` it removes the ability to smoke-test from a laptop without a jump host. Kept as a parameter (`appPublicNetworkAccess`) |

## Consequences

**Positive**

- Data-plane traffic to Key Vault and Storage never leaves the VNet; public ingress refuses all requests.
- No keys or connection strings exist anywhere in the repo, app settings, or outputs.
- Role assignments are resource-scoped and idempotent (`guid(resourceId, principalId, roleId)`).

**Negative / operational cost**

- **DNS is now load-bearing.** A client without the private zone (an on-prem host, a laptop) resolves the
  public CNAME and is refused. Debugging "403/forbidden" often starts with `nslookup`.
- **Developer and CI access to the data plane is blocked.** Portal secret browsing, `az keyvault secret
  show`, and `az storage blob` from outside the VNet fail by design. Validation in this repo is
  control-plane only (build, lint, what-if), which is unaffected.
- Purge protection on Key Vault means a deleted vault name is unavailable until retention expires
  (7 days in `dev`).
- Two private endpoints and two DNS zones add a small fixed cost and two more resources to reason about.

## Follow-up risks

- DNS ownership → platform team → before this workload joins a hub-and-spoke landing zone (open decision 4).
  Central `privatelink.*` zones would replace the ones `network.bicep` creates.
- `appPublicNetworkAccess` → architect → before `test`/`prod`: flip to `Disabled` and add an App Service
  private endpoint (groupId `sites`) plus `privatelink.azurewebsites.net`.
- Storage soft delete is 7 days in `dev` → architect → confirm for `prod` (open decision 3).

> **Assumption:** The presenter laptop can reach the App Service default hostname over the internet in
> `dev`. Nothing in this repository has been deployed; every statement above describes the Bicep source,
> not a live environment.
