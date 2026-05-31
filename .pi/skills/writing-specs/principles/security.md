---
name: security
applies: [spec]
heading: Security
enabled: true
---

Ensure the spec addresses the security posture of the feature being built.

Call out, where relevant:
- **Trust boundaries** — what input is untrusted (user, network, external API) and where it is
  validated.
- **Secrets** — how credentials/tokens are stored and accessed (env/secret-manager, never
  committed; never written into `.incant/` or session transcripts).
- **Common vulnerability classes** for this surface — injection, XSS, SSRF, path traversal,
  authz/authn gaps — and how each is avoided.
- **Blast radius** — what a failure or compromise can reach, and how it is contained.

A lightweight, targeted note is the goal — not a full STRIDE document. If a dimension does not
apply, say so in one line.
