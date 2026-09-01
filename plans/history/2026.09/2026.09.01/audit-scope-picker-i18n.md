# Full Audit + Findings Dashboard — Missing i18n Strings

The Full Audit feature (`extension/src/audit/`) referenced 47 `audit.*` l10n keys with no corresponding entries in `extension/src/i18n/locales/en.json`. The scope picker, progress notification, error messages, and report webview all rendered raw key paths instead of readable text. Additionally, 3 `findingsDash.script.*` accessibility keys were missing, and the progress-bar message was hardcoded in English.

## Finish Report (2026-09-01)

### Changes

- **`extension/src/i18n/locales/en.json`** — Added 51 keys total:
  - `audit.alreadyRunning`, `audit.noProject`, `audit.missingDep` (command guards)
  - `audit.scope.*` (10 keys: scope picker labels, descriptions, placeholder, branch prompt)
  - `audit.progress.title`, `audit.progress.message` (notification title and localized progress string)
  - `audit.error.*` (3 keys: spawn failure, invalid project, parse failure)
  - `audit.report.*` (27 keys: report webview title, heading, subtitle, baseline tag, search, filters, chips, buttons, table columns, empty states, keyboard hint). `toggleGroup` label corrected to "Toggle grouping" since the button toggles between grouped/ungrouped states.
  - `findingsDash.script.announceSearchVerb`, `.severitiesNoun`, `.impactsNoun` (accessibility announcements)

- **`extension/src/audit/audit-command.ts`** — Replaced hardcoded inline progress message (`${pct}% · ${p.progress}/${p.total} files · ...`) with `l10n('audit.progress.message', { pct, scanned, total, issues, file })`.

- **`extension/scripts/check_l10n_keys.py`** — New CI-ready script that cross-references every `l10n()` call in `extension/src/**/*.ts` against `en.json`:
  - Key existence check: exits 1 when keys are used in code but absent from the catalog.
  - `--check-params` flag: validates interpolation tokens — extracts `{placeholder}` from catalog values and cross-references against the call-site object keys. Handles JS shorthand properties (`{ message }`), nested parentheses in values (`String(totalCount)`), and computed/dynamic key prefixes (`codeHealth.flag.` + var).
  - Proper block-comment and line-comment stripping (string-literal-aware) so doc examples don't register as real call sites.
  - UTF-8 output forced on Windows.

- **`CHANGELOG.md`** — Two maintenance entries under 15.2.7 Unreleased.

### What was NOT changed

- Translated locale catalogs not regenerated — requires explicit approval to run the MT pipeline.
- 38 pre-existing interpolation mismatches in other files flagged by `--check-params` but not addressed (out of scope).

### Verification

- `check_l10n_keys.py`: all 1428 l10n keys resolve. Zero missing.
- `check_l10n_keys.py --check-params`: zero audit-namespace param mismatches.
- Code review (medium): no findings in changed files.
