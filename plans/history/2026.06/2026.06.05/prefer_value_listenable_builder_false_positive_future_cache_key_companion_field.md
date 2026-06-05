# BUG: `prefer_value_listenable_builder` — fires when a non-Future cache-key companion field accompanies cached `Future` fields

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-05
Rule: `prefer_value_listenable_builder`
File: `lib/src/rules/core/performance_rules.dart` (line ~1434)
Severity: False positive / High (forces `// ignore:` on the FutureBuilder cache idiom)
Rule version: v4 | Since: unknown | Updated: unknown

---

## Summary

The rule's async-builder-cache exemption (added for the `FutureBuilder` /
`StreamBuilder` invalidate-and-re-fetch idiom) only skips fields whose declared
type is `Future` / `Stream`. A State that backs a `FutureBuilder` with a cache
commonly also holds a **plain companion field that is the cache key** (e.g.
`List<String>? _lastContactUUIDs;` paired with `Future<...>? _contactsFuture;`).
That companion is non-`Future`, so it is counted as `stateFieldCount == 1`, and
the single `setState(_reinitFutures)` that re-runs the fetch counts as
`setStateCallCount == 1` — tripping the rule. `ValueListenableBuilder` cannot
express "re-run an async fetch", so the suggestion is a false positive, the same
family the rule already documents for the Future field itself.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'prefer_value_listenable_builder'" lib/src/rules/
# lib/src/rules/core/performance_rules.dart:1451:    'prefer_value_listenable_builder',

# Negative — rule is NOT in sibling repos
grep -rn "'prefer_value_listenable_builder'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/src/rules/core/performance_rules.dart:1451`
**Rule class:** `PreferValueListenableBuilderRule` — registered in `lib/saropa_lints.dart:1270`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#4`

---

## Reproducer

Minimal Dart code that triggers the bug.

```dart
class _CacheBackedFutureBuilderState extends State<CacheBackedWidget> {
  // The cached async idiom: a primary future + a cached secondary future.
  late Future<List<int>?> _primaryFuture;        // skipped (Future-typed)
  Future<List<String>?>? _secondaryFuture;       // skipped (Future-typed)

  // The CACHE KEY for _secondaryFuture. Non-Future-typed, so the rule's
  // async-cache exemption does NOT skip it → counted as the single state field.
  List<int>? _lastKeys;                          // counted as stateFieldCount = 1

  void _initFutures() {
    _primaryFuture = fetchPrimary();
    _secondaryFuture = null;
    _lastKeys = null;
  }

  // Recreates the futures on demand; `_lastKeys` is the invalidation key, not a
  // synchronous display value. This is the only setState → setStateCallCount = 1.
  void refresh() {
    if (mounted) {
      setState(_initFutures); // counted
    }
  }

  Future<List<String>?> _cachedSecondary(List<int>? keys) {
    final bool changed = _secondaryFuture == null || keys?.length != _lastKeys?.length;
    if (changed) {
      _lastKeys = keys;                          // mutated OUTSIDE setState
      _secondaryFuture = fetchSecondary(keys);
    }
    return _secondaryFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>?>(
      future: _primaryFuture,
      builder: (_, _) => const SizedBox(),
    ); // LINT fires on the State class name — but should NOT (false positive)
  }
}
```

**Frequency:** Always, when a `FutureBuilder` cache uses a non-`Future` key field and exactly one `setState`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the lone non-Future field is a cache key for the Future idiom; `ValueListenableBuilder` cannot re-run an async fetch |
| **Actual** | `[prefer_value_listenable_builder]` reported on the State class name token |

---

## AST Context

```
ClassDeclaration (_CacheBackedFutureBuilderState)   ← node reported here (nameToken)
  ├─ FieldDeclaration  late Future<List<int>?> _primaryFuture   (skipped: Future)
  ├─ FieldDeclaration  Future<List<String>?>? _secondaryFuture  (skipped: Future)
  ├─ FieldDeclaration  List<int>? _lastKeys                     (COUNTED: stateFieldCount++)
  └─ MethodDeclaration refresh → setState(_initFutures)         (COUNTED: setStateCallCount++)
```

