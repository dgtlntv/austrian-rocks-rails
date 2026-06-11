---
id: "0011"
slug: self-host-inter-glyphs-for-shared-map-styles
branch: incant/0011-self-host-inter-glyphs-for-shared-map-styles
title: Self-host Inter glyphs for shared map styles
stage: review
status: in-progress
created: 2026-06-11
updated: 2026-06-11
commit: 73d3705d
spec_commit: 581501fe
---

# Plan — Self-host Inter glyphs for shared map styles

## Status
- Work item: `0011` / `self-host-inter-glyphs-for-shared-map-styles`
- Stage: review
- Branch: `incant/0011-self-host-inter-glyphs-for-shared-map-styles`
- Current phase: `0011-P2` complete; awaiting phase review.
- Next step: run `/incant:review 0011`.
- Blockers: none.
- Spec staleness check: `spec.md` was drafted against `581501fe`; current HEAD was `73d3705d` before implementation, whose only project change was the committed 0011 spec/session artifacts on top of `581501fe`. I re-read the affected map tile/style code before editing and the spec still holds.
- Fresh verification:
  - 2026-06-11: Phase 0011-P1 gate passed in Docker because local `bin/rails` uses Ruby 4.0.2 while the Gemfile requires 3.3.5: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:${POSTGRES_PASSWORD:-password}@db:5432/austrian-rocks-test web bash -lc 'bin/rails test test/lib/map_tiles/configuration_test.rb test/lib/map_tiles/style_materializer_test.rb'` → 22 runs, 1022 assertions, 0 failures, 0 errors, 0 skips.
  - 2026-06-11: Phase 0011-P2 gate passed in Docker: `docker compose run --rm -e RAILS_ENV=test -e DATABASE_URL=postgis://austrian-rocks:${POSTGRES_PASSWORD:-password}@db:5432/austrian-rocks-test web bash -lc 'bin/rails test test/lib/map_tiles/font_assets_test.rb test/lib/map_tiles/style_materializer_test.rb'` → 7 runs, 963 assertions, 0 failures, 0 errors, 0 skips.
- Key decisions:
  - The configured glyph subpath is `fonts/inter-v1`, rooted under the existing `map_styles` style prefix.
  - MapLibre style `text-font` replacements are one-to-one: `Roboto-Light` → `Inter Light`, `Roboto-Regular` → `Inter Regular`, `Roboto-Medium` → `Inter Medium`, `Roboto-Bold` → `Inter Bold`, `Roboto-MediumItalic` → `Inter Medium Italic`, and `RobotoCondensed-BoldItalic` → `Inter Bold Italic`.
  - The dedicated font publisher is separate from normal PMTiles/style/sprite/manifest release publishing and does not require a map artifact version.

## Files touched
- `config/map_tiles.yml` — add the stable `font_glyph_subpath: fonts/inter-v1` configuration value inherited by all environments.
- `lib/map_tiles/configuration.rb` — expose validated font glyph helpers: `font_glyph_subpath`, `font_glyph_root`, `font_glyph_object_prefix`, and `font_glyphs_template_url`.
- `config/map_styles/austrian_rocks_light.json` — switch committed light style glyph URL and every `layout.text-font` stack to the approved Inter stacks.
- `config/map_styles/austrian_rocks_dark.json` — switch committed dark style glyph URL and every `layout.text-font` stack to the approved Inter stacks.
- `lib/map_tiles/style_materializer.rb` — materialize the glyph URL from configuration and reject disallowed glyph/font references.
- `app/javascript/controllers/map_controller.js` — switch the web-only dynamic contribution text layer to `Inter Regular`.
- `config/map_styles/fonts/inter-v1/` — add committed runtime glyph PBF folders for the six approved Inter stacks.
- `config/map_styles/fonts/inter-v1/README.md` — record the committed PBF tree purpose, provenance, approved stacks, and update rule.
- `config/map_styles/fonts/inter-v1/LICENSE.md` — record Inter's SIL Open Font License 1.1 provenance and runtime PBF licensing note.
- `lib/map_tiles/font_publisher.rb` — add a dedicated idempotent Bunny/S3 publisher for committed glyph PBF assets.
- `lib/map_tiles/cli.rb` — add `publish-fonts` CLI command with test injection for the font publisher.
- `lib/tasks/map_tiles.rake` — add `map_tiles:publish_fonts` Rails task.
- `config/map_styles/README.md` — add committed maintainer summary for self-hosted Inter glyphs and the separate publish path.
- `docs/map_tiles.md` — update the ignored local maintainer/operator doc with the font publish and `inter-v2` update workflow.
- `test/lib/map_tiles/configuration_test.rb` — cover configured font subpath, URL, root, object prefix, and unsafe subpath rejection.
- `test/lib/map_tiles/style_materializer_test.rb` — cover committed and materialized glyph/font invariants, approved Inter stacks, and dynamic contribution font use.
- `test/lib/map_tiles/font_assets_test.rb` — cover committed glyph tree shape, PBF-only runtime assets, and documentation presence.
- `test/lib/map_tiles/font_publisher_test.rb` — cover static font upload keys, sorting/idempotency, headers, path safety, and credential-safe failures.
- `test/lib/map_tiles/cli_test.rb` — cover `publish-fonts` command behaviour and no version/smoke/clean coupling.
- `test/lib/map_tiles/bunny_publisher_test.rb` — assert normal map release publishing still excludes font glyph uploads.

