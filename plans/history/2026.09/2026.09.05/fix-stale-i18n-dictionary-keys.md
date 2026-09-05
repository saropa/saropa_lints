# Fix stale i18n dictionary keys and missing translations

The `generate_translations.py` script warned about 2 curated dictionary keys in
`extension/scripts/i18n/dictionaries.py` that no longer matched any English source
string, plus 48 missing translations across 21 locales where MT returned English
unchanged.

## Changes

### Stale key fixes

**`de`** — removed stale entry. The English key for the scan-on-save description
was rewritten in `package.nls.json` (daemon label, LSP/plugin separation, Engines
row reference). The curated German translation no longer matched the new semantics.

**`fil`** — capitalization fix. "Analyzer plugin" → "Analyzer Plugin" to match
the current source strings.

### Missing translation patches (48 entries, 21 locales)

**Cross-locale passthroughs** (added to `DO_NOT_TRANSLATE`):
- `{grade} · {score}/100` — 21 locales. Format-only (placeholders + punctuation).
- `Web` — 6 locales. Universal loanword.
- `Mobile` — 4 locales. Universal loanword.
- `Migration` — 2 locales. Cognate in de/fr.

**Per-locale curated entries** (15 entries, 10 locales):
- `de`: "Gate passing", log-panel empty-state message.
- `fil`: gate-failing status with grade/score prefix.
- `it`: gate-failing status with grade/score prefix.
- `pl`: gate-failing status with grade/score prefix.
- `pt`: gate-failing status, gate-passing tooltip, scan timestamp.
- `ru`: gate-failing tooltip with violation count.
- `sw`: gate-failing label, hotspot review progress, scan timestamp.
- `tr`: scan timestamp.
- `uk`: Code Health prompt.
- `ur`: full scan-on-save setting description (preserves **bold** and `backtick`
  formatting).

## Finish Report (2026-09-05)

Two curated dictionary entries in `dictionaries.py` became stale after the English
source strings they keyed against were rewritten or re-capitalized. The `de` entry
for the scan-on-save description was removed because the English text changed
substantially and the old German no longer applied. The `fil` "Analyzer plugin"
key was capitalized to match current source strings.

Additionally, 48 missing translations across 21 locales were patched. Four
high-frequency format/loanword strings (`{grade} · {score}/100`, `Web`, `Mobile`,
`Migration`) were added to `DO_NOT_TRANSLATE` to cover 33 gaps. The remaining 15
locale-specific entries were hand-translated and added as curated dictionary entries
with comments explaining each.
