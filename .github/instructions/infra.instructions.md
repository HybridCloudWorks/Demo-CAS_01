---
applyTo: "infra/**/*.bicep,infra/**/*.bicepparam"
---

# Bicep conventions for this repository

- `targetScope = 'resourceGroup'` in `main.bicep`. Modules do not set a scope.
- Every module starts with `@description()` on each parameter and ends with `output` declarations that
  other modules need (`id`, `name`, and any endpoint/URI). Outputs never expose secrets.
- Pass `location` and `tags` into every module that creates taggable resources; apply both to every resource that supports them.
- Use `resource ... existing` plus `scope:` for role assignments so the assignment is scoped to the
  target resource, not the resource group.
- Role assignment names are `guid(<targetResourceId>, <principalId>, <roleDefinitionId>)` so they are idempotent.
- Private endpoints: one `Microsoft.Network/privateEndpoints` plus a child `privateDnsZoneGroups`
  that links the matching `privatelink.*` zone from `network.bicep` outputs.
- Use string interpolation (`'${a}-${b}'`) rather than `concat()`. Use `uniqueString(resourceGroup().id)`
  for global-name suffixes.
- No `@secure()` parameters with default values. No literal secrets anywhere.
- Prefer the most recent **stable** API version you are confident exists. If unsure, keep the version
  already used in the module you are editing.
- Keep modules small: one primary resource (plus its direct children) per file.