---

## Root Cause

`_isAsyncBuilderCacheType` (`performance_rules.dart:1543`) only matches type
names `Future` / `Stream`. The cache-key companion field that travels with the
cached future (declared `List<...>?`, `String?`, `int?`, etc.) is not a `Future`,
so the `continue` at line 1504 does not fire and it is counted at line 1506.
With `stateFieldCount == 1` and the single invalidate-and-re-fetch `setState`
giving `setStateCallCount == 1`, the gate at lines 1530-1532 passes and the rule
reports.

The mechanism is the same one the rule already exempts for the Future field
itself (see the comment at lines 1496-1502): a setState that re-runs an async
fetch is not a single-value publish. The exemption simply does not reach the
companion key field.

### Hypothesis A: detect the companion-key pattern

When ALL of the following hold, suppress: (a) the State has ≥1 `Future`/`Stream`
field, (b) the only counted non-Future field(s) are never assigned inside a
`setState` callback (they are mutated in plain methods — the cache-fill path),
and (c) the counted `setState` callback assigns/clears a `Future`/`Stream` field
or calls a method that does. This targets the invalidate-and-re-fetch idiom
without weakening the rule for genuine single-value state.

### Hypothesis B: narrower — require the counted field to be set inside setState

Only count a non-final field toward `stateFieldCount` if it is actually assigned
within a `setState` callback somewhere in the class. A field mutated only outside
`setState` (a cache key) is not the synchronous display value the rule targets.
Simpler than A and likely sufficient.

---

## Suggested Fix

Prefer Hypothesis B: in the field-counting loop (lines 1493-1518), track which
non-final field names are assigned inside a `setState` callback (the
`_SetStateCounterVisitor` already walks setState bodies — extend it to collect
assigned field names). Then only count a non-Future field toward
`stateFieldCount` if its name appears in that assigned-in-setState set. The
`_lastKeys`-style cache key, assigned only in `_initFutures`/`_cachedSecondary`
outside any `setState`, drops out of the count and the rule no longer fires.

---

## Fixture Gap

The fixture at `example*/lib/.../prefer_value_listenable_builder_fixture.dart` should include:

1. **State with a cached `Future` + a non-Future cache-key field + one `setState` that re-inits the futures** — expect NO lint (this bug).
2. **State with a single non-Future field assigned inside `setState` and no Future fields** — expect LINT (the genuine case stays flagged).
3. **State with a non-Future field mutated only outside `setState` and no Future fields** — expect NO lint (nothing drives a rebuild through that field).

---

## Changes Made

Implemented **Hypothesis B** in `PreferValueListenableBuilderRule`
(`lib/src/rules/core/performance_rules.dart`):

- The single field-and-method loop was split into three passes. Pass 1 now
  collects both `finalFieldNames` and `nonFinalFieldNames`. Pass 2 walks every
  method body to count `setState` calls, detect in-place mutation of a `final`
  collection, AND collect the names of non-final fields **reassigned inside a
  setState callback**. Pass 3 counts state fields.
- A non-Future field is now counted toward `stateFieldCount` only when it is
  reassigned inside a setState callback. The `_lastKeys`-style cache key, mutated
  only in plain helpers (and, in the reproducer, set inside `_initFutures` passed
  to setState as a **tear-off** — whose body is intentionally not scanned), no
  longer counts, so the rule no longer fires on the FutureBuilder cache idiom.
- Added `_SetStateAssignmentCollector` (mirrors the existing
  `_FinalFieldMutationVisitor`): records `=` / compound / `++` / `--`
  reassignments of a non-final field. In-place index mutation (`_list[i] = v`)
  is intentionally excluded, matching the `final`-collection guard.

