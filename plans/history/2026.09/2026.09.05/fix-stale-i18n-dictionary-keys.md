# Fix stale i18n dictionary keys, missing translations, and analyzer lint

The `generate_translations.py` script warned about 2 curated dictionary keys in
`extension/scripts/i18n/dictionaries.py` that no longer matched any English source
string, plus 48 missing translations across 21 locales where MT returned English
unchanged. Additionally, 8 pre-existing analyzer lint issues were blocking all git
commits via the pre-commit hook.

## Changes

### Stale key fixes

**`de`** — removed stale entry. The English key for the scan-on-save description
was rewritten in `package.nls.json` (daemon label, LSP/plugin separation, Engines
row reference). The curated German translation no longer matched the new semantics.

**`fil`** — removed "Analyzer Plugin" passthrough. The string does not exist as a
standalone source value — only in longer phrases like "Analyzer Plugin: enabling…".

**`ur`** — fixed curly apostrophe (U+2019) in the scan-on-save key to match the
source string's straight apostrophe (U+0027) in "sidebar's".

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
- `pl`: gate-failing status with grade/score prefix (matched existing "Brama nie
  działa" pattern).
- `pt`: gate-failing status, gate-passing tooltip, scan timestamp.
- `ru`: gate-failing tooltip with violation count (pluralization caveat documented).
- `sw`: gate-failing label, hotspot review progress, scan timestamp.
- `tr`: scan timestamp.
- `uk`: Code Health prompt.
- `ur`: full scan-on-save setting description (preserves **bold** and `backtick`
  formatting).

### DO_NOT_TRANSLATE collision lint

Added `_check_dnt_collisions()` to `generate_locales.py`. Warns when a
`DO_NOT_TRANSLATE` keyword appears as a substring of a longer source string.
Skips two known-safe patterns: prefix matches (format-string extensions) and
short keywords (≤15 chars) inside much longer prose (≥5× length).

### Analyzer lint fixes (8 issues across 7 files)

Pre-existing lint issues blocking the pre-commit hook:
- `structure_rules.dart`: removed unused `fileSource` variable.
- `avoid_disposing_late_fields_rules.dart`: added curly braces to single-line `if`.
- `saropa_lint_rule.dart`: added curly braces to single-line `if`.
- `getters_in_member_list_rules.dart`, `initializers_ordering_rules.dart`,
  `avoid_equals_and_hash_code_on_mutable_classes_extended_rules.dart`,
  `debug_rules.dart`: removed unnecessary `analyzer_compat.dart` imports
  (already re-exported by `saropa_lint_rule.dart`).
- `scan_runner.dart`: removed unnecessary `rule_lane.dart` import (already
  re-exported by `saropa_lints.dart`).

## Finish Report (2026-09-05)

Two curated dictionary entries in `dictionaries.py` became stale after the English
source strings they keyed against were rewritten or re-capitalized. The `de` entry
for the scan-on-save description was removed because the English text changed
substantially and the old German no longer applied. The `fil` "Analyzer Plugin"
passthrough was removed because it matched no standalone source string. The `ur`
scan-on-save key had a curly apostrophe that silently diverged from the source.

48 missing translations across 21 locales were patched. Four high-frequency
format/loanword strings were added to `DO_NOT_TRANSLATE` to cover 33 gaps. The
remaining 15 locale-specific entries were hand-translated and added as curated
dictionary entries with comments explaining each. A `_check_dnt_collisions()` lint
was added to `generate_locales.py` to catch future keyword-in-prose collisions,
with heuristic suppression for known-safe patterns (prefix matches, short keywords
in long prose).

Eight pre-existing analyzer lint issues across 7 Dart files were fixed to unblock
the pre-commit hook: 1 unused variable, 2 missing curly braces, 5 unnecessary
imports. All purely syntactic — no behavioral change.

### Hardening (reflection gate)

Added a guard comment to the `DO_NOT_TRANSLATE` list in `dictionaries.py` warning
future editors that common English words risk silent passthrough in locales that
translate those words. The collision heuristic thresholds (5× ratio, 15-char
keyword cap) were validated against actual data — the smallest real ratio is 37.8×,
so the 5× threshold is conservative with wide margin.

### `--strict-dnt` flag (reflection gate — unrequested feature)

Added `--strict-dnt` CLI flag to `generate_locales.py`. When passed, any
`DO_NOT_TRANSLATE` collision warnings become fatal errors (exit 1). Intended for
CI pipelines alongside `--fail-on-missing` and `--fail-on-drift` to prevent
publishes when a passthrough keyword is embedded in a longer translatable string.
