# BUG: `avoid_expensive_build` — matcher list conflates heavy operations with idiomatic Flutter list rendering, producing 45 hits in a single project that are not actionable as-is

**Status: Fixed**

Created: 2026-06-01
Fixed: 2026-06-01
Rule: `avoid_expensive_build`
File: `lib/src/rules/core/performance_rules.dart` (line ~203, `_expensiveOperations`)
Severity: Improvement / overly broad
Rule version: v3 | Since: prior | Updated: v3

## Attribution (positive grep)

```
$ grep -rn "'avoid_expensive_build'" lib/src/rules/
lib/src/rules/core/performance_rules.dart:195:    'avoid_expensive_build',
```

Rule lives in `saropa_lints`.

## Summary

The rule's `_expensiveOperations` set (line 203) lumps together two semantically different categories of method calls:

**Heavy (genuinely justifies the warning):**

- `jsonDecode`, `jsonEncode` — string parsing of unbounded payload
- `parse`, `tryParse` — domain-dependent, often heavy
- `readAsString`, `readAsBytes`, `readAsLines`, `readAsBytesSync`, `readAsStringSync` — file I/O
- `compute` — explicit isolate dispatch

**Iteration primitives (NOT inherently expensive, used everywhere in idiomatic Flutter):**

- `sort` — O(n log n) on a list; on small UI lists (≤100 elements) imperceptible
- `where` — O(n) filter; foundational Flutter list-rendering primitive
- `map` — O(n) transform; the standard way to convert `List<T>` → `List<Widget>`
- `fold` — O(n) accumulation
- `reduce` — O(n) accumulation

The rule fires on any call to ANY name in the combined set inside a Widget's `build()`. With the iteration primitives included, the rule effectively says: "don't transform a list into widgets inside build()", which contradicts the documented Flutter pattern:

```dart
// Flutter's own cookbook demonstrates this exact pattern repeatedly:
Column(
  children: items.map((Item i) => Text(i.label)).toList(),
)
```

## Downstream impact (the noise/signal problem)

Enabling this rule in `saropa/contacts` produced **45 WARNING-severity hits** on the very first run. Sampling a representative cross-section:

```dart
// activity_list_widget.dart:220  --  rendering a list of activities
Column(
  children: activities!.map((a) => ActivityViewWidget(a)).toList(),
)

// activity_list_recent_phone_calls.dart:92 -- standard StreamBuilder data prep
final activities = snapshot.data?.where((a) => a.displayDayOnly() != null).toList();

// activity_list_recent_phone_calls.dart:116 -- one-pass derivation for sectioning
final groupValues = activities
    .map((a) => a.activityDateOnly())
    .nonNulls
    .toList()
    .toDateOnlySorted(...);

// recent_emails.dart:173 -- builder callback rendering activity rows
childrenBuilder: () => groupedActivities.map(...).toList(),
```

Every one of these is a small-list (≤~100 elements) UI rendering pattern. Caching each as a State field would mean:

- Add a `List<Widget>? _cachedXyz;` field per call site (45 fields).
- Track invalidation: when `widget.contacts` changes, when `snapshot.data` changes, when filters change — `didUpdateWidget`, `didChangeDependencies`, every state setter.
- Reset cache on every parent state mutation.

For a perf gain that is unmeasurable on these list sizes. The net effect is **45 line-level `// ignore:` directives**, each carrying a one-sentence rationale, contributing zero quality signal — and burying future *real* fires under noise.

## Suggested fix

Split `_expensiveOperations` into two tiers — keep this rule as the **heavy** tier, and either:

1. **Demote** the iteration primitives to a separate rule with INFO severity, narrowing its matcher with a collection-size hint (e.g., only flag inside `for` loops, or only when chained 3+ times) — name candidate: `avoid_iteration_chains_in_build`. OR
2. **Drop** the iteration primitives entirely from `avoid_expensive_build`; let `avoid_excessive_rebuilds_animation` (already exists) and `prefer_value_listenable_builder` (already exists) cover the rebuild-perf concern at a higher level.

Either way, the heavy tier stays unambiguous and actionable:

```dart
static const Set<String> _expensiveOperations = <String>{
  'jsonDecode',
  'jsonEncode',
  'parse',
  'tryParse',
  'readAsString',
  'readAsBytes',
  'readAsLines',
  'readAsBytesSync',
  'readAsStringSync',
  'compute',
};
```

## Why iteration primitives don't belong in the heavy tier

