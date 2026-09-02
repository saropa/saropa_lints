# Cost-Aware Rule Shedding

The memory pressure shedding system shed rules by severity only (INFO first, then WARNING), ignoring rule cost. Type-resolving rules — the dominant memory consumers with 1,668 `.staticType`/`.element` references across 67 files — survived shedding while cheap syntactic rules were dropped. This produced 6.3 GB RSS even with 1,270 rules shed.

## Finish Report (2026-09-01)

### Root cause

`_rebuildShedRuleNames` used a 2-level severity-only scheme: level 1 shed INFO-severity rules, level 2 added WARNING-severity. `RuleCost` and `usesTypeResolution` metadata existed on every rule but were not consulted during shedding decisions.

### Fix

Restructured to 3-level cost-aware shedding:
- **Level 1** (soft limit): shed expensive rules — `usesTypeResolution == true` OR `RuleCost.high`/`.extreme` — regardless of INFO/WARNING severity.
- **Level 2** (escalation-1): add remaining INFO-severity rules.
- **Level 3** (escalation-2): add remaining WARNING-severity rules.
- ERROR-severity and essential-tier rules remain permanently protected.

Escalation boundaries now split the soft→hard RSS range into thirds instead of halves. A `maxShedLevel` constant is the single source of truth for the 3-level cap.

### Changes

- `lib/src/project_context_throttle_memory.dart` — added `registerRuleCosts()`, `_typeResolvingRules`, `_highCostRules` sets, `maxShedLevel` constant. Rewrote `_rebuildShedRuleNames` with cost-aware logic and level-3 short-circuit optimization. Rewrote `_refreshEscalation` for 3 escalation boundaries.
- `lib/saropa_lints.dart` — merged the severity/cost metadata loop into the registration loop (single pass). Disabled rules no longer registered into shedding metadata.
- `extension/src/systemHealth/memoryPressureWatcher.ts` — added level-3 status bar (`shedCritical`) and tooltip (`shedLevel3`) handling. Updated JSDoc for 3-level scheme.
- `extension/src/i18n/locales/en.json` — new keys `shedCritical`, `shedLevel3`; updated `shedInfo`, `shedLevel1`, `shedLevel2` text.
- `test/report/memory_pressure_shedding_test.dart` — rewritten with cost-aware test group: 15 tests covering all 3 levels, essential protection with cost, ERROR immunity, clamp, edge cases. All pass.
- `CHANGELOG.md` — new `[15.2.8] — Unreleased` section.

### Architecture finding

Investigation confirmed saropa_lints already runs as a native analyzer plugin (not custom_lint). The 6.3 GB RSS is a scale problem (2,300+ rules, 67 with type resolution), not an architecture problem. Cost-aware shedding is the correct mitigation — shedding expensive rules first gives the largest RSS reduction per rule dropped.

### Verification

- `dart analyze --fatal-infos` on changed files: clean
- `dart format --set-exit-if-changed`: clean
- `dart test test/report/memory_pressure_shedding_test.dart`: 15/15 pass
- Adjacent memory tests (`memory_pressure_periodic_log_test.dart`, `memory_eviction_test.dart`): 19/19 pass
- `npx tsc --noEmit` (extension): clean

### Open items

- Locale catalog regeneration needed for 25 non-English locales (new/updated en.json keys). Blocked on explicit user "run it" per MT pipeline rule.
- Manual VS Code test pending (trigger soft-threshold, verify 3-level status bar/tooltip progression).
