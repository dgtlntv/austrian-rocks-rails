---
name: config-vs-code
applies: [spec]
heading: Config vs code
enabled: true
---

Ensure the spec keeps **configuration separated from code**. Wherever it makes sense,
configurable values live in a dedicated config file (e.g. a JSON file) that the code imports —
not inlined as literals scattered through logic. Behaviour then changes by editing config, not
by editing and redeploying code.

State explicitly in the spec:
- Which values are configuration, and the dedicated file/format that holds them.
- How the code consumes that config (imported/loaded, not hardcoded).
- The defaults and their rationale.

This is a "where sensible" rule, not an absolute — not every constant warrants externalising.
If separating configuration does not make sense for this feature, say so in one line and why.