- **`sort`** — performed in place on existing list, no allocation; size-dependent. The rule already exempts `take(n).toList()` in `avoid_large_list_copy`'s sibling rationale; the same size-aware spirit applies here.
- **`where` / `map` / `fold` / `reduce`** — these are LAZY on Iterables until materialized. Flagging them in build() conflates the conceptual concern (excessive rebuilds) with the syntactic shape (using a higher-order function). The same logic flagged would equivalently be written as an imperative `for` loop and not trigger the rule — that's a sign the matcher is on the wrong axis.

## Project decision (`saropa/contacts`)

After surfacing the 45 hits and sampling 4 sites, the project owner chose to **SKIP** this rule pending the upstream narrowing. Rationale comment is in [analysis_options.yaml#L334](../../contacts/analysis_options.yaml#L334) pointing at this bug.

Re-enable in `saropa/contacts` once either:

- The matcher narrows to the heavy tier above, OR
- The rule splits into `avoid_expensive_build_heavy` (this stays WARNING) + `avoid_expensive_build_iteration` (separate INFO, opt-in).

## Fixture gap

Add fixtures that should NOT fire (under the proposed narrowing):

```dart
// fixtures/avoid_expensive_build_iteration_ok.dart
class MyWidget extends StatelessWidget {
  final List<String> items;
  const MyWidget({required this.items, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((s) => Text(s)).toList(),  // expect: no diagnostic
    );
  }
}
```

```dart
// fixtures/avoid_expensive_build_heavy_fires.dart
class MyWidget extends StatelessWidget {
  final String json;
  const MyWidget({required this.json, super.key});

  @override
  Widget build(BuildContext context) {
    final data = jsonDecode(json);  // expect: diagnostic
    return Text(data['title']);
  }
}
```

---

## Finish Report (2026-06-01)

### Resolution

Adopted option 2 from the bug report's "Suggested fix" section — **dropped the iteration primitives entirely** from `_expensiveOperations`. The rebuild-axis concern those calls used to proxy for is already covered by `avoid_excessive_rebuilds_animation` and `prefer_value_listenable_builder`, so a second matcher on the call-name axis added noise without coverage. No new rule was created (option 1 was rejected — would have introduced an `avoid_iteration_chains_in_build` whose only useful narrowing is a chained-length heuristic, which doesn't carry its weight as a separate rule).

### Changes

- `lib/src/rules/core/performance_rules.dart` — `_expensiveOperations` narrowed to the 10 heavy operations (`jsonDecode`, `jsonEncode`, `parse`, `tryParse`, `compute`, `readAsString`, `readAsBytes`, `readAsLines`, `readAsBytesSync`, `readAsStringSync`); rule version tag bumped from `{v2}` to `{v3}` in problemMessage; DartDoc explains the v3 narrowing inline so future readers see the rationale without chasing CHANGELOG.
- `example/lib/performance/avoid_expensive_build_fixture.dart` — added `_IterationInBuildOk` (StatelessWidget exercising all five removed primitives — `where`/`map`/`sort`/`fold`/`reduce` — must NOT fire) and `_HeavyInBuild` (StatelessWidget with `jsonDecode` — must fire, carries `// expect_lint: avoid_expensive_build`). Existing fixture left untouched.
- `CHANGELOG.md` — added `[Unreleased]` section with one-bullet `### Fixed` entry covering the narrowing.

### Verification

Scanned a synthetic widget pair (`IterationWidget` with all five primitives + `HeavyWidget` with `jsonDecode`) at `--tier comprehensive`:

```
"byRule": {
  "avoid_expensive_build": 1,   // jsonDecode in HeavyWidget.build()
  ...
}
```

Only the heavy call fired. All five iteration calls in `IterationWidget.build()` produced zero `avoid_expensive_build` diagnostics. The `{v3}` tag in the diagnostic message confirms the active code is the narrowed version. Verification fixture deleted; the in-repo example fixture is the permanent record.

### Downstream

The `saropa/contacts` project still has this rule listed as SKIP in `analysis_options.yaml#L334`. Re-enable in `contacts` once this change ships to pub.dev — the 45 previously-fired sites will all go silent without code changes.

### Out of scope

- The pre-existing `_bad778_build` fixture function is named `_bad778_build` (not `build`), so it cannot trigger the rule regardless of `_expensiveOperations` contents — that's a latent fixture-naming defect unrelated to this bug. Left in place.
- The bug report mentioned `avoid_excessive_rebuilds_animation` and `prefer_value_listenable_builder` as sibling coverage; both exist in the codebase, no changes needed.
