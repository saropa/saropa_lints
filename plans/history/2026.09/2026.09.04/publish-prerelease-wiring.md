# Publish pipeline: automatic prerelease wiring

`scripts/publish.py` had no coordinated path for shipping a beta/prerelease. The
version-parsing and prompting infrastructure already understood semver
prerelease suffixes (`X.Y.Z-beta.N`), but the three publish targets — VS Code
Marketplace, Open VSX, and the GitHub release — never inspected the version
string, so a hyphenated version would publish to every store's default
(stable) channel with no `--pre-release`/`--prerelease` flag.

## Change

Prerelease routing is now derived automatically from the version string alone
— no new CLI flag, mode, or prompt. `is_prerelease_version()` and
`strip_prerelease_suffix()` were added to `scripts/modules/_utils.py` as the
single source of truth:

- `vsce package`, `vsce publish`, and `ovsx publish`
  (`scripts/modules/_extension_publish.py`) append `--pre-release` when the
  version has a prerelease suffix.
- `gh release create` (`scripts/modules/_git_ops.py`) appends `--prerelease`
  under the same condition.
- The post-publish `pubspec.yaml` snippet (`_publish_workflow.py`
  `print_success_banner`) pins the exact prerelease version instead of a
  caret range — `^1.2.3-beta.1` would resolve straight past the prerelease
  into the next stable major, which is the same class of bug already fixed
  for the tier-yaml pins under issue #216.

## Bug caught in review

The initial implementation wrote the full pub.dev version (including the
`-beta.N` suffix) straight into `extension/package.json`'s `version` field.
The VS Code Marketplace requires that field to be a plain three-part semver;
`vsce` rejects a hyphenated version outright regardless of `--pre-release` —
that flag marks the channel, it does not relax the version-string
requirement. As implemented, no prerelease extension build could have
packaged successfully.

Fix: `package_extension()` now writes `strip_prerelease_suffix(version)` into
`package.json`, while the `.vsix` filename and the `--pre-release` flag
decision continue to use the full pub.dev version (filenames aren't
semver-validated, so they can carry the full identifier for traceability).
Store-publication verification (`_verify_marketplace_and_ovsx`) was updated
to compare against the stripped version too, since that's what the
Marketplace/Open VSX APIs actually report back.

A second review finding — the prerelease-detection rule (`"-" in version`)
duplicated inline in three places — was consolidated into the single
`is_prerelease_version()` helper in `_utils.py`, imported everywhere the
check is needed.

## Files touched

- `scripts/modules/_utils.py` — added `is_prerelease_version`,
  `strip_prerelease_suffix`.
- `scripts/modules/_extension_publish.py` — `--pre-release` flags on
  package/publish commands; `package_extension` strips the version before
  writing `package.json`.
- `scripts/modules/_git_ops.py` — `--prerelease` flag on `gh release create`.
- `scripts/modules/_publish_workflow.py` — exact-pin pubspec snippet for
  prereleases; store-verification now compares the stripped version.
- `scripts/modules/tests/test_marketplace_stored_credential.py` — updated
  for `publish_extension_to_marketplace`'s new `version` parameter.
- `scripts/modules/tests/test_prerelease_version.py` — new: pins
  `is_prerelease_version`/`strip_prerelease_suffix` edge cases and pins
  that `package_extension` never writes a hyphenated version into
  `package.json`.

## Verification

`python -m unittest discover -s scripts/modules/tests -p "test_*.py"` — 142
tests, all passing (135 pre-existing + 7 new).

## Finish Report (2026-09-04)

The handoff reflection flagged the beta-iteration collision as a known,
unaddressed limitation. The user selected all three /finish reflection-gate
options, so it was closed out in the same session rather than deferred.

### Empirical hardening

Three of the five "least confident" items were resolved by directly querying
the tools/APIs involved instead of relying on documentation alone:

- `npx @vscode/vsce package --help` / `publish --help` and `npx ovsx publish
  --help` all confirmed `--pre-release` as the literal flag name in the
  locally resolvable package versions.
- `gh release create --help` confirmed `-p, --prerelease`.
- A live query against the Marketplace `extensionquery` API (`GitHub.copilot`,
  which ships frequent prerelease builds) confirmed `versions[0]` reflects the
  most recently published version regardless of prerelease status — the
  polling code's assumption was correct.
- A live query against the Open VSX API (`eamodio.gitlens`, `preRelease:
  true`) confirmed the same for `_fetch_open_vsx_latest_version`.

The two items left unverified (`dart pub publish`'s native handling of a
hyphenated version was previously reasoned about but not re-run end-to-end
here — inspection of `_publish_steps.py` confirmed it already prints its own
"pre-release caveat" without needing an explicit flag; and `gh release
create --prerelease`'s interaction with an already-existing non-prerelease
release of the same tag remains genuinely untested, though it is guarded by
the pre-existing "release already exists" check regardless of prerelease
status).

### Collision fix (previously deferred, now implemented)

`extension_version_for()` (`scripts/modules/_utils.py`) replaces the plain
`strip_prerelease_suffix()` call at the two sites that write or verify the
extension's Marketplace-facing version
(`_extension_publish.py::package_extension`,
`_publish_workflow.py::_verify_marketplace_and_ovsx`). It offsets PATCH by a
fixed band (500) plus a channel-derived band (a bounded hash of the text
before the trailing iteration number, e.g. "beta" vs "rc") plus the trailing
iteration number itself, so:

- `16.0.0-beta.1` -> `16.0.913`
- `16.0.0-beta.2` -> `16.0.914`
- `16.0.0-rc.1` -> a different value than either beta build

A second code-review pass (looped back into Section 3 per the reflection-gate
protocol) caught that the first version of this fix derived the offset from
only the trailing digit, so `beta.1` and `rc.1` of the same base version
still collided — the channel-name-blind version could not tell "first beta"
from "first rc" apart. Fixed by folding a hash of the channel text into the
offset before the final review pass completed.

### Residual, explicitly accepted risk

The channel band is a bounded hash (`sum(ord(c)) % 1000`), not a registry of
issued versions — two different channel *names* could theoretically hash to
the same band, and the whole scheme is stateless (derived purely from the
version string each time, with no persisted "versions issued so far" ledger).
A fully collision-proof scheme would need such a ledger. This was judged
disproportionate to the actual usage pattern (this project's prerelease
convention is `-beta.N`; alternate channel names are possible but unused in
practice) and was called out rather than silently accepted.

## Verification (final)

`python -m unittest discover -s scripts/modules/tests -p "test_*.py"` — 148
tests, all passing (135 pre-existing + 13 in the new
`test_prerelease_version.py`).
