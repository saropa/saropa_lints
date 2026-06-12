# BUG: `require_timezone_display` — fires on `.pattern`-only introspection and on seconds-only formats

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-11
Rule: `require_timezone_display`
File: `lib/src/rules/data/json_datetime_rules.dart` (line ~1594)
Severity: False positive
Rule version: v1 | Since: v4.14.0

---

## Summary

`require_timezone_display` is a pure syntactic heuristic: it fires on any
`DateFormat` whose format string contains a `[Hhms]` char (or whose named
constructor is in `_timeOnlyConstructors`) and lacks a `[zZvOxX]` char. It never
checks whether the formatter is actually used to display a value, nor whether the
matched component can carry cross-timezone ambiguity. This produces false
positives on two mechanically-provable classes of correct code, plus on
reusable clock-rendering library primitives where the caller — not the formatter —
owns the timezone-display decision.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'require_timezone_display'" lib/src/rules/
# lib/src/rules/data/json_datetime_rules.dart:1610:    'require_timezone_display',
```

**Emitter registration:** `lib/src/rules/data/json_datetime_rules.dart:1610`
**Rule class:** `RequireTimezoneDisplayRule` — `lib/src/rules/data/json_datetime_rules.dart:1594`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#1`

---

## Reproducer

```dart
import 'package:intl/intl.dart';

// CASE 1 — .pattern introspection, never .format()ed.
// The DateFormat is constructed only to read its pattern string for locale-hour
// detection. Nothing is ever displayed, so the rule's harm rationale ("users
// misinterpret a displayed time") cannot occur.
bool localeUses24Hour(String? locale) =>
    DateFormat.jm(locale).pattern?.contains('H') ?? false; // LINT — should be OK

// CASE 2 — seconds-only format.
// Timezone offsets are never finer than minutes (e.g. +05:30, +05:45, +12:45),
// so the seconds field is identical in every timezone. A timezone indicator on a
// seconds-only render is meaningless.
String renderSeconds(DateTime d, String? locale) =>
    DateFormat('ss', locale).format(d); // LINT — should be OK

// CASE 3 — reusable clock-rendering primitive in a utility library.
// The library's job is to produce a locale clock ("3:30 PM" / "15:30"); the
// timezone-display decision belongs to the caller's display context.
String clock(DateTime d, String? locale) =>
    DateFormat.jm(locale).format(d); // LINT — arguably OK in a formatter library
```

**Frequency:** Always (cases 1 and 2 are deterministic).

Real triggering source — `saropa_dart_utils`:
- `lib/datetime/date_time_intl_time_display_extensions.dart:25` — case 1 (`DateFormat.jm(locale).pattern?.contains('H')`)
- `lib/datetime/date_time_intl_display_render.dart:60` — case 2 (`DateFormat('ss', locale)`)
- `lib/datetime/date_time_intl_time_display_extensions.dart:55-59` — case 3 (`jms`/`jm`/`Hms`/`Hm`/`'h:mm'` rendered for display)

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic for cases 1 and 2 (provably cannot mislead); case 3 is a library-design boundary |
| **Actual** | `[require_timezone_display]` reported on every `DateFormat` with a `[Hhms]` char and no tz char |

---

## Root Cause

`runWithReporter` (lines 1649-1690) checks only the syntactic shape of the
`DateFormat` constructor:

```dart
if (_timePattern.hasMatch(formatString) &&        // _timePattern = RegExp(r'[Hhms]')
    !_timezonePattern.hasMatch(formatString)) {   // _timezonePattern = RegExp(r'[zZvOxX]')
  reporter.atNode(node);
}
```

and, for named constructors, fires whenever the name is in `_timeOnlyConstructors`
without consulting how the result is used.

### Case 1 — `.pattern` introspection (definitive defect)

The rule reports on the `InstanceCreationExpression` regardless of whether
`.format(...)` is ever invoked. When the `DateFormat`'s only consumer is
`.pattern` (a `String?` getter used here for locale-hour detection), no value is
ever rendered, so the diagnostic's premise is structurally impossible.

