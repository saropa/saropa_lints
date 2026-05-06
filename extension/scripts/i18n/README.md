# Extension i18n generator

Generates localized JSON files from English sources for:

- `extension/package.nls.<locale>.json`
- `extension/src/i18n/locales/<locale>.json`

## Usage

```bash
python scripts/i18n/generate_locales.py
```

Default locales:

- `nl, ur, fr, de, es, it, pt, ru, ja, ko, zh, ar, hi`

## Manifest migration

```bash
python scripts/i18n/migrate_manifest_nls.py
```

## Coverage audit

```bash
python scripts/i18n/audit_coverage.py
```

Writes:

- `extension/reports/i18n_coverage_report.md`

## Notes

- The script is modular: CLI, translation engine, phrase dictionaries, and file IO are separated.
- Placeholder tokens like `{target}` and markdown/command links are preserved.
- Unknown phrases fall back to English until a translation is added to `dictionaries.py`.
