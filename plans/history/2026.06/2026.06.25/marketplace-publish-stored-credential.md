# Marketplace publish — stored-credential fallback

The publish script never pushed the VS Code extension to the Marketplace when the
`VSCE_PAT` environment variable was unset, even though vsce held a valid stored
login for the publisher. Every release advanced pub.dev, Open VSX, the git tag,
and the GitHub release while the Marketplace silently stayed a version behind,
forcing a manual `.vsix` upload each time.

## Finish Report (2026-06-25)

### Defect

`publish_extension_to_marketplace` in `scripts/modules/_extension_publish.py`
read `VSCE_PAT` from the environment and, when it was empty and the interactive
PAT prompt was declined, returned early with "Skipping VS Code Marketplace
publish." It treated an empty env var as "cannot publish." vsce authenticates
from EITHER `VSCE_PAT` OR a stored `vsce login` credential (a PAT or, on vsce
3.x, a Microsoft Entra browser login that creates no PAT at all). On a machine
authenticated via `vsce login`, the credential was present and valid
(`vsce verify-pat saropa` succeeds with no env var), but the script ignored it
and skipped. The sibling saropa_workspace publish script does not exhibit this
because it calls `vsce publish` directly and lets vsce resolve the stored login.

Observed on the 14.2.2 release: Open VSX published via `ovsx publish`, pub.dev
confirmed 14.2.2, the tag and GitHub release were created, and the store
verification loop then reported the Marketplace stuck on 14.2.1 for the full
polling window.

### Fix

When `VSCE_PAT` is absent, the Marketplace step now resolves the publisher id
from `extension/package.json` and probes for a usable stored login with a
read-only `vsce verify-pat <publisher>` before deciding to skip:

- New `_read_extension_publisher(project_dir)` — parses the `publisher` field
  from `extension/package.json`; returns `""` (never raises) on a missing or
  malformed manifest so the publish degrades rather than crashing.
- New `_has_stored_vsce_credential(publisher)` — runs `vsce verify-pat`
  (read-only; no packaging, no upload) and returns whether vsce can
  authenticate to that publisher by any means.
- `publish_extension_to_marketplace` falls through to the existing
  `vsce publish --packagePath` call when a stored login is found, and only
  prompts/skips when there is genuinely no env var, no stored login, and no
  pasted PAT. This matches the path saropa_workspace already uses.

### Adjacent packaging fix

The extension `.vsix` shipped 1200 files (17.7 MB) of dev-only content —
`test-ux/` UX screenshots, `reports/` i18n translation-audit markdown, and
`**/*.map` source maps. `.vscodeignore` never excluded those directories, and
its bare `*.md` rule only matched the package root, so nested `reports/*.md`
leaked through. The ignore list now excludes `test-ux/**`, `reports/**`, and
`**/*.map`, and uses `**/*.md` with the README and CHANGELOG re-included.
`vsce ls` confirms the package drops from 1200 to 555 files.

### Tests

`scripts/modules/tests/test_marketplace_stored_credential.py` (6 cases,
`unittest`):

- `_read_extension_publisher`: reads the publisher field; returns `""` for a
  missing file, malformed JSON, or a missing `publisher` key.
- The regression itself: with no `VSCE_PAT` and a valid stored login (mocked
  `verify-pat` exit 0), a `vsce publish` command is issued and the PAT prompt is
  not consulted.
- The negative guard: with no env var, no stored login (mocked `verify-pat`
  exit 1), and a declined prompt, no publish command runs and the step skips.

Run from repository root:
`python -m unittest scripts.modules.tests.test_marketplace_stored_credential` —
6 passed.

### Scope

Publish tooling and packaging only. No Dart lint rules, analyzer code, tiers, or
extension user-facing strings were touched.