### Case 2 — seconds-only format (definitive defect)

`_timePattern` matches a lone `s`. But timezone offsets are always whole-minute
(or coarser); the seconds field is invariant across all zones. A format whose
*only* time component is `s` (no `H`/`h`/`m`) can never be misread across zones,
so requiring a timezone pattern is incorrect.

### Case 3 — rendering-primitive library (design boundary)

The heuristic targets app display code. In a reusable formatter library, the
formatter is the primitive and the caller owns the display context. This is the
weaker class — reasonable people can want the rule here — but it is worth a
documented carve-out (e.g. a config option or a `// formatter library` allowance).

---

## Suggested Fix

1. **Seconds-only (case 2):** require at least one of `H`, `h`, or `m` in the
   format string before reporting — change the gate so a format whose only
   time char is `s` does not match. The seconds field carries no cross-timezone
   ambiguity.

2. **`.pattern`-only use (case 1):** when the `DateFormat` instance's result
   flows only to the `.pattern` getter (and never to a `.format*` invocation),
   skip the report. A conservative version: if the `InstanceCreationExpression`'s
   immediate parent is a `PropertyAccess`/`PrefixedIdentifier` selecting
   `pattern`, do not report. This covers the common locale-hour-detection idiom
   without full data-flow analysis.

3. **Rendering-primitive (case 3):** consider a rule option to suppress inside
   files whose purpose is formatting (or document `// ignore_for_file` as the
   sanctioned escape). Lower priority than 1 and 2.

---

## Fixture Gap

The fixture at `example/lib/json_datetime/require_timezone_display_fixture.dart`
currently covers only: `DateFormat('yyyy-MM-dd HH:mm')`, `DateFormat.Hm()`,
`DateFormat('yyyy-MM-dd HH:mm z')`, `DateFormat('yyyy-MM-dd')`, `DateFormat.jmz()`.
It should add:

1. **`DateFormat.jm(locale).pattern`** read for introspection, never formatted — expect NO lint (case 1)
2. **`DateFormat('ss')`** seconds-only format — expect NO lint (case 2)
3. **`DateFormat('mm:ss')`** minute+second — expect LINT (minutes ARE timezone-variant; guards against over-correcting fix 1)
4. **`DateFormat('s')`** single seconds char — expect NO lint (case 2 boundary)

---

## Changes Made

Cases 1 and 2 (the two definitive defects) are fixed in
`lib/src/rules/data/json_datetime_rules.dart`. Case 3 (rendering-primitive
library boundary) is intentionally **not** addressed — it is the weak class the
report itself flags as "reasonable people can want the rule here," and the
sanctioned escape is `// ignore_for_file: require_timezone_display` in a
formatter library. No rule option was added to avoid scope creep.

**Case 2 — seconds-only formats.** Narrowed the time-component gate from
`RegExp(r'[Hhms]')` to `RegExp(r'[Hhm]')`. Seconds are timezone-invariant
(offsets are always whole-minute or coarser), so a format whose only time char
is `s` no longer matches. Formats containing hours or minutes — including
`mm:ss` — still match, because minutes ARE timezone-variant.

**Case 1 — `.pattern`-only introspection.** Added `_isPatternIntrospection`,
which returns `true` when the `DateFormat` instance's immediate parent is a
`PropertyAccess` selecting `pattern` (e.g. `DateFormat.jm(locale).pattern`).
`runWithReporter` early-returns before any report when this holds. A
conservative immediate-parent check covers the locale-hour-detection idiom
without full data-flow analysis.

### Verification note

This rule registers only `addInstanceCreationExpression`. The `scan` CLI parses
with unresolved `parseString`, under which `DateFormat(...)` parses as a
`MethodInvocation`, not an `InstanceCreationExpression` — so the rule emits
nothing under `scan` (confirmed: the sibling `require_intl_date_format_locale`,
which has a `MethodInvocation` fallback, fired on the same fixture while this
rule did not; see its comment at `internationalization_rules.dart:1370-1384`).
The rule fires normally in the resolved custom_lint/IDE environment, which is
where the bug was observed. The fix is therefore validated by construction plus
`dart analyze` (clean), and by the `expect_lint` fixture for the resolved path.