Tear-off rationale: `setState(_reinit)` carries no assignment expressions in the
argument list walked here, so a field assigned only inside such a helper is not
collected. This is what exempts the invalidate-and-re-fetch idiom while keeping
inline `setState(() => field = x)` flagged.

---

## Tests Added

Fixture `example/lib/performance/prefer_value_listenable_builder_fixture.dart`
gained the three cases from the Fixture Gap section:

1. `_good790FutureCacheKeyState` — cached `Future` + non-Future cache-key field +
   one `setState(_initFutures)` tear-off → **no lint**.
2. `_bad790AssignedInSetStateState` — single non-Future field reassigned inside
   `setState`, no Future fields → **expect_lint** (genuine case still fires).
3. `_good790OutsideSetStateState` — non-Future field mutated only outside
   `setState`, no Future fields → **no lint**.

Verified with the scan CLI against a standalone reproducer: the rule fired only
on the two genuine single-value classes and stayed silent on the cache-key
companion and outside-setState classes. All six pre-existing fixture cases keep
their expected behavior.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 13.12.0
- Dart SDK version: (Flutter-bundled; project pins via fvm)
- custom_lint version: n/a — native analyzer plugin (`analysis_server_plugin`)
- Triggering project/file: `d:\src\contacts\lib\components\contact\contact_points_list_widget.dart:34`

---

## Finish Report (2026-06-05)

**Scope:** (A) Dart lint rules / analyzer plugin.

**Critical note:** This work was reviewed against the LINTER /finish checklist; it will be reviewed by another AI.

### What changed

`PreferValueListenableBuilderRule` (`lib/src/rules/core/performance_rules.dart`)
implemented Hypothesis B. The single field-and-method loop became three passes:

1. Collect `finalFieldNames` and `nonFinalFieldNames`.
2. Walk method bodies to count `setState`, detect in-place `final`-collection
   mutation, and collect non-final field names reassigned inside a `setState`
   callback (`fieldsAssignedInSetState`).
3. Count a non-`Future` field toward `stateFieldCount` only when it is in
   `fieldsAssignedInSetState`.

New visitor `_SetStateAssignmentCollector` records `=` / compound / `++` / `--`
reassignments of non-final fields, operator-guarded so postfix `!` and prefix
`!`/`-`/`~` reads are not mistaken for assignments. In-place index mutation
(`_list[i] = v`) is excluded by design, mirroring the `final`-collection guard.
Tear-off `setState(_reinit)` bodies are not scanned, which is what exempts the
FutureBuilder cache-key idiom.

### Deep review notes

- No quick fix added: the suggested ValueNotifier refactor is structural and
  non-mechanical, not safely auto-fixable.
- No tier / `LintImpact` / message / severity change — fix only, so no existing
  test assertion was invalidated.
- `_SetStateAssignmentCollector` reuses the existing visitor convention
  (`_FinalFieldMutationVisitor`); no duplication introduced.

### Verification

- `dart test test/rules/core/performance_rules_test.dart` → All tests passed (99).
- Scan CLI against a standalone reproducer: rule fired only on the two genuine
  single-value classes (reassigned field, `++` counter); silent on the cache-key
  companion, the read-only `!`/`-` case, and the outside-`setState` case.
- All six pre-existing fixture cases retain expected behavior (reasoned + the two
  `expect_lint` BAD cases confirmed via scan equivalents).

### Files

- `lib/src/rules/core/performance_rules.dart` — three-pass rewrite + new collector.
- `example/lib/performance/prefer_value_listenable_builder_fixture.dart` — 3 new cases.
- `CHANGELOG.md` — new `[Unreleased]` Fixed entry.
- This bug report — Status → Fixed, archived to `plans/history/2026.06/2026.06.05/`.

### Outstanding

None. Fix landed and verified.

Finish report appended: plans/history/2026.06/2026.06.05/prefer_value_listenable_builder_false_positive_future_cache_key_companion_field.md
