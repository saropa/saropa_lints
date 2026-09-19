# BUG: `check_l10n_keys.py` — reports 389 "defined but never referenced" keys, most likely dynamic families

**Status: Open**

Created: 2026-09-19
Rule: n/a (infrastructure — `extension/scripts/check_l10n_keys.py`)
File: `extension/scripts/check_l10n_keys.py` (dead-key report, ~line 467)
Severity: False positive (warning noise) / risk of wrongly deleting live keys
Rule version: n/a

---

## Summary

`python3 extension/scripts/check_l10n_keys.py` exits 0 but warns that 389 keys in `en.json` are "defined but never referenced in code". Many of these are almost certainly used through string-built or table-driven references the script cannot see, so the warning cannot be trusted and nobody should delete keys from it. Nobody has yet classified the 389 into truly dead vs. dynamically used.

---

## Attribution Evidence

The script lives in this repo: `extension/scripts/check_l10n_keys.py`. It only matches literal `l10n('dotted.key')` calls (single or double quotes). Template-literal keys such as ``l10n(`prefix.${var}`)`` are documented in the script as dynamic and skipped. The only mechanism for dynamic keys is a type alias named `*Key` that is a union of dotted string literals.

---

## Reproducer

```text
python3 extension/scripts/check_l10n_keys.py
...
⚠ 389 key(s) defined in en.json but never referenced in code:
✓ All 1775 l10n keys resolve against en.json.
```

Largest prefix groups in the unreferenced list (count, prefix):

| Count | Prefix |
|---|---|
| 43 | `packageDashboard.toolbar` |
| 38 | `packageDashboard.columns` |
| 24 | `codeHealth.flag` |
| 20 | `projectMap.reports` |
| 13 | `debug.engine` |
| 12 | `stylistic.desc` |
| 12 | `commandCatalog.script` |
| 10 | `packageDashboard.tabs` |
| 10 | `findingsDash.script` |
| 9 | `packs.domainDesc` |
| 8 | `packageDashboard.settingsTab` |
| 7 each | `statusBar.menu`, `commandCatalog.search` |
| 6 each | `packageDashboard.links`, `memoryPressure.tooltip` |

Also seen: `toolbar.*`, `empty.*`, `loading.*`, `packageDetail.version.blockedVia*`, `systemHealth.tooltip.*`.

---

## Expected vs Actual

- **Expected:** the report lists only keys with no reference anywhere (literal, template, key-union, or webview-script table), so it is safe to act on.
- **Actual:** keys reached via webview script string tables, per-column/per-flag lookups built from an id, or keys passed as data (e.g. `stylistic.desc.<category>`) are reported as unreferenced.

---

## Root Cause

### Hypothesis A: string-built keys

Keys like `stylistic.desc.<category>` and `packs.domainDesc.<domain>` are likely composed at runtime from an id, which the literal-only regex cannot match.

### Hypothesis B: keys referenced inside webview script tables

`findingsDash.script.*`, `commandCatalog.script.*` and `codeHealth.script.*` are probably embedded in HTML/JS strings or maps rather than `l10n('...')` calls, so they are invisible to the scan.

### Hypothesis C: some are genuinely dead

After the first two are ruled out, a remainder may be truly unused (e.g. old toolbar or column keys left after a dashboard consolidation).

---

## Suggested Fix

1. Classify all 389: for each prefix group, grep `extension/src/` for the prefix string (`'packageDashboard.columns.'`, `` `packageDashboard.columns.${ ``, the bare last segment) to decide dynamic vs dead.
2. For dynamic families, add a documented prefix allowlist (or `*Key` union types at the call sites) so the checker counts them as used.
3. Delete only the confirmed-dead keys from `en.json` and all locale files.
4. Optionally make the dead-key report a count-per-prefix summary, and fail CI only on newly added unreferenced keys.

---

## Fixture Gap

No tests exist for `check_l10n_keys.py`. Add a small fixture tree covering literal, template-literal, `*Key` union, and prefix-allowlisted references, plus a truly dead key.

---

## Environment

- Script: `extension/scripts/check_l10n_keys.py`
- Full list: run the script; output is the source of truth (389 keys at time of filing)
