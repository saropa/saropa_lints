# Extension i18n generator

Generates localized JSON files from English sources for:

- `extension/package.nls.<locale>.json`
- `extension/src/i18n/locales/<locale>.json`

## Usage

From the repository root:

```bash
python extension/scripts/i18n/generate_locales.py
```

**Full runtime + manifest locale fill (machine translation):** install the optional
dependency, opt in with the environment variable, then run the same script:

```bash
pip install -r extension/scripts/i18n/requirements.txt
# Windows PowerShell:
$env:SAROPA_I18N_MACHINE_TRANSLATE = "1"; python extension/scripts/i18n/generate_locales.py
# bash:
SAROPA_I18N_MACHINE_TRANSLATE=1 python extension/scripts/i18n/generate_locales.py
```

Curated entries in `dictionaries.py` still win when present; everything else is
translated via Google (through `deep-translator`) and cached under
`extension/scripts/i18n/.cache/` (gitignored). Ship the generated
`package.nls.<locale>.json` and `src/i18n/locales/<locale>.json` in git so CI
does not need network.

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
- Unknown phrases use **machine translation** when `SAROPA_I18N_MACHINE_TRANSLATE=1` and
  `deep-translator` is installed; otherwise they stay English until you add a
  dictionary entry or run with MT enabled.
- **Curated overrides:** add high-value phrases to `dictionaries.py` so they beat MT
  (product names, tone, or strings MT mishandles).

## Product note (UI language setting)

- **`saropaLints.uiLanguage`** is written to **User** settings from the sidebar picker so saves succeed reliably on all hosts and **the same language applies in every workspace** (product default; confirmed maintainer intent).
- **Per-workspace** UI language is **not** implemented; adding it would require a new product decision and a safe workspace-write path (workspace saves previously failed for some hosts with “not a registered configuration”).
