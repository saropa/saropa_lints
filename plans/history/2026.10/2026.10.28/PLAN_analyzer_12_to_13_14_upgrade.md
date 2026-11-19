# PLAN: Analyzer upgrade (12 to 13/14) without breaking target projects

**Status (2026-10-28):** Shipped. saropa_lints 17.0.0 is on pub.dev (`analyzer >=13.0.0 <15.0.0`, `meta ^1.18.0`). Analyzer 12 projects stay on the frozen 16.x line (16.10.0 carries `meta ^1.18.0`). Only the open items below remain.
**Terms:** "target project" installs saropa_lints. "The package" is saropa_lints.

## Decisions (owner, 2026-10-27)

- Lower the `meta` floor to `^1.18.0` in a 16.x patch so Flutter 3.44 and older (meta pinned to exactly 1.18.0) can resolve it (D1).
- Move to analyzer 13/14 in a major (17.0.0), Dart floor 3.11, no back-ports to 16.x (D4).
- Extension offers only versions the project can resolve and reads the plugin version from `analysis_options.yaml`.
- CI covers analyzer 13.0.0 (lowest) and 14.6.0 (latest), plus the scratch-project solver test.

## Shipped (verified 2026-10-28)

- 17.0.0 and 16.10.0 on pub.dev; details in CHANGELOG 17.0.0.
- Migration, compat card, startup detection, rename-migration command, analyzer-matrix workflow (`.github/workflows/analyzer-matrix.yml`, latest runs green), solver script (`scripts/check_pub_solver.py`), pre-commit spelling speed-up (45 s to 7.5 s), stale `meta`/Flutter statements in pubspec, PACKAGE_VIBRANCY.md and CHANGELOG.
- Uncommitted in the working tree: the start-up upgrade offer now also runs when Lint integration is Off (extension.ts gate removed, CHANGELOG entry added).

## Open items

1. **Translations (decision 2026-10-28).** 124 strings across 24 locales are untranslated (`debug.ci.publish.pubspecHasOtherEdits`, `compat.recommend.*`, `compat.card.*`, `compat.apply.*`, `command.configureCompatibility.title` in `package.nls.<locale>.json`). `localeParity.test.js` keeps failing (npm test exit 48). Owner has no GPU, cannot run the translation pipeline, and chose to move past it. English sources: `extension/src/i18n/locales/en.json`, `extension/package.nls.json`.
2. **Never exercised:** extension `HealthPanel` flow (needs a live VS Code host); scan CLI after `init`; first run of the light/full rule lane in an isolate with a custom `projectRoot`.

## Decision 2026-10-28: 17.0.0 retraction

17.0.0 was published to pub.dev as stable (2026-10-29 00:30 UTC, tag v17.0.0) but was meant to be a beta. Owner decided: retract 17.0.0 on pub.dev (allowed for 7 days after publish) and continue with 17.0.1-beta.1.
