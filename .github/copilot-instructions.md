# Copilot instructions — agentic-azure-api

This repository builds **one small, secure Azure API baseline** with Bicep. It is used live in the
Cloud & AI Summit 2026 session *From Cloud Architect to Agentic Architect*. You (the agent) write the
syntax; the architect owns the decisions. Follow these rules on every task.

## Business intent

> Create an internal API environment with managed identity, private data access, secrets management,
> observability, tags, and reviewable documentation.

Full acceptance criteria live in `docs/requirements.md`. Read them before proposing a plan.

## Security rules

- Every compute resource uses a **system-assigned managed identity**. Never create or store keys,
  passwords, or connection strings in Bicep, parameters, or app settings. Reference secrets by
  Key Vault URI or use identity-based access.
- Data services (Key Vault, Storage) are **private by default**: `publicNetworkAccess: 'Disabled'`,
  `networkAcls.defaultAction: 'Deny'`, reached through **private endpoints** in the `snet-pe` subnet
  with private DNS zone groups.
- Key Vault uses **RBAC authorization** (`enableRbacAuthorization: true`), soft delete, and purge protection.
- Storage: HTTPS only, minimum TLS 1.2, `allowBlobPublicAccess: false`, `allowSharedKeyAccess: false`.
- App Service: `httpsOnly: true`, `minTlsVersion: '1.2'`, `ftpsState: 'Disabled'`, VNet integration into
  `snet-app`, `vnetRouteAllEnabled: true`.
- Role assignments are scoped to the **smallest resource** (the vault, the storage account) — never the
  resource group or subscription. Use built-in roles only.

## Governance rules

- Every taggable resource carries the `tags` object from `main.bicep`. Required keys:
  `workload`, `environment`, `owner`, `costCenter`, `managedBy`.
- Naming: `<abbr>-<workload>-<environment>[-<suffix>]` using the `names` variable in `main.bicep`
  (storage accounts and Key Vault use the compact, globally-unique form already defined there).
- Location comes from the `location` parameter (defaults to the resource group location). Do not hardcode regions.
- Environment is one of `dev`, `test`, `prod` and is passed via `infra/<env>.bicepparam`.
- Prefer stable API versions. Do not use `-preview` versions without saying why.

## Change boundaries

- **Do not deploy.** Never run `az deployment group create`, `az deployment sub create`, or any command
  that changes Azure. `what-if` is the only deployment command you may run, and only when asked.
- Do not modify `infra/modules/network.bicep` outputs or parameters. It is the shared platform piece;
  other modules consume its outputs (`appSubnetId`, `peSubnetId`, `keyVaultDnsZoneId`, `blobDnsZoneId`).
- One resource type per module under `infra/modules/`. `main.bicep` composes modules; it does not declare
  resources directly except through modules.
- Do not add new Azure services beyond the requirements without asking. If scope is ambiguous, **stop
  and ask** — do not guess.
- Do not touch files under `.github/` unless the task is explicitly about them.

## How to work (the loop)

1. **Plan first.** For any change touching more than one file, list the files you will change, the
   assumptions you are making, the risks, and the checks you will run. **Wait for approval** before editing.
2. **Act minimally.** Edit only the files in the approved plan. Run the minimum tools needed.
3. **Validate.** Run `scripts/validate.sh` (or `scripts/validate.ps1` on Windows). Fix errors and
   re-run until it passes. Report each command and its result verbatim — do not summarize a failure as a pass.
4. **Report.** Finish with: files changed, validation output, open decisions that need the architect,
   and anything you assumed.

## Completion rules

A task is complete only when all of the following are true:

- `az bicep build --file infra/main.bicep` succeeds with no errors.
- `az bicep lint --file infra/main.bicep` reports no errors (warnings must be listed).
- `scripts/validate.sh` policy checks pass (tags, identity, public access, TLS, secrets scan).
- Documentation that describes infrastructure is generated **from the Bicep source**, not from memory.
  Mark anything you could not verify as an *assumption*.
- You never claim a deployment occurred.
