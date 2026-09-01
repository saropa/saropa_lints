# l10n Checker Param Validation + usesTypeResolution Fixes

The `check_l10n_keys.py --check-params` flag reported 38 interpolation mismatches, all of which were false positives caused by three bugs in the checker's param extraction logic. Separately, 8 lint rules across 4 files incorrectly declared `usesTypeResolution => false` despite using `NamedType.element` for superclass resolution, causing those rules to silently skip their checks when run in the light analysis lane.

## Finish Report (2026-09-01)

### l10n Checker Fixes

Three bugs in `check_l10n_keys.py` caused all 38 reported param mismatches to be false positives:

1. **Trailing delimiter consumption** — `_OBJ_KEY_RE` consumed the trailing `,`/`}`/`:` of each match, preventing consecutive shorthand properties (`{ a, b, c }`) from all being found. Fixed by changing the trailing group to a lookahead `(?=:|[,}])`.

2. **Template-literal leakage** — `${suffix}` inside a template-literal param value was parsed as an object key `suffix`. Added `_sanitize_param_values()` to blank string/template-literal contents before key extraction.

3. **Plural key false alarms** — keys ending in `One`/`Other` contain `{count}` that is substituted by `pluralize()` in `webview-format.ts`, not by `l10n()`. The checker now skips param validation for plural-form keys.

Two additional keys (`codeHealth.table.detailHeading`, `findingsDash.script.bulkSelectedTpl`) are intentional template pass-throughs for client-side JS substitution, added to a `_PASSTHROUGH_KEYS` allowlist.

After fixes: `All 1428 l10n keys resolve against en.json. (params validated)` — zero mismatches.

### usesTypeResolution Fixes

The `usesTypeResolution` integrity test regex (`_resolvedTypePatterns`) did not catch bare `.element` access on `NamedType` nodes (only `.staticElement`, `.declaredElement`, etc.). Three stylistic rules plus 5 widget rules used `extendsClause.superclass.element?.name` for superclass identity resolution but declared `usesTypeResolution => false`, meaning they would get `null` from `.element` in the light analysis lane and silently skip their checks.

**Rules fixed (false → true):**
- `PreferOneWidgetPerFileRule` (stylistic_rules.dart)
- `PreferPrivateUnderscorePrefixRule` (stylistic_rules.dart)
- `PreferWidgetMethodsOverClassesRule` (stylistic_rules.dart)
- `PreferCachedPaintObjectsRule` (ui_ux_rules.dart)
- `RequireCustomPainterShouldRepaintRule` (ui_ux_rules.dart)
- `AvoidUnnecessarySetStateRule` (widget_lifecycle_rules.dart)
- `AvoidUnnecessaryStatefulWidgetsRule` (widget_lifecycle_rules.dart)
- `PreferKeyboardShortcutsRule` (widget_patterns_ux_rules.dart)

**Integrity test regex** extended with `|\.superclass\.element\b` to catch this pattern going forward.

**Broader issue documented:** 14 additional rule files use `.constructorName.type.element` (same API, different access path) without the flag. This is tracked in `bugs/type_element_resolution_gap.md` as a separate bulk fix.

### Verification

- `dart test test/integrity/uses_type_resolution_test.dart` — 2/2 pass
- `dart test test/integrity/rule_lane_test.dart` — 10/10 pass
- `check_l10n_keys.py --check-params` — 0 mismatches, 1428 keys validated
