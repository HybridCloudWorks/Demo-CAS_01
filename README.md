# agentic-azure-api

Demo repository for **From Cloud Architect to Agentic Architect** — The Cloud & AI Summit 2026,
St. Charles, MO · Saul Patino.

One small, secure Azure API baseline, built live with **VS Code + GitHub Copilot agent mode** against the
rules in [`.github/copilot-instructions.md`](.github/copilot-instructions.md). The agent writes the syntax;
the architect owns the decision.

> **No live deployment.** Everything in this repo is build → lint → what-if → document → review.

## What gets built

| Artifact | Where | Demo |
|---|---|---|
| Infrastructure as code (Bicep) | `infra/` | 01 — plan, then build |
| Validation evidence | `scripts/validate.sh` · `scripts/validate.ps1` output | 02 — check the code |
| README (this file), `docs/adr/ADR-001-private-access.md` | `docs/` | 03 — docs and design |
| Architecture diagram (Mermaid) | `docs/diagrams/environment.md` | 03 — docs and design |

## Repository layout

```
agentic-azure-api/
├─ .github/
│  ├─ copilot-instructions.md      ← rules the agent follows on every task
│  ├─ instructions/                ← path-specific rules (infra/**, docs/**)
│  ├─ prompts/                     ← the three demo prompts (/01-plan-and-build …)
│  └─ workflows/validate.yml       ← same gates in CI on every PR
├─ infra/
│  ├─ main.bicep                   ← composition root (starting state: network only)
│  ├─ modules/network.bicep        ← shared platform piece — interface fixed
│  ├─ dev.bicepparam
│  └─ bicepconfig.json             ← linter rules
├─ docs/
│  ├─ requirements.md              ← business intent + acceptance criteria
│  ├─ adr/                         ← decision records (template included)
│  └─ diagrams/                    ← Mermaid architecture
├─ scripts/validate.sh · validate.ps1
└─ README.md
```

## Prerequisites

- VS Code with the recommended extensions (`.vscode/extensions.json`): Bicep, GitHub Copilot + Chat.
- Azure CLI with Bicep: `az bicep install` (or `az bicep upgrade`).
- `jq` for the bash validator's policy checks (`validate.ps1` has no extra dependency).
- An Azure login is **optional** — only `--what-if` needs it, and it is read-only.

## Validate

```bash
scripts/validate.sh                              # build · lint · secrets scan · policy checks
scripts/validate.sh --what-if rg-casapi-dev      # + read-only what-if against an existing RG
```

```powershell
./scripts/validate.ps1
./scripts/validate.ps1 -WhatIf -ResourceGroup rg-casapi-dev
```

The scripts never deploy. The output is the evidence you paste into the pull request.

## Parameters (`infra/main.bicep`)

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `location` | string | resource group location | never hardcode a region |
| `environment` | `dev` · `test` · `prod` | — | drives names and tags |
| `workload` | string (3–10) | `casapi` | used in every resource name |
| `owner` | string | — | `owner` tag |
| `costCenter` | string | — | `costCenter` tag |

## Deploy safely (after the session, if you choose to)

1. `az group create -n rg-casapi-dev -l <region> --tags workload=casapi environment=dev owner=<you> costCenter=<cc>`
2. `scripts/validate.sh --what-if rg-casapi-dev` — read the adds/changes/deletes.
3. Only then: `az deployment group create -g rg-casapi-dev -f infra/main.bicep -p infra/dev.bicepparam`
4. Open a PR with the validation output and the what-if summary. The PR is the control plane.

## Documentation index

- [Requirements](docs/requirements.md)
- [Architecture decision records](docs/adr/README.md)
- [Diagrams](docs/diagrams/README.md)
- [Copilot instructions](.github/copilot-instructions.md)