---

## Tests Added

`example/lib/json_datetime/require_timezone_display_fixture.dart` extended with:

1. `DateFormat.jm(locale).pattern?.contains('H')` — `.pattern` introspection,
   expect NO lint (case 1).
2. `DateFormat('ss', locale)` — seconds-only, expect NO lint (case 2).
3. `DateFormat('s')` — single seconds char, expect NO lint (case 2 boundary).
4. `DateFormat('mm:ss')` — minute+second, expect LINT (guards against
   over-correcting the seconds carve-out, since minutes are timezone-variant).

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: (consumed by saropa_dart_utils dev dependency)
- Dart SDK version: as configured in saropa_dart_utils
- custom_lint version: as configured in saropa_dart_utils
- Triggering project/file: `saropa_dart_utils` — `lib/datetime/date_time_intl_time_display_extensions.dart`, `lib/datetime/date_time_intl_display_render.dart`

---

## Finish Report (2026-06-11)

**Scope:** (A) Dart lint rule — `RequireTimezoneDisplayRule` in
`lib/src/rules/data/json_datetime_rules.dart`. No extension/TypeScript touched.

**Resolution.** Fixed the two definitive false-positive classes; case 3
(formatter-library boundary) intentionally left to `// ignore_for_file` as the
report recommends — no rule option added (scope creep on shared config).

- **Case 2 (seconds-only):** time-component gate narrowed `RegExp(r'[Hhms]')` →
  `RegExp(r'[Hhm]')`. Seconds are timezone-invariant (offsets are whole-minute
  or coarser), so `DateFormat('ss')` / `DateFormat('s')` no longer match;
  `mm:ss` and `HH:mm` still match. Fractional-second `S` was never in the set,
  so `DateFormat('ss.SSS')` is also correctly silent.
- **Case 1 (`.pattern` introspection):** added static `_isPatternIntrospection`
  — true when the instance's immediate parent is a `PropertyAccess` selecting
  `pattern`. `runWithReporter` early-returns before any report. Covers the
  `DateFormat.jm(locale).pattern` locale-hour-detection idiom without data-flow
  analysis.

**Deep review.** Nullable parent check (no deref/recursion/race); O(1) cost;
rule in correct file; `tiers.dart` unchanged (behavior fix, not a new rule);
`LintImpact` unchanged; quick fix omitted (the timezone token and insertion
point are not mechanically determinable). WHY-comments added at both sites.

**Tests.** `dart test test/rules/data/json_datetime_rules_test.dart` → 27/27
pass (instantiation + fixture-exists pins; none asserted the changed
message/regex, so none broke). Behavior is pinned by the extended `expect_lint`
fixture (4 cases). `dart analyze` on the rule file → clean.

**Verification limitation.** The rule registers only
`addInstanceCreationExpression`. The `scan` CLI parses unresolved
(`parseString`), under which `DateFormat(...)` is a `MethodInvocation`, not an
`InstanceCreationExpression` — so the rule emits nothing under `scan`
(confirmed: sibling `require_intl_date_format_locale`, which has a
`MethodInvocation` fallback, fired on the same fixture while this rule did not).
The rule fires in the resolved custom_lint/IDE path, where the bug was observed.
Adding a `MethodInvocation` fallback would make it scan-verifiable but expands
coverage beyond the reported symptom — not done without sign-off.

**Files:** `lib/src/rules/data/json_datetime_rules.dart`,
`example/lib/json_datetime/require_timezone_display_fixture.dart`,
`CHANGELOG.md`, this bug report (archived).

Finish report appended: this file.
Bug archived: `bugs/require_timezone_display_false_positive_rendering_primitive_and_pattern_introspection.md` → `plans/history/2026.06/2026.06.11/require_timezone_display_false_positive_rendering_primitive_and_pattern_introspection.md`
