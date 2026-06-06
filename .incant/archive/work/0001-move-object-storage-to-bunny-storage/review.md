---
id: "0001"
slug: move-object-storage-to-bunny-storage
stage: review
reviewed: 2026-06-05
commit: f8d7b9fc
---

# Move Object Storage To Bunny Storage — review
<!-- Single fresh-eyes pass against spec + plan + acceptance + active principles. -->
<!-- Each finding: file:line — what's wrong; why it matters; how to fix. status: open|addressed|wontfix (+ note). -->

### Strengths
- config/storage.yml:9 — Production storage is now a clearly named `bunny` S3-compatible service, with endpoint, region, bucket, access key, and secret key all fetched from environment variables rather than committed provider literals.
- config/environments/production.rb:26 — Production Active Storage points at `:bunny`, matching the renamed service and keeping the vendor switch explicit.
- config/initializers/active_storage.rb:1 — The Rails proxy-route behavior is preserved while the committed R2 fallback credentials were removed.
- config/deploy.yml:67 — Rails upload settings and credentials are separated from the backup accessory configuration, supporting the spec's separate-zone/separate-credential requirement.
- config/deploy.yml:132 — The backup accessory now gets its endpoint, region, and bucket from Bunny backup-zone deployment environment values instead of committed Cloudflare R2 literals.
- .gitignore:29 and docs/bunny-storage-migration.md:1 — `/docs/` is ignored and the local runbook covers setup, rclone copy/verification, deploy checks, variants, backups, R2 read-only fallback, rollback, and final credential removal without adding it to git.

### Blocker
- None.

### Major
- .incant/work/0001-move-object-storage-to-bunny-storage/plan.md:78 — The Phase 0001-P2 quality gate is not freshly passing in this review: `bin/rails runner ...` and `bin/rails test` both exit before Rails boots with `Bundler::RubyVersionMismatch` because the active local Ruby is 4.0.2 while the Gemfile specifies 3.3.5. The grep check and ignored-runbook check pass, and the plan records implementation-session evidence under Ruby 3.3.11 plus a human waiver for the unfinished test suite, but the spec acceptance criterion requires automated checks to pass locally without Bunny credentials before release. status: wontfix (human explicitly accepted this as-is on 2026-06-05)

### Minor
- None.

### Nit
- None.

### Verdict
Ready to release? **Yes** — the only major finding is explicitly waived by the human. The configuration and runbook changes align with the migration requirements, with implementation-session gate evidence recorded and no open blocker/major findings.
