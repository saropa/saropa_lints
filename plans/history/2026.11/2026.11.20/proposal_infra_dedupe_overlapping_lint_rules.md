# PROPOSAL: Dedupe overlapping rules that double-report the same line

**Status: Open**

Created: 2026-11-20
Type: Infrastructure
Related rules: `avoid_positional_boolean_parameters_with_fix`, `prefer_named_boolean_parameters`, `avoid_complex_conditions`, `avoid_excessive_expressions`, `avoid_duplicate_string_literals`, `avoid_duplicate_string_literals_pair`, `avoid_adjacent_strings`, `avoid_very_long_files`, `avoid_long_files`, `avoid_medium_length_files`

---

## Summary

Several rule groups report the same line or declaration with near-identical intent, multiplying the diagnostic count and the number of `// ignore:` lines a project needs. Consolidate each group so one finding is reported per cause.

---

## Motivation

In `saropa_drift_advisor/lib/src/server/router.dart` (review of `bugs/lints.json`, 179 entries), the same parameters or lines are flagged by multiple rules:

- `_routePreQuery(..., bool authenticated)`, `setChangeDetectionEnabled(bool)`, `setMonitoringEnabled(bool)` — flagged by both `avoid_positional_boolean_parameters_with_fix` and `prefer_named_boolean_parameters` (3 + 3).
- Two conditions (router.dart ~L343, ~L1239) — flagged by both `avoid_complex_conditions` and `avoid_excessive_expressions` (2 + 2).
- One repeated message literal — flagged by `avoid_duplicate_string_literals` (2), `_pair` (4), and `avoid_adjacent_strings` (3), plus `no_magic_string` (3).
- One 1,600-line file — flagged by three cumulative length thresholds (`avoid_very_long_files`, `avoid_long_files`, `avoid_medium_length_files`) plus `limit_max_imports`.

Rule names are as they appear in the export; positive grep for each was not repeated here — verify registration before implementing.

---

## Detection / Behavior

For each group, report once (the strictest applicable threshold) and let the others stay silent for the same node/line, or merge the rules and expose thresholds as options.

### Should flag (bad code)

```dart
void setEnabled(bool value) {} // LINT — one diagnostic, not two
```

### Should pass (good code)

```dart
void setEnabled({required bool value}) {} // OK
```

---

## Proposed Tier

Tier: n/a (affects existing rules in whatever tiers they occupy)
Justification: noise reduction; no new detection.

---

## Edge Cases

1. **Rules in different tiers** — a user enabling only the lower-tier rule must still get the diagnostic; suppress the duplicate only when the stricter rule is also enabled.
2. **Cumulative file-length thresholds** — report only the highest threshold crossed.

---

## Alternatives Considered

- Leave overlap and document `// ignore_for_file:` combos — rejected: increases ignore noise.

---

## Decision

Open.


---

## Findings (code verification, 2026-11-20)

Verified against `lib/` only. No rule, tier, or registration changed.

### Verified overlaps

1. **Positional bool pair: full duplicate.** `AvoidPositionalBooleanParametersRule` (code `avoid_positional_boolean_parameters_with_fix`, `lib/src/rules/code_quality/code_quality_avoid_rules.dart:4822-4888`) and `PreferNamedBooleanParametersRule` (`lib/src/rules/architecture/structure_rules.dart:1734-1795`) both visit `addFormalParameterList`, skip closures, report every positional `bool` `RegularFormalParameter` via `reporter.atNode(param)`. Same node, same line. Differences: the `_with_fix` rule also skips operators, setters, `@override` methods, function-typed suffix parents, and ships `ConvertToNamedBoolParamFix`; the `prefer_` rule has none of these exemptions and no fix. Both are in the professional tier (`lib/src/tiers.dart:1843`, `:2728`). The `_with_fix` rule is the stricter-exempt, fixable one; `prefer_` is a strict superset of its reports.
2. **Complex conditions vs excessive expressions: partial overlap only.** `avoid_complex_conditions` (`complexity_rules.dart:379-450`) fires on `if`/`while`/ternary conditions with more than 3 `&&`/`||`. `avoid_excessive_expressions` (`complexity_rules.dart:550-688`) fires on a top-level `BinaryExpression` with more than 5 binary operators of any kind (`_countOperators` at `:678` counts all binaries), with guard-clause (<=10) and symmetric-pattern exemptions. They coincide only for conditions with >5 operators that are not exempt. Both professional (`tiers.dart:2115`, `:2489`). Different scopes: excessive also fires outside conditions (e.g. assignments, returns), complex does not.
3. **Duplicate string literals vs `_pair`: full superset.** Bodies are identical copies (`code_quality_avoid_rules.dart:3912-4022` vs `:4057-4156`); only `_minOccurrences` differs (3 vs 2). Any literal reported by the base rule is also reported by `_pair`. Both are in the professional tier (`tiers.dart:2187`, `:2486`).
4. **File length: cumulative thresholds, nested.** Thresholds 300 / 500 / 1000 code lines, all calling `_checkFileLength` (`structure_rules.dart:700-719`), each reporting at the file's first token. A 1,600-line file triggers all three. Tiers: medium (`:2103`) professional; long (`:2514`) professional; very-long (`:1125`) recommended.

### False or inaccurate claims

- **Rule names for file length are wrong.** Registered codes are `avoid_long_length_files` (`structure_rules.dart:939`) and `avoid_very_long_length_files` (`:998`), not `avoid_long_files` / `avoid_very_long_files`. Classes are `AvoidLongFilesRule` / `AvoidVeryLongFilesRule`. `avoid_medium_length_files` is correct (class `AvoidMediumFilesRule`). Doc comments at `:915` and `:974` also quote stale names.
- **`avoid_adjacent_strings` is not a duplicate-string overlap.** It fires on any `AdjacentStrings` node (`code_quality_avoid_rules.dart:83-85`), a different cause (implicit concatenation). It flags a line only coincidentally when that line has both. Not a dedupe candidate; also in professional (`tiers.dart:2467`).
- **`no_magic_string`** exists (`lib/src/rules/data/numeric_literal_rules.dart:375`, `tiers.dart:2602`) but was not compared; unverified.
- **`limit_max_imports`** exists (`tiers.dart:2590`); it counts imports, a different cause than file length. Not an overlap in detection; unverified beyond registration.
- **"Rules in different tiers" edge case is mostly moot.** All pairs above are in the same tier except very-long (recommended) vs medium/long (professional).
- **Pair-rule doc is wrong.** `AvoidDuplicateStringLiteralsPairRule` DartDoc says "Comprehensive tier" (`code_quality_avoid_rules.dart:4029`); it is in `professionalOnlyRules`.
- **Misplaced DartDoc.** The "Prefer named boolean parameters... use one or the other" comment sits above `BannedUsageRule` (`code_quality_avoid_rules.dart:4890-4895`), evidence the two bool rules were already known duplicates.

### Recommended ONE action

Remove `prefer_named_boolean_parameters` as a duplicate of `avoid_positional_boolean_parameters_with_fix` (identical visitor and report node; the survivor has the fix and the saner exemptions). Needs user approval: it requires deprecation/alias handling, removal from `structure_rules.dart`, `tiers.dart`, `rule_pack_codes_generated.dart`, `rule_pack_migration_codes.dart`, `rule_category_map.dart`, fixtures, and tests. Remaining groups (string pair, length thresholds, complex/excessive) are deliberate tiered variants; defer.

**Status: findings appended; awaiting user approval. Nothing implemented.**
