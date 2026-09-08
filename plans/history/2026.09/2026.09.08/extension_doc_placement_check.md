# Doc-placement extension-native check

Reports still reading as open work were sometimes filed directly under the
workspace's archive/history directory by habit, and nothing re-scanned that
directory for unresolved findings once a document landed there. This adds
an extension-native diagnostic that catches the case at file-open/save time.

## Summary

Reviewed `bugs/proposal_infra_doc_history_vs_bugs_placement.md` and found
two factual errors in its Implementation Notes: it claimed `markdownUtils.ts`
and `pathUtils.ts`/`projectRoot.ts` could be reused for structural markdown
parsing and glob matching, but neither utility exists in either file, and
no glob-matching dependency (`minimatch`/`micromatch`) is present in
`extension/package.json`. Corrected the proposal doc, then implemented the
feature.

## What changed

- `extension/src/extensionChecks/docPlacementCheck.ts` (new): mirror image
  of the existing `bugArchivalCheck.ts`. Flags a markdown file matching a
  configurable archive glob (default `**/plans/history/**/*.md`) whose text
  still matches an "open work" signal (open `Status:`/`Severity:` field, an
  unresolved severity table cell, or an unaddressed action-items heading)
  with no overriding "closed" signal. Diagnostic lands on line 1 via the
  check's own `vscode.DiagnosticCollection`, following the exact
  `bugArchivalCheck.ts` pattern (own collection, scan on open/save/config
  change, no shared registry).
- Glob matching: no existing utility does this, and no glob dependency is
  installed, so a small purpose-built `globToRegExp` (`**`/`*` only) was
  written and exported for direct unit testing, rather than adding a new
  dependency for one setting.
- Five new settings under `saropaLints.docPlacement.*`: `enabled`,
  `archiveGlob`, `openIssuesDir`, `openSignals`, `closedSignals` — added to
  `extension/package.json` (schema + defaults) and `extension/package.nls.json`
  (English descriptions).
- `docPlacement.diagnostic.message` key added to
  `extension/src/i18n/locales/en.json`; not yet propagated to other locale
  catalogs (see Not Yet Verified).
- Wired into `extension/src/extension.ts` via `registerDocPlacementCheck`,
  registered alongside `registerBugArchivalCheck`.
- `extension/src/test/extensionChecks/docPlacementCheck.test.ts` (new): 22
  unit tests total in the `extensionChecks` suite (was 10) covering the
  glob matcher and the diagnostic logic, including the proposal's three
  worked examples.
- `CHANGELOG.md`: added an `### Added (Extension)` bullet under
  `[16.2.0] — Unreleased`.

## Review findings acted on

A `/code-review medium` pass on the diff surfaced two defects in the new
check before it shipped, both fixed:

