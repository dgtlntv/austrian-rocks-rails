---
name: code-documentation
applies: [spec]
heading: Code documentation
enabled: true
---

Ensure the spec calls out the documentation expectations for code touched by the feature.
Documentation should explain **what the code does and why it exists** where that is not obvious;
it should not restate every line or spam comments around self-explanatory implementation details.
Prefer concise, useful docs at module boundaries, public APIs, non-obvious decisions, and tricky
edge cases.

State explicitly, where relevant:
- Which new or changed modules/functions need documentation and what the docs should clarify.
- Any non-obvious behaviour, invariants, side effects, or error cases that should be documented
  near the code.
- How documentation will be kept tasteful: enough context for maintainers, no noisy paraphrases
  of obvious code.

For **TypeScript and JavaScript** files, require proper JSDoc:
- Each source file should have a file-level JSDoc block describing the file's responsibility.
- Every function should have JSDoc describing what it does.
- Function JSDoc should document parameters/properties (`@param`) and return values (`@returns`)
  where applicable, including async return behaviour when useful.
- Keep JSDoc accurate and concise; avoid boilerplate that says nothing beyond the signature.

If the feature does not touch code, or touches only files where inline documentation is not useful,
say so in one line and why.
