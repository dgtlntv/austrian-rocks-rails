---
id: "0001"
slug: move-object-storage-to-bunny-storage
stage: archived
completed: 2026-06-06
commit: f8d7b9fc
---

# Summary — Move Object Storage To Bunny Storage

## What was built
- Production Active Storage now uses a `bunny` S3-compatible service instead of the former Cloudflare R2-backed service.
- Bunny upload storage configuration is sourced from environment/Kamal secrets rather than committed provider literals or credentials.
- Database backups are configured to target a separate Bunny backup zone with a separate credential set.
- Committed Rails R2 read-only fallback credentials were removed from the Active Storage runtime.
- `/docs/` is gitignored, and a local ignored `docs/bunny-storage-migration.md` runbook documents Bunny setup, rclone copy/verification, deployment checks, backup verification, R2 read-only fallback, rollback, and final R2 credential removal.

## Deviations from spec
- The full Rails test suite did not pass locally during final review because the active local Ruby did not match the Gemfile; implementation-session evidence recorded the targeted storage checks under an available Ruby, and the remaining automated-check gap was explicitly accepted as `wontfix` by the human on 2026-06-05.
- Deployment secret mapping was tightened after the original implementation shape so Bunny endpoint/region/bucket values are supplied through Kamal secrets rather than clear env entries.

## Key decisions
- Use a vendor-explicit Active Storage service name, `bunny`, instead of keeping the old `amazon` service name.
- Keep Rails upload storage and database backup storage in separate Bunny zones with separate credentials.
- Keep R2 only as an operational read-only fallback window outside Rails; no automatic Rails fallback to R2 was added.
- Keep the migration runbook local and uncommitted by ignoring `/docs/`.

## Links
- Final reviewed commit: `f8d7b9fc`
- Branch: `incant/0001-move-object-storage-to-bunny-storage`

## Sessions
- `019e9854-ad66-777d-ba98-524ec6403a0b`
- `019e9856-5de1-73c5-996d-f4aa4efa6740`
- `019e986c-b6cc-701b-8a70-fc9252019427`
- `019e9871-8579-755e-837a-1c05deda3573`
- `019e987a-1b6d-7253-b681-97ac9e0d499b`
- `019e987d-25f1-73bb-b2fa-2bcf452e24c5`
- `019e9884-0d4c-7756-a848-d55a1f2bd40e`
- `019e9caf-65e0-7beb-9e89-0966b170ca74`

## Follow-ups
- None.
