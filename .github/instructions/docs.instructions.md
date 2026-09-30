---
applyTo: "docs/**/*.md,README.md"
---

# Documentation conventions

- **Generate from source.** Read `infra/main.bicep` and `infra/modules/*.bicep` before writing. Every
  resource, parameter, and relationship you document must exist in the Bicep. If you cannot find it, do
  not write it.
- Separate **Facts** (verified in source or validation output) from **Assumptions** (inferred). Use a
  visible `> **Assumption:**` callout for anything inferred.
- Never state that a deployment happened, that a resource exists in Azure, or that validation passed
  unless you are quoting actual command output from this session.
- ADRs follow `docs/adr/template.md`: Context → Decision → Alternatives considered → Consequences →
  Follow-up risks. Number them `ADR-NNN-kebab-title.md`.
- Diagrams are **Mermaid in Markdown** under `docs/diagrams/`. Node labels use the resource names from
  the `names` variable in `main.bicep`. Show subnets as subgraphs and private endpoints as explicit nodes.
- README sections, in order: Purpose · Architecture (link the diagram) · Prerequisites · Parameters
  (table from `main.bicep`) · Validate · Deploy safely (what-if first) · Documentation index.
- Keep prose short. Tables for parameters and resources; bullets only for procedural steps.
