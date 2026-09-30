# Validation evidence

Paste the **verbatim** output of the validation run here before opening the pull request. Do not
summarize a failure as a pass. Nothing below is pre-filled with results on purpose.

## Run

| Field | Value |
|---|---|
| Date / time | |
| Machine | |
| Command | `scripts/validate.sh` · `scripts/validate.ps1` |
| Git commit | |
| `az --version` / `az bicep version` | |

## Build

```text
<paste az bicep build output>
```

## Lint

```text
<paste az bicep lint output — list every warning, even accepted ones>
```

## Policy checks

```text
<paste the PASS / FAIL / WARN lines>
```

## What-if (read-only, optional)

Resource group: `rg-casapi-dev`

```text
<paste the adds / changes / deletes summary — expected: only Create for a first run>
```

## Reviewer attention

Items the machine cannot judge — the architect signs these off:

- [ ] Role assignments are scoped to the vault and the storage account (not the resource group)
- [ ] DNS: both `privatelink.*` zones are linked to `vnet-casapi-dev` and each private endpoint has a zone group
- [ ] `appPublicNetworkAccess` value is intentional for this environment (ADR-001)
- [ ] Soft-delete / retention values are intentional for this environment
- [ ] No new Azure services beyond `docs/requirements.md`
- [ ] Unresolved lint warnings are listed and accepted
