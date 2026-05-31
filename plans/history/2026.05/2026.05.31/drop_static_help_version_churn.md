# Drop static `views.help.name` version churn

## Trigger

After landing the CI test-path fix and removing the post-publish auto-bump
(commit `5e1943ba` earlier in this session), three `extension/package.nls.*.json`
files remained modified in the working tree (`ar`, `fa`, `pl`) with a stale
`(الإصدار 13.11.1)` / `(نسخه 13.11.1)` / `(wersja 13.11.1)` translated
parenthetical alongside the suffix `(v13.11.2)`. The user asked: "why do
these exist, and can we fix it." Investigation traced the residue to a
manifest-time sync script writing a value that the runtime code at
[extension/src/extension.ts:506-513](../../../../extension/src/extension.ts#L506-L513)
explicitly overrides; the static value is dead code that nobody reads.

## Finish Report (2026-05-31)

### Scope

(C) docs/scripts only — `extension/scripts/`, manifest static `package.nls*.json`
bundles, and `CHANGELOG.md`. No Dart / `lib/` / analyzer code touched.

### Root cause

Four layers stacked:

1. [`extension/scripts/sync-help-version.js`](../../../../extension/scripts/sync-help-version.js)
   ran at `npm precompile` and rewrote `views.help.name` in every
   `package.nls*.json`. Its strip regex `/\s*\(v[^\)]*\)\s*$/u` only matched
   lowercase Latin `v`, so the trailing `(v13.11.X)` advanced each release but
   any translated version paren that crept in (Arabic `(الإصدار X.Y.Z)`,
   Persian `(نسخه X.Y.Z)`, Polish `(wersja X.Y.Z)`) was treated as part of
   the "base label" and persisted forever, drifting one release behind the
   visible suffix.
2. `extension/scripts/i18n/generate_locales.py` (the MT pipeline) produced
   slightly different output across runs for the same input — different
   Arabic word for "Help" between two consecutive calls in the same publish
   flow.
3. The publish workflow called `package_extension(version)` twice
   ([_publish_workflow.py:967](../../../../scripts/modules/_publish_workflow.py#L967)
   pre-commit, then again at
   [_publish_workflow.py:835](../../../../scripts/modules/_publish_workflow.py#L835)
   inside `run_extension_after_publish`). The first run's output was
   committed; the second run's output churned the working tree post-commit
   and was never staged. That is why these three locales appeared modified
   after the `Release v13.11.2` commit landed.
4. The runtime override in `extension.ts` already produces `Help (vX.Y.Z)`
   at activation time, with the localized word coming from `l10n('findingsDash.menuPalette.help')`
   and the version from `context.extension.packageJSON.version`. The static
   `views.help.name` value is visible only briefly during extension activation
   before the runtime code sets `helpView.title`.

### Changes

- Deleted `extension/scripts/sync-help-version.js`.
- Removed the `require('./sync-help-version')` line from
  `extension/scripts/copy-codicons.js`.
- Stripped the version suffix from `views.help.name` in all 25
  `extension/package.nls*.json` bundles (English + 24 locale bundles).
  Each value is now just the localized word for "Help" — e.g. `"Help"`,
  `"Hilfe"`, `"مساعدة"`, `"راهنما"`, `"Pomoc"`, `"帮助"` — no version, no
  duplicate translated paren.
- Added a Maintenance bullet under `[Unreleased]` in `CHANGELOG.md`.

### Why this is safe

The runtime `createTreeView().title` injection at
[extension.ts:511](../../../../extension/src/extension.ts#L511) sets the
Help panel title to `${l10n('findingsDash.menuPalette.help')} (v${helpExtVersion})`
on every activation. That code path was added explicitly to retire the
static value (see the comment at lines 499-505: "The version must NOT be
baked into the localized view name…"). Users continue to see the live
`Help (vX.Y.Z)` from `package.json`'s version field. The brief pre-activation
fallback (vscode rendering the panel title from the manifest before the
extension's `activate` runs) now shows just "Help" / "Hilfe" / etc., which
is correct localized copy.

### Why this is durable

- The MT pipeline (`generate_locales.py`) now translates the static word
  "Help" once per locale and caches the result. The cache key no longer
  contains a version number, so it doesn't bust on every release.
- The strip-regex-only-matches-Latin-`v` bug is removed alongside the
  script that contained it; even if a future MT pass produced a translated
  parenthetical, it would not stack release-on-release because there is no
  per-release rewrite step.

### Test audit

Grepped `extension/src/test/`, `test/`, and `scripts/modules/tests/` for
`sync-help-version`, `sync_help_version`, `views.help.name`, `copy-codicons`,
and `package.nls`. The only hit was
[extension/src/test/views/uxLabels.test.ts:47-49](../../../../extension/src/test/views/uxLabels.test.ts#L47-L49),
which loads `package.nls.json` as a `%key%` resolution table for placeholder
checks. It does not pin the value of `views.help.name` nor assert any
`(vX.Y.Z)` substring; the placeholder resolution continues to work because
the key still exists and still resolves to a non-undefined string.

No Python test under `scripts/modules/tests/` references any changed symbol.
Python suite ran green earlier this session (53/53). Extension TS suite
not executed in this environment — audited by inspection only.

### Files changed

- Deleted: `extension/scripts/sync-help-version.js`
- Modified: `extension/scripts/copy-codicons.js` (removed 2 lines: the comment
  and the `require`)
- Modified: 25 × `extension/package.nls*.json` (single value per file)
- Modified: `CHANGELOG.md` (added one Maintenance bullet)
- Created: this finish report at
  `plans/history/2026.05/2026.05.31/drop_static_help_version_churn.md`

### Scope-bounded follow-ups (not in this commit)

- The redundant second `package_extension(version)` call inside
  `run_extension_after_publish` is still in place. It is now harmless
  (regenerated values are stable) but remains wasteful work that could be
  removed to drop one repackage cycle per publish. Out of scope for this
  task; flagged here so a future cleanup pass has the reference.

`Bug archived: No bug archive — task did not close a bugs/*.md file.`
`Finish report saved: plans/history/2026.05/2026.05.31/drop_static_help_version_churn.md`
