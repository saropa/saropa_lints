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