1. The shipped default `archiveGlob` (`**/docs/history/**/*.md`) did not
   match this repository's own archive convention
   (`plans/history/YYYY.MM/YYYYMMDD/*.md`, per `ISSUE_REPORT_GUIDE.md` and
   `bugArchivalCheck.ts`'s archive target), so the check would have been
   silently inert here without a manual settings override. Changed the
   default to `**/plans/history/**/*.md`.
2. The default `Status:`/`Severity:` regexes only matched
   `**Status: Fixed**` (bold wraps the whole field) and missed
   `**Status:** Fixed` (bold wraps only the label) — a style this repo's
   own archived docs commonly use. Added `\*{0,2}` right after the field's
   colon to absorb both styles, in both the open and closed signal
   defaults, in the code, `package.json`, and the test fixtures.

Three other findings from that same review pass (`scripts/modules/_utils.py`
version-parity guard, and English-placeholder translations in `th.json`/
`sw.json`) are pre-existing modifications unrelated to this change — present
in git status before this task started — and were left untouched as out of
scope.

## Not yet verified

Per `.claude/rules/extension-verification.md`, this is unverified: the five
new settings and the live diagnostic have not been seen in the Extension
Development Host (F5). Typechecks (`tsc --noEmit -p .` and
`tsc -p tsconfig.test.json`) and the scoped mocha run
(`extensionChecks/**/*.test.js`, 22/22 passing) are green, but that proves
logic, not rendering — settings-UI labels and live Problems-panel behavior
need a human look.

The new `docPlacement.diagnostic.message` and `config.property.docPlacement.*`
strings exist only in English; other locale catalogs were not regenerated
(`extension/scripts/generate_translations.py` requires explicit in-the-moment
authorization per global instructions and was not run this session).

## Second pass: hardening + move-to-bugs quick fix (commit `6dc1d830`)

At the `/finish` reflection gate, the user selected both "harden reflection
items" and "implement the unrequested feature." Both were done in one
follow-up pass, committed separately from the first draft above (the first
draft had already been swept into `350b3c52` by a concurrent process before
this pass could commit it).

Hardening:

- Extracted `extension/src/extensionChecks/docConventions.ts` (new) —
  `ARCHIVE_DIR = 'plans/history'` and `OPEN_ISSUES_DIR = 'bugs'` as the
  single source of truth. Both `docPlacementCheck.ts` and the pre-existing
  `bugArchivalCheck.ts` now derive their directory-matching logic from it,
  so the two mirror checks can no longer drift apart on directory names.
- Fixed a second latent regex gap the first pass missed: the default
  `Status:`/`Severity:` signals absorbed bold wrapping a field's *label*
  (`**Status:**`) but not bold wrapping only its *value*
  (`Severity: **Critical**`). Added a second `\*{0,2}` before the value in
  both signal defaults, in code, `package.json`, and test fixtures.
- Applied the identical bold-label regex fix to `bugArchivalCheck.ts`'s
  pre-existing `STATUS_LINE_PATTERN` — same bug, same fix, a file this task
  did not originally author but which shared the defect.
- `compilePatterns()` now `console.warn`s (with the offending source string)
  when a user-supplied regex setting fails to compile, instead of failing
  silently.
- The config-change rescan handler now filters to
  `doc.languageId === 'markdown'` before rescanning open documents, instead
  of relying on `validateDocument`'s own early return for every open
  document on every settings change.

Move-to-bugs quick fix (the unrequested feature):

- `computeDocPlacementDiagnostic` now sets `diag.code = 'docPlacement'` so a
  `CodeActionProvider` can scope to only this check's diagnostics.
  Deliberately not `diag.source` (`'Saropa Lints'`), which is shared by
  every check in the extension and is not a safe filter key on its own —
  the pre-existing `StaleIgnoreCodeActionProvider` filters by `source`
  alone, a latent cross-provider collision risk this pass did not copy.
- New `DocPlacementCodeActionProvider` offers one quick fix
  ("Move to bugs/") wired to a new `saropaLints.docPlacement.
  moveToOpenIssues` command.
- New `moveToOpenIssuesCommand(uri, openIssuesDir)`: resolves the workspace
  folder, computes the target path under `openIssuesDir`, refuses to
  proceed if a file already exists there, tries `git mv` first (so the move
  is tracked as a rename in git history) falling back to a plain
  `vscode.workspace.fs.rename` if `git mv` fails (not a git repo, untracked
  file, git not on PATH), then opens the moved file at its new path.
- Three new `docPlacement.*` l10n keys for the quick-fix title and two error
  messages (no workspace folder, target already exists).

Testing: 7 more unit tests added (bold-value severity, glob edge cases,
invalid-regex warning, the `diag.code` field, and
`DocPlacementCodeActionProvider` filtering with/without a matching
diagnostic) — 29/29 passing in `extensionChecks/**/*.test.js`. Both
typechecks (`tsc --noEmit -p .`, `tsc -p tsconfig.test.json`) clean.

Still not yet verified: F5 in the Extension Development Host (settings UI
rendering, live diagnostic + quick-fix behavior, enable/disable toggle) —
requires a human look per `.claude/rules/extension-verification.md`. Locale
catalogs for the three new l10n keys added in this pass have also not been
checked against the unrelated `350b3c52` locale regen for stale English
placeholders.
