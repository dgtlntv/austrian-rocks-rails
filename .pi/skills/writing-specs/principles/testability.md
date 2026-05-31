---
name: testability
applies: [spec]
heading: Testability
enabled: true
---

Ensure the spec states how the feature will be **verified**, so the plan can turn each
requirement into a checkable quality gate.

State explicitly:
- The **testing strategy** — unit, integration, or manual, and why that level fits.
- Which behaviours get **automated tests**, and the exact command that runs them.
- How the acceptance criteria map to **observable, pass/fail** checks (no "looks reasonable").
- Any **seams** the design needs to be testable (injected dependencies, pure cores, fixtures)
  rather than bolting tests on afterwards.

If a part is genuinely only verifiable by hand, say so and describe the manual check.
