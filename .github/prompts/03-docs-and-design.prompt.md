---
mode: agent
description: "Demo 03 — generate README, ADR-001, and the Mermaid architecture from the validated Bicep"
---

Using the **validated Bicep files as the only source of truth** (`infra/main.bicep`, `infra/modules/*.bicep`,
`infra/dev.bicepparam`):

1. Update `README.md` following `.github/instructions/docs.instructions.md` (purpose, architecture link,
   prerequisites, parameter table generated from `main.bicep`, validate, deploy safely, documentation index).
2. Create `docs/adr/ADR-001-private-access.md` from `docs/adr/template.md`, recording the decision to make
   Key Vault and Storage private-endpoint-only with public access disabled. Include alternatives considered
   and the operational consequences (DNS, developer access, CI access).
3. Generate `docs/diagrams/environment.md` with a Mermaid diagram of the resource relationships: subnets as
   subgraphs, private endpoints and DNS zones as explicit nodes, identity/RBAC edges labeled with the role.

Distinguish **facts** (present in source) from **assumptions** (inferred) using the `> **Assumption:**`
callout. **Do not claim deployment occurred.** Finish with the list of files created or changed.
