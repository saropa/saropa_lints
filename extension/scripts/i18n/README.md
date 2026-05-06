# Extension i18n generator

Generates localized JSON files from English sources for:

- `extension/package.nls.<locale>.json`
- `extension/src/i18n/locales/<locale>.json`

## Usage

From the repository root:

```bash
python extension/scripts/i18n/generate_locales.py
```

Or from ``extension/scripts/i18n`` (imports resolve):

```bash
python generate_locales.py
```

Default locales:

- `nl, ur, fr, de, es, it, pt, ru, ja, ko, zh, ar, hi`

## Manifest migration

```bash
python extension/scripts/i18n/migrate_manifest_nls.py
```

## Coverage audit

```bash
python extension/scripts/i18n/audit_coverage.py
```

Writes:

- `extension/reports/i18n_coverage_report.md`

## Notes

- The script is modular: CLI, translation engine, phrase dictionaries, and file IO are separated.
- Placeholder tokens like `{target}` and markdown/command links are preserved.
- Unknown phrases fall back to English until a translation is added to `dictionaries.py`.
- **New runtime keys:** add the English string under `extension/src/i18n/locales/en.json`, then add the same English string as a **dictionary key** in `dictionaries.py` for each locale you ship (value = translation). Running `generate_locales.py` overwrites non-`en` locale files from `en.json` via those tables, so skipping `dictionaries.py` would drop non-English lines on the next regen.

## Product note (UI language setting)

- **`saropaLints.uiLanguage`** is written to **User** settings from the sidebar picker so saves succeed reliably on all hosts and **the same language applies in every workspace** (product default; confirmed maintainer intent).
- **Per-workspace** UI language is **not** implemented; adding it would require a new product decision and a safe workspace-write path (workspace saves previously failed for some hosts with “not a registered configuration”).
