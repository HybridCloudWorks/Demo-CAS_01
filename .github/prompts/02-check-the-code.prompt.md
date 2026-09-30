---
mode: agent
description: "Demo 02 — run only the repository validation, fix findings, report evidence"
---

Run only the repository validation commands: `scripts/validate.sh` (or `scripts/validate.ps1` on Windows).

- Fix syntax or lint errors in the Bicep files and re-run until the build and lint steps pass.
- If a policy check fails, fix it **only** when the fix is unambiguous under
  `.github/copilot-instructions.md`. Otherwise stop and describe the decision I need to make.
- **Do not deploy.** If I ask for a what-if, run only
  `az deployment group what-if --resource-group <rg> --template-file infra/main.bicep --parameters infra/dev.bicepparam`.

Report each command you ran, its exit code, and its output verbatim. Then list any issue that requires
an architecture decision. Evidence, not "looks good".
