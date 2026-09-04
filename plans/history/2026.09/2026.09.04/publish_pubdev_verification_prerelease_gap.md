# Pub.dev verification step never recognized pre-release publishes

`verify_pubdev_publication` in `scripts/modules/_publish_steps.py` polled pub.dev's package API and compared the expected version only against `data["latest"]["version"]`. Pub.dev's `latest` field always reflects the newest *stable* release and never points at a pre-release (e.g. `16.0.0-beta.1`), even after that pre-release publishes successfully. A `16.0.0-beta.1` release would therefore have polled for the full 10-minute timeout and printed a false "did not report v16.0.0-beta.1" warning after a successful `dart pub publish`.

## Context

Triggered while preparing `16.0.0` to ship as a gated pre-release (`16.0.0-beta.1`) rather than a default-installed stable version, so existing `^15.x` consumers are not force-upgraded onto the new LSP-server BETA feature. `_version_changelog.py` already had correct pre-release semver handling (regex, sort order, `-beta.N` increment logic) — the gap was isolated to the final store-verification step.

## Fix

Added `is_version_published(package_name, version) -> bool`, which checks the full `versions` list from the pub.dev package API rather than `latest`. `verify_pubdev_publication` now branches: for a pre-release expected version (contains `-`), it checks membership via `is_version_published`; for a stable version, it keeps using `latest` as before (unchanged behavior for every existing stable release flow).

`CHANGELOG.md` heading changed from `## [16.0.0] — Unreleased` to `## [16.0.0-beta.1] — Unreleased` so the publish pipeline's version-sync/tag-clash logic picks up the pre-release string at the next release run.

## Verification

No existing Python test suite covers `scripts/modules/` (publish tooling has no pytest harness; it is validated by its own audit/dry-run gates at publish time). Verified by direct execution: loaded the module, stubbed the `print_*` I/O helpers, mocked `urllib.request.urlopen` to return a fixture pub.dev API response containing both a stable and a pre-release version, and asserted all four cases — pre-release published, pre-release not yet published, stable published, stable not yet published — resolve correctly. All four passed.

`/code-review low` on the diff (this file + `.gitignore` unrelated pre-existing entry) reported no findings.