## Phase 0011-P1 — Config-derived glyph URL and Inter style contract
Goal: The committed and materialized shared styles, plus the web-only dynamic contribution labels, use Inter glyphs/font stacks with automated tests preventing Bergwerk/Mapbox glyph or Roboto regressions.

- [x] Read before editing: `config/map_tiles.yml`, `lib/map_tiles/configuration.rb`, `lib/map_tiles/style_materializer.rb`, `config/map_styles/austrian_rocks_light.json`, `config/map_styles/austrian_rocks_dark.json`, `app/javascript/controllers/map_controller.js`, `test/lib/map_tiles/configuration_test.rb`, and `test/lib/map_tiles/style_materializer_test.rb`.
- [x] In `config/map_tiles.yml`, add `font_glyph_subpath: fonts/inter-v1` to the default map tile settings under `style_prefix: map_styles`, so development, test, and production inherit the same glyph version path.
- [x] In `lib/map_tiles/configuration.rb`, add:
  - `font_glyph_subpath`, validating the configured path as slash-separated safe segments with no blank, `.`, or `..` segment;
  - `font_glyph_root`, returning `Rails.root.join("config/map_styles", font_glyph_subpath)`;
  - `font_glyph_object_prefix`, returning `object_key(style_prefix, font_glyph_subpath)`;
  - `font_glyphs_template_url`, returning `#{public_cdn_base}/#{font_glyph_object_prefix}/{fontstack}/{range}.pbf`.
- [x] In `config/map_styles/austrian_rocks_light.json` and `config/map_styles/austrian_rocks_dark.json`, set top-level `glyphs` to `https://tiles.austrian.rocks/map_styles/fonts/inter-v1/{fontstack}/{range}.pbf`.
- [x] In both style JSON templates, replace every single-value `layout.text-font` array using this exact mapping: `Roboto-Light` to `Inter Light`, `Roboto-Regular` to `Inter Regular`, `Roboto-Medium` to `Inter Medium`, `Roboto-Bold` to `Inter Bold`, `Roboto-MediumItalic` to `Inter Medium Italic`, and `RobotoCondensed-BoldItalic` to `Inter Bold Italic`.
- [x] In `lib/map_tiles/style_materializer.rb`, assign `style["glyphs"] = configuration.font_glyphs_template_url` during materialization before writing the style artifact, and validate that each style has no `basemap.bergwerk-gis.at/basemap-download/webapp/fonts`, no `mapbox://fonts`, no `Roboto` text-font value, and no `text-font` outside `Inter Light`, `Inter Regular`, `Inter Medium`, `Inter Bold`, `Inter Medium Italic`, or `Inter Bold Italic`.
- [x] In `app/javascript/controllers/map_controller.js`, change the `contribute-problems-texts` layer layout from `"text-font": ["Roboto-Regular"]` to `"text-font": ["Inter Regular"]`.
- [x] In `test/lib/map_tiles/configuration_test.rb`, assert the default test configuration exposes `font_glyph_subpath == "fonts/inter-v1"`, `font_glyph_root == Rails.root.join("config/map_styles/fonts/inter-v1")`, `font_glyph_object_prefix == "map_styles/fonts/inter-v1"`, and `font_glyphs_template_url == "https://tiles.austrian.rocks/map_styles/fonts/inter-v1/{fontstack}/{range}.pbf"`; also add unsafe subpath assertions for `/fonts/inter-v1`, `fonts//inter-v1`, `fonts/../inter-v1`, and `fonts/inter v1`.
- [x] In `test/lib/map_tiles/style_materializer_test.rb`, add `APPROVED_INTER_FONT_STACKS = ["Inter Light", "Inter Regular", "Inter Medium", "Inter Bold", "Inter Medium Italic", "Inter Bold Italic"]`, assert committed template glyphs equal the production Inter URL, assert materialized artifact glyphs equal `@configuration.font_glyphs_template_url`, replace current Roboto contour/overlay expectations with Inter expectations, and add helpers that scan all `text-font` arrays plus generated JSON for forbidden Bergwerk glyph URL, `mapbox://fonts`, and `Roboto`.
- [x] In `test/lib/map_tiles/style_materializer_test.rb`, add a controller-source assertion that `app/javascript/controllers/map_controller.js` includes `"text-font": ["Inter Regular"]` and does not include `"text-font": ["Roboto-Regular"]`.

