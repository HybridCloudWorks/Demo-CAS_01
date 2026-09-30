---
mode: agent
description: "Demo 01 — plan the Azure baseline, wait for approval, then build it"
---

Review the requested Azure baseline in `docs/requirements.md` and the rules in
`.github/copilot-instructions.md`.

**Do not edit yet.**

Produce a plan that lists:
1. The minimum set of files you will create or change under `infra/` (one module per resource type).
2. Assumptions you are making (SKUs, retention, names, regions, anything not stated in the requirements).
3. Risks and the architecture decisions that need my input before you proceed.
4. The exact validation commands you will run when finished.

Then **wait for my approval**. After approval, implement the plan exactly, run `scripts/validate.sh`
(or `scripts/validate.ps1`), fix any errors, and report: files changed, validation output verbatim,
and open decisions.
