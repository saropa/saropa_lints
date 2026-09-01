# Full Audit + Findings Dashboard — Missing i18n Strings

The Full Audit feature (`extension/src/audit/`) referenced 47 `audit.*` l10n keys with no corresponding entries in `extension/src/i18n/locales/en.json`. The scope picker, progress notification, error messages, and report webview all rendered raw key paths instead of readable text. Additionally, 3 `findingsDash.script.*` accessibility keys were missing, and the progress-bar message was hardcoded in English.

## Finish Report (2026-09-01)

### Changes

- **`extension/src/i18n/locales/en.json`** — Added 51 keys total across audit command guards, scope picker, progress, errors, report webview, and findingsDash accessibility announcements.

- **`extension/src/audit/audit-command.ts`** — Replaced hardcoded inline progress message with `l10n('audit.progress.message', { pct, scanned, total, issues, file })`.

- **`extension/scripts/check_l10n_keys.py`** — CI-ready script cross-references every `l10n()` call against `en.json`:
  - `--check-params` validates interpolation tokens match between call sites and catalog values.
  - Template-literal-aware comment stripping (handles `${}` interpolations containing `//` or `/*`).
  - Balanced-brace param extraction handles JS shorthand properties (`{ message }`), nested parentheses (`String(totalCount)`), and spread exclusion (`...obj`).
  - Dynamic-key-prefix filtering (trailing-dot keys like `codeHealth.flag.` + var).

- **`extension/src/i18n/l10nDiagnostics.ts`** — New VS Code diagnostic provider (`saropa-l10n` collection):
  - Scans TypeScript files under `extension/src/` for `l10n()` calls on save and open.
  - Reports missing `en.json` keys as warnings (yellow squiggles at the key string).
  - Reports interpolation param mismatches (missing params) as warnings.
  - Caches the flattened catalog; invalidates and re-validates all open files when `en.json` changes via FileSystemWatcher.
  - Registered at extension activation via `extension.ts`.

- **`CHANGELOG.md`** — Maintenance entries under 15.2.7 Unreleased.

### What was NOT changed

- Translated locale catalogs not regenerated — requires explicit approval to run the MT pipeline.
- 38 pre-existing interpolation mismatches in other files not addressed (out of scope).

### Verification

- `check_l10n_keys.py`: all 1428 l10n keys resolve. Zero missing.
- `check_l10n_keys.py --check-params`: zero audit-namespace param mismatches; 38 pre-existing in other files.
- Code review: no findings in changed files.