**Quality gate:** `bin/rails test test/lib/map_tiles/configuration_test.rb test/lib/map_tiles/style_materializer_test.rb` → all configuration and style materializer tests pass, proving the glyph URL is config-derived for materialized styles and committed/materialized style contracts reject Bergwerk/Mapbox/Roboto font regressions.

## Phase 0011-P2 — Commit runtime Inter v1 glyph assets and provenance
Goal: The repository contains the approved runtime Inter PBF glyph tree, documents its provenance/license, and commits no Inter source font binaries.

- [x] Read before editing: `tmp/font-maker-2026-06-11T14_25_38.391Z/`, `config/map_styles/README.md`, and `test/lib/map_tiles/style_materializer_test.rb`.
- [x] Create `config/map_styles/fonts/inter-v1/` with exactly these approved stack directories copied from `tmp/font-maker-2026-06-11T14_25_38.391Z/`: `Inter Light`, `Inter Regular`, `Inter Medium`, `Inter Bold`, `Inter Medium Italic`, and `Inter Bold Italic`.
- [x] Copy every `*.pbf` file from each approved source stack directory into its matching `config/map_styles/fonts/inter-v1/<stack>/` directory, preserving filenames such as `0-255.pbf`, and do not copy unapproved Inter/Inter Display stack directories.
- [x] Add `config/map_styles/fonts/inter-v1/README.md` documenting: these are committed MapLibre runtime glyph PBFs, the CDN path is `map_styles/fonts/inter-v1/{fontstack}/{range}.pbf`, the approved stacks are the six Inter stacks listed above, the source tree was `tmp/font-maker-2026-06-11T14_25_38.391Z/` generated on 2026-06-11, normal PMTiles releases do not upload fonts, and future updates must create `inter-v2` instead of mutating `inter-v1`.
- [x] Add `config/map_styles/fonts/inter-v1/LICENSE.md` documenting that Inter is copyright The Inter Project Authors, licensed under SIL Open Font License 1.1, with source project `https://github.com/rsms/inter`, and that this repository commits generated runtime PBF glyph assets only, not `.ttf`, `.otf`, `.woff`, or `.woff2` source font binaries.
- [x] Add `test/lib/map_tiles/font_assets_test.rb` with assertions that `config/map_styles/fonts/inter-v1/` contains exactly the approved stack directories plus documentation files, each approved stack has at least `0-255.pbf` and only `.pbf` files, no `.ttf`, `.otf`, `.woff`, or `.woff2` file exists under the tree, and the README/LICENSE files mention `SIL Open Font License 1.1`, `tmp/font-maker-2026-06-11T14_25_38.391Z`, and `inter-v2`.

**Quality gate:** `bin/rails test test/lib/map_tiles/font_assets_test.rb test/lib/map_tiles/style_materializer_test.rb` → all font asset and style contract tests pass, proving the committed runtime glyph tree matches the approved Inter stack set and contains no source font binaries.

