# Full Audit + Findings Dashboard — Missing i18n Strings

The Full Audit feature (`extension/src/audit/`) referenced 47 `audit.*` l10n keys with no corresponding entries in `extension/src/i18n/locales/en.json`. The scope picker, progress notification, error messages, and report webview all rendered raw key paths instead of readable text. Additionally, 3 `findingsDash.script.*` accessibility keys were missing.

## Finish Report (2026-09-01)

### Changes

- **`extension/src/i18n/locales/en.json`** — Added 50 keys total:
  - `audit.alreadyRunning`, `audit.noProject`, `audit.missingDep` (command guards)
  - `audit.scope.*` (10 keys: scope picker labels, descriptions, placeholder, branch prompt)
  - `audit.progress.title` (notification title)
  - `audit.error.*` (3 keys: spawn failure, invalid project, parse failure)
  - `audit.report.*` (27 keys: report webview title, heading, subtitle, baseline tag, search, filters, chips, buttons, table columns, empty states, keyboard hint)
  - `findingsDash.script.announceSearchVerb`, `.severitiesNoun`, `.impactsNoun` (accessibility announcements)

- **`extension/scripts/check_l10n_keys.py`** — New CI-ready script that cross-references every `l10n()` call in `extension/src/**/*.ts` against `en.json`. Exits 1 when keys are used in code but absent from the catalog. Warns (exit 0) on keys defined but unreferenced. Skips comment lines to avoid doc-example false positives. Forces UTF-8 output on Windows.

- **`CHANGELOG.md`** — Two maintenance entries under 15.2.7 Unreleased.

### What was NOT changed

- No TypeScript code modified — all `l10n()` call sites were already correct; only the catalog was missing.
- Translated locale catalogs not regenerated — requires explicit approval to run the MT pipeline.

### Verification

- `check_l10n_keys.py`: all 1423 l10n keys resolve. Zero missing.
- Code review (medium): no findings.
- No test files reference audit or findingsDash script keys; no assertions broken.
