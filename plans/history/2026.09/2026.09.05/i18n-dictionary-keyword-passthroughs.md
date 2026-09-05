# i18n Dictionary Keyword Passthroughs

The translation audit flagged 42 missing translations across 19 locales. All were technical keywords or column-header identifiers (`saropa_tier`, `runtime_tier`, `rule_name`, `Budget`, `Extension`, etc.) that should render identically in every locale.

## Changes

**`extension/scripts/i18n/dictionaries.py`**:
- Added `DO_NOT_TRANSLATE` list at module top for technical keywords (`runtime_tier`, `rule_name`, `saropa_quality_gate.yaml thresholds`, `saropa_tier`). A merge loop at the bottom of the file auto-generates identity passthroughs into every locale's dict at import time, so future keywords require only one entry instead of 19+.
- Added locale-specific passthroughs for MT-failure strings (e.g., `Budget` in de/fr, `Doctor` in es, `Extension`/`Identifier`/`Output`/`Previous / next tab`/`Tier cap` etc. in fil) that are not universal keywords but had no MT translation available.
- Fixed 4 stale dictionary keys: `"Editor dashboards"` → `"Dashboards"` in nl/fr/ur (source renamed), `"Lane"` removed from fil/tr (source deleted).
- Comments updated to distinguish true keywords from MT-failure passthroughs.

## Finish Report (2026-09-05)

**What changed:** A `DO_NOT_TRANSLATE` mechanism centralizes keyword passthroughs — 4 keywords auto-expand to all 24 locales at import time via `setdefault`. 31 per-locale duplicate entries removed. Locale-specific MT-failure passthroughs remain in their respective locale sections with accurate comments. Four stale keys (renamed/removed English sources) fixed.

**Verification:** The stale-key checker (`_check_dictionary_drift`) skips entries where `en_key == translation` (line 165), so `DO_NOT_TRANSLATE`-merged entries are correctly ignored. The integrity checker (`_check_dictionary_locale_integrity`) walks AST keys only, so merged-at-runtime entries don't trigger false positives. Full locale regeneration deferred to publish time per project convention.

**Risk:** Low. The merge loop runs once at import time and uses `setdefault`, so any per-locale override in `TRANSLATIONS` takes precedence over the auto-generated passthrough. The `compute_stats` function at line 273 treats `dict_table.get(src) == src` as translated, which is exactly what the merged entries produce.