## Phase 0011-P3 — Dedicated static font publisher command
Goal: Operators can publish the committed Inter PBF tree to Bunny/CDN under `map_styles/fonts/inter-v1/` without coupling that upload to normal map releases.

- [ ] Read before editing: `lib/map_tiles/bunny_publisher.rb`, `lib/map_tiles/cli.rb`, `lib/tasks/map_tiles.rake`, `test/lib/map_tiles/bunny_publisher_test.rb`, and `test/lib/map_tiles/cli_test.rb`.
- [ ] Add `lib/map_tiles/font_publisher.rb` defining `MapTiles::FontPublisher` with `Error`, `ConfigurationError`, and `UploadError` subclasses, `PBF_CONTENT_TYPE = "application/x-protobuf"`, `IMMUTABLE_CACHE_CONTROL = "public, max-age=31536000, immutable"`, and the same five required Bunny environment variable names used by map release publishing.
- [ ] Implement `MapTiles::FontPublisher#publish` to validate Bunny env presence, validate `configuration.public_cdn_host`, validate `configuration.style_prefix`, validate `configuration.font_glyph_root` exists, collect sorted `*.pbf` files below that root, require at least one PBF, and upload each file with stable keys rooted at `configuration.font_glyph_object_prefix` such as `map_styles/fonts/inter-v1/Inter Regular/0-255.pbf`.
- [ ] In `MapTiles::FontPublisher`, normalize every PBF path with `realpath`, reject files outside `configuration.font_glyph_root.realpath`, reject relative path segments that are blank, `.`, `..`, or contain characters outside letters, numbers, spaces, dots, underscores, and dashes, reject non-`.pbf` upload candidates, and omit credential values and raw service error messages from raised errors.
- [ ] In `lib/map_tiles/cli.rb`, require `map_tiles/font_publisher`, update `USAGE` to include `publish-fonts`, add `font_publisher_class: FontPublisher` injection, route `publish-fonts` to `font_publisher_class.new(configuration: configuration, out: out).publish`, reject unknown options for that command, and do not require `--version`, run smoke, or run local artifact cleanup for font publishing.
- [ ] In `lib/tasks/map_tiles.rake`, add `desc "Publish committed MapLibre font glyph PBFs to Bunny/CDN"` and `task publish_fonts: :environment` that exits with `MapTiles::CLI.new([ "publish-fonts" ]).run`.
- [ ] Add `test/lib/map_tiles/font_publisher_test.rb` using temporary font roots and a fake S3 client to assert deterministic sorted object keys with spaces, repeat `publish` calls upload the same keys/bodies/headers, `.pbf` uploads use `application/x-protobuf` and immutable cache control, missing env/root/PBFs fail safely, path escape/symlink candidates are rejected, and an AWS service error containing `super-secret` produces an `UploadError` without `super-secret`.
- [ ] Update `test/lib/map_tiles/cli_test.rb` with a fake font publisher class and tests that `publish-fonts` succeeds without a version, does not call smoke/publish/clean for map releases, rejects unknown options, and returns status `1` with usage when the font publisher raises `MapTiles::FontPublisher::Error`.

**Quality gate:** `bin/rails test test/lib/map_tiles/font_publisher_test.rb test/lib/map_tiles/cli_test.rb` → all font publisher and CLI tests pass, proving the static font publish path is repeatable, safely keyed, credential-safe, and separate from map release publish flow.

## Phase 0011-P4 — Documentation and normal-release separation proof
Goal: Maintainers have clear publish/update instructions, and automated tests prove normal PMTiles/style/sprite releases do not upload font glyphs.

