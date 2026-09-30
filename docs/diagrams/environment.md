# Environment architecture — `casapi` / `dev`

Generated from `infra/main.bicep` and `infra/modules/*.bicep`. Node labels are the `names` variable
values with `workload = casapi`, `environment = dev`; `<sfx>` is `take(uniqueString(resourceGroup().id), 6)`.

```mermaid
flowchart TB
  classDef compute fill:#1E67C4,stroke:#0E2A4A,color:#fff
  classDef data fill:#0E2A4A,stroke:#0E2A4A,color:#fff
  classDef net fill:#EAF3FC,stroke:#3BA0E8,color:#0E2A4A
  classDef obs fill:#10B981,stroke:#0E2A4A,color:#fff
  classDef dns fill:#F7F8FA,stroke:#94A3B8,color:#0E2A4A

  subgraph RG["Resource group · tags: workload, environment, owner, costCenter, managedBy"]
    subgraph VNET["vnet-casapi-dev · 10.20.0.0/16"]
      subgraph SNETAPP["snet-app · 10.20.1.0/24 · delegated Microsoft.Web/serverFarms"]
        APP["app-casapi-dev-&lt;sfx&gt;<br/>Linux App Service · system-assigned identity<br/>httpsOnly · TLS 1.2 · FTPS off · vnetRouteAll"]:::compute
      end
      subgraph SNETPE["snet-pe · 10.20.2.0/24"]
        PEKV["pe-kv-casapi-dev<br/>groupId: vault"]:::net
        PEST["pe-st-casapi-dev<br/>groupId: blob"]:::net
      end
    end

    PLAN["asp-casapi-dev<br/>Linux plan · B1"]:::compute
    KV["kv-casapi-dev-&lt;sfx&gt;<br/>RBAC · soft delete · purge protection<br/>publicNetworkAccess: Disabled"]:::data
    ST["stcasapidev&lt;sfx&gt;<br/>StorageV2 · HTTPS · TLS 1.2<br/>no public blob · no shared key · public access Disabled"]:::data
    LOG["log-casapi-dev<br/>Log Analytics · 30d"]:::obs
    APPI["appi-casapi-dev<br/>Application Insights (workspace-based)"]:::obs

    ZKV["privatelink.vaultcore.azure.net<br/>linked to vnet-casapi-dev"]:::dns
    ZBLOB["privatelink.blob.core.windows.net<br/>linked to vnet-casapi-dev"]:::dns
  end

  PLAN --- APP
  APP -- "HTTPS via private DNS" --> PEKV --> KV
  APP -- "HTTPS via private DNS" --> PEST --> ST
  PEKV -. "privateDnsZoneGroups" .-> ZKV
  PEST -. "privateDnsZoneGroups" .-> ZBLOB
  APP -- "Key Vault Secrets User<br/>(scope: vault)" --> KV
  APP -- "Storage Blob Data Contributor<br/>(scope: account)" --> ST
  APP -- "APPLICATIONINSIGHTS_CONNECTION_STRING" --> APPI --> LOG
  KV -. "diagnostics: audit + AllMetrics" .-> LOG
```

## Reading the diagram

| Edge | Source of truth |
|---|---|
| App → private endpoints → data services | `app.bicep` (`virtualNetworkSubnetId`, `vnetRouteAllEnabled`), `private-endpoint.bicep` |
| Private endpoints → DNS zones | `private-endpoint.bicep` (`privateDnsZoneGroups`), `network.bicep` (zones + links) |
| Role edges | `rbac-keyvault.bicep`, `rbac-storage.bicep` (`scope:` on the target resource) |
| Telemetry | `app.bicep` app settings, `monitoring.bicep`, `keyvault.bicep` diagnostics |

> **Assumption:** The App Service is shown without an inbound private endpoint because
> `appPublicNetworkAccess = 'Enabled'` in `dev.bicepparam` (ADR-001). Nothing here reflects a deployed
> environment; it is derived from source only.