- [ ] Read before editing: `config/map_styles/README.md`, `docs/map_tiles.md`, and `test/lib/map_tiles/bunny_publisher_test.rb`.
- [ ] In `config/map_styles/README.md`, add a committed section stating that shared styles use self-hosted Inter glyphs at `https://tiles.austrian.rocks/map_styles/fonts/inter-v1/{fontstack}/{range}.pbf`, list the six approved Inter font stacks, point to `config/map_styles/fonts/inter-v1/README.md`, and state that `bin/build_pmtiles publish` does not upload fonts.
- [ ] In ignored local `docs/map_tiles.md`, replace the sentence saying only glyphs still come from Bergwerk with a statement that glyphs are self-hosted Inter PBFs under `map_styles/fonts/inter-v1/`, add the configured font glyph subpath to the settings list, and add operator commands `bin/build_pmtiles publish-fonts` and `bin/rails map_tiles:publish_fonts`.
- [ ] In `docs/map_tiles.md`, document first-rollout verification with `curl -I 'https://tiles.austrian.rocks/map_styles/fonts/inter-v1/Inter%20Regular/0-255.pbf'`, document that `%20` is only for manual URL checks because Bunny object keys and MapLibre font stacks contain spaces, and document future upgrade flow: generate a new PBF tree outside the app pipeline, add a new configured subpath such as `fonts/inter-v2`, update styles/tests, run `publish-fonts`, and leave `inter-v1` immutable.
- [ ] In `test/lib/map_tiles/bunny_publisher_test.rb`, add an assertion to the existing upload plan test that no normal release upload key includes `/fonts/` or starts with `styles/fonts/`, proving `MapTiles::BunnyPublisher#publish` still publishes only PMTiles, styles, sprite objects, and manifest.
- [ ] Run a final repository scan command to prove committed/shared map style and dynamic contribution sources contain no forbidden glyph/font references.

**Quality gate:** `bin/rails test test/lib/map_tiles/configuration_test.rb test/lib/map_tiles/style_materializer_test.rb test/lib/map_tiles/font_assets_test.rb test/lib/map_tiles/font_publisher_test.rb test/lib/map_tiles/cli_test.rb test/lib/map_tiles/bunny_publisher_test.rb && ! rg -n 'basemap\.bergwerk-gis\.at/basemap-download/webapp/fonts|mapbox://fonts|Roboto' config/map_styles/austrian_rocks_*.json app/javascript/controllers/map_controller.js && test -z "$(find config/map_styles/fonts/inter-v1 -type f \( -name '*.ttf' -o -name '*.otf' -o -name '*.woff' -o -name '*.woff2' \) -print -quit)"` → all targeted tests pass, forbidden shared-style/controller font references are absent, and no Inter source font binaries are committed under the runtime glyph tree.

## Coverage self-review
- [x] Requirement 1 maps to 0011-P1 style JSON glyph edits and style tests.
- [x] Requirement 2 maps to 0011-P1 font-stack mapping and approved-stack tests.
- [x] Requirement 3 maps to 0011-P1 Austrian Rocks overlay font expectations for `regions`, `clusters`, `areas`, `boulders-texts`, selected layers, POIs, and any other `austrian-rocks` symbol layer with `text-font`.
- [x] Requirement 4 maps to 0011-P1 `app/javascript/controllers/map_controller.js` edit and controller-source assertion.
- [x] Requirement 5 maps to 0011-P2 glyph tree copy plus README/LICENSE and font asset tests.
- [x] Requirement 6 maps to 0011-P2 no-source-font-binaries tests and final scan.
- [x] Requirement 7 maps to 0011-P1 `config/map_tiles.yml` and `MapTiles::Configuration#font_glyphs_template_url`.
- [x] Requirement 8 maps to 0011-P3 `MapTiles::FontPublisher` and tests for keys/headers/path safety.
- [x] Requirement 9 maps to 0011-P3 CLI separation and 0011-P4 `BunnyPublisher` no-font-upload assertion.
- [x] Requirement 10 maps to 0011-P1 style/materializer tests and 0011-P4 final scan.
- [x] Requirement 11 maps to 0011-P3 font publisher tests.
- [x] Documentation acceptance maps to 0011-P2 glyph README/LICENSE and 0011-P4 maintainer docs.
- [x] First rollout verification acceptance maps to 0011-P4 `curl -I` documentation.
- [x] Symbol/signature consistency checked: configuration helpers are consistently named `font_glyph_subpath`, `font_glyph_root`, `font_glyph_object_prefix`, and `font_glyphs_template_url`; CLI command is consistently `publish-fonts`; Rails task is consistently `map_tiles:publish_fonts`.
- [x] Goal-level verification checked: final gate proves styles, assets, publisher, CLI separation, normal-release separation, forbidden references, and source-binary absence together.
- [x] No placeholders: every phase names concrete files, constants, commands, and expected behaviours.

## Implementation checkpoint
Phase 0011-P2 is complete and ready for phase review. Continue with Phase 0011-P3 only after `/incant:review 0011` clears this phase without open blocker/major findings.
