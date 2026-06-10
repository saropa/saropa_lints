# BUG: `prefer_value_listenable_builder` — flags async-loaded counts, FutureBuilder re-fetch keys, transient locks, and notifier-diff caches as "simple single-value state"

**Status: Fixed**

Created: 2026-06-09
Rule: `prefer_value_listenable_builder`
File: `lib/src/rules/core/performance_rules.dart` (line ~1463)
Severity: False positive / High (fires on ~38 sites in one downstream app; forces `// ignore:` on extremely common idioms — async-count-into-int, FutureBuilder re-fetch key, in-flight lock, persisted-pref mirror, notifier-diff cache)
Rule version: v4 | Since: present in v4

---

## Summary

The rule's gate is purely structural: a `State<T>` with **exactly one** non-`final` field that is reassigned inside a `setState` callback, and `1 <= setStateCallCount <= 3`, is reported as "simple single-value state" that should migrate to `ValueListenableBuilder`. The four prior FP fixes (`future_cache`, `inplace_mutation_final_collection`, `future_cache_key_companion_field`, `controller_backed_state_bare_setstate`) each carved out one *structural* escape hatch, but the heuristic still has no way to tell a **synchronous display value** (what the rule targets) from a scalar that is one of:

1. **An async-loaded value** — `int _dbCount` filled by `setState(() => _dbCount = await ...)` in `initState` because the data source (Drift) has no synchronous API. A `ValueNotifier<int>` does not remove the async load; the `initState`/`await`/assign sequence is identical, and the field already reflects exactly the subtree that should rebuild.
2. **A FutureBuilder re-fetch key** — `int _rebuildKey` / `int _visibleCount` reassigned in `setState` purely to invalidate or re-slice a cached `Future` (which the existing async guard skips). The single counted field is the *cache key*, not a display value, and it is reassigned *directly* in `setState`, so the `future_cache_key_companion_field` guard (which only exempts fields *never* reassigned in `setState`) does not catch it.
3. **A transient reentrancy / in-flight lock** — `bool _isReordering` / `bool _isPersistingDragOrder` / `String? _loadingCode`, set in `setState` to block concurrent gestures or fetches. This is coordination state, not a single display value, and a `ValueListenableBuilder` would not isolate it (the whole widget reacts to the lock).
4. **A deferred-optimization flag** — `bool _blurActive`, flipped in a `setState` driven by an `AnimationController` status listener to defer `BackdropFilter` GPU cost until a transition settles. Driven by a `final` controller, not by user state.
5. **A persisted-preference mirror** — `late bool _isEnabled`, seeded in `initState` from a Drift `UserPreferenceType.boolValue` and updated optimistically after an async save. The source of truth is Drift, not a `ValueNotifier`; the field is read across the entire (tiny) widget body.
6. **A notifier-diff cache** — `String _displayedTime`, set in `setState` from a manual `ValueListenable` listener that suppresses 59 of every 60 ticks (only rebuild when the *minute* string changes). The widget **already uses a `ValueListenable`** and listens manually *precisely because* `ValueListenableBuilder` cannot express the diff-suppression — suggesting VLB here makes it strictly worse.

None of these is the "single synchronous display value updated by `setState`" the rule's correction message assumes. The fix the rule suggests ("replace `setState` with a `ValueNotifier` field and wrap the dependent UI in `ValueListenableBuilder`") is wrong or impossible for every category above.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'prefer_value_listenable_builder'" lib/src/rules/
# lib/src/rules/core/performance_rules.dart:1451:    'prefer_value_listenable_builder',

# Negative — NOT a rule definition in the sibling drift-advisor (only a config
# reference in analysis_options.yaml, no rule source)
grep -rn "'prefer_value_listenable_builder'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/src/rules/core/performance_rules.dart:1451`
**Rule class:** `PreferValueListenableBuilderRule` — `runWithReporter` at `lib/src/rules/core/performance_rules.dart:1458`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#5`

---

## Reproducer

Each block is a distinct real-world category. All fire today; none is the
single-synchronous-display-value the rule targets.

```dart
// (1) ASYNC-LOADED COUNT — Drift has no sync count API, so the int is filled
// asynchronously in initState. A ValueNotifier<int> does NOT remove the async
// load; the field already reflects exactly the subtree that rebuilds.
class _ButtonState extends State<Button> {
  int _dbCount = 0;                                       // ONLY counted field
  @override
  void initState() {
    super.initState();
    unawaited(_initCount());
  }
  Future<void> _initCount() async {
    final int count = await DatabaseFooIO.dbFooLoadCount();
    if (mounted) setState(() => _dbCount = count);        // ONLY setState
  }
  @override
  Widget build(BuildContext context) => CountBadge(_dbCount);
}
// LINT on _ButtonState — but the value is async-loaded; VLB cannot do the load.

// (2) FUTUREBUILDER RE-FETCH KEY — the int is reassigned in setState only to
// invalidate/re-slice a cached Future (Future field is skipped by the async
// guard). The counted field is a cache key, not a display value, and it is
// reassigned DIRECTLY in setState so the cache-key-companion guard misses it.
class _SectionState extends State<Section> {
  Future<List<Item>?>? _itemsFuture;                     // Future → skipped
  int _visibleCount = 10;                                // ONLY counted field
  @override
  Widget build(BuildContext context) {
    _itemsFuture ??= _fetch();
    return FutureBuilder<List<Item>?>(
      future: _itemsFuture,
      builder: (_, snap) => ShowMoreList(
        items: snap.data,
        visible: _visibleCount,
        onMore: () => setState(() => _visibleCount += 10), // ONLY setState
      ),
    );
  }
}
// LINT on _SectionState — but _visibleCount paginates a FutureBuilder; a single
// ValueListenableBuilder<int> cannot wrap a value that re-slices async data.

// (3) TRANSIENT IN-FLIGHT LOCK — bool/String set in setState to block
// concurrent gestures/fetches. Coordination state, not single display state.
class _PickerState extends State<Picker> {
  String? _loadingCode;                                  // ONLY counted field
  void _setLoadingCode(String? code) {
    if (mounted) setState(() => _loadingCode = code);    // ONLY setState
  }
  // build() reads _loadingCode to spin the tapped row and tap-block all rows.
}
// LINT on _PickerState — but this is cross-row coordination, not display state.

// (6) NOTIFIER-DIFF CACHE — already uses a ValueListenable; listens manually to
// suppress 59/60 ticks. VLB cannot express the diff and would rebuild 60x/min.
class _ClockState extends State<Clock> {
  String _displayedTime = '';                            // ONLY counted field
  @override
  void initState() {
    super.initState();
    widget.tickNotifier.addListener(_onTick);
  }
  void _onTick() {
    final String next = _format(widget.tickNotifier.value);
    if (next == _displayedTime) return;                  // diff-suppress
    if (mounted) setState(() => _displayedTime = next);  // ONLY setState
  }
}
// LINT on _ClockState — but migrating to ValueListenableBuilder REMOVES the
// minute-diff cache and rebuilds every second. Strictly worse.
```

**Frequency:** Always, whenever a `State` has exactly one non-`final` field reassigned in `setState`, `1 <= setStateCallCount <= 3`, and that field is an async-loaded value / a Future re-fetch key reassigned in `setState` / a transient lock / a controller-driven optimization flag / a persisted-pref mirror / a notifier-diff cache.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — none of these is a synchronous single display value that a `ValueNotifier` + `ValueListenableBuilder` could replace; the suggested refactor is wrong or impossible for every category |
| **Actual** | `[prefer_value_listenable_builder] Simple single-value state managed with setState …` reported on the State class name token |

---

## AST Context

```
ClassDeclaration (_ButtonState)              ← reported here (nameToken)
  ├─ FieldDeclaration  int _dbCount          (non-final, non-Future → COUNTED: stateFieldCount = 1)
  └─ MethodDeclaration _initCount
       └─ Block
           └─ … await … ExpressionStatement
               └─ MethodInvocation setState  (COUNTED: setStateCallCount = 1)
                   └─ FunctionExpression body
                       └─ AssignmentExpression  _dbCount = count   (→ fieldsAssignedInSetState = {_dbCount})
```

The async source (`await DatabaseFooIO.dbFooLoadCount()`) sits *outside* the
`setState` callback, so the field's declared type is `int`, not `Future`/`Stream` —
`_isAsyncBuilderCacheType` (line ~1588) returns false and the field is counted.

---

## Root Cause

`runWithReporter` (`performance_rules.dart:1458`) decides solely on *structure*:

```dart
// Skip Future/Stream-typed FIELDS only — not fields whose VALUE is async-loaded.
if (_isAsyncBuilderCacheType(member.fields.type)) {
  continue;
}
...
// Count only fields reassigned DIRECTLY in a setState callback.
if (!reassignedInSetState) {
  continue;
}
stateFieldCount++;
...
if (stateFieldCount == 1 &&
    setStateCallCount >= 1 &&
    setStateCallCount <= 3) {
  reporter.atToken(node.nameToken, code);   // ← fires
}
```

The guards added by the four prior fixes are all structural escape hatches keyed
on the *shape* of the `setState` or the *declared type* of the field:

- `_isAsyncBuilderCacheType` keys on the **field's declared type** (`Future`/`Stream`). It cannot see that `int _dbCount` is *filled* by an `await` — the async load is in `initState`, the field stays `int`. → category (1) escapes the guard.
- `reassignedInSetState` exempts only fields **never** assigned in a `setState` callback. A FutureBuilder cache key reassigned *directly* (`setState(() => _visibleCount += 10)` / `_rebuildKey++`) IS in `fieldsAssignedInSetState`, so it counts. → category (2) escapes the guard.
- `hasBareSetState` bails only when a `setState` callback assigns **no** non-final field. Categories (1)–(6) each assign exactly the lone counted field, so the callback is *not* bare. → categories (1)–(6) escape the guard.
- `mutatesFinalField` keys on in-place mutation of a **`final`** collection. Irrelevant to scalar fields. → no help.

The common blind spot: the rule equates "one non-`final` field reassigned by 1–3
`setState` calls" with "one synchronous display value." That equivalence is false
for async-loaded scalars, Future re-fetch keys, transient locks, optimization
flags, persisted-pref mirrors, and notifier-diff caches. The rule has no signal
that distinguishes a value the user would naturally hold in a `ValueNotifier`
from a value whose update is intrinsically tied to an async load, a Future
re-fetch, a `Listenable` it already consumes, or a persisted source of truth.

### Hypothesis A (narrow, highest-value): async-loaded scalar

If the single counted field is reassigned in a `setState` whose enclosing method
is `async` (or whose callback / enclosing method body contains an `await` on the
value's source), the value is async-loaded and a `ValueNotifier` cannot replace
the load. Bail out. This alone clears categories (1) and (2) — the two largest
buckets (the `_dbCount` async-count idiom and the `_visibleCount`/`_rebuildKey`
FutureBuilder companions, which are almost always in a State that also holds a
`Future`/`Stream` field).

### Hypothesis B: the State already holds a `Future`/`Stream` field

A State that declares a `Future`/`Stream` field (the FutureBuilder/StreamBuilder
cache idiom) is, by construction, not "simple single-value state" — its primary
rebuild driver is the async builder, and the lone non-`final` scalar is almost
always a companion (page count, re-fetch key, in-flight flag). If any
`_isAsyncBuilderCacheType` field exists on the class, bail out. Clears
categories (1), (2), and the lock-on-a-FutureBuilder cases in (3).

### Hypothesis C: the State consumes an external `Listenable`/controller it listens to manually

If the class wires `widget.<x>.addListener(...)` / holds a `final`
controller/`Listenable` read in `build`, its rebuilds are driven by that
listenable, not the scalar. Bail out. Clears categories (4) and (6) and overlaps
the already-shipped controller-backed guard.

---

## Suggested Fix

Prefer **Hypothesis B** as the primary fix — it is the cheapest, most robust
signal and subsumes most of the categories. Reuse the existing
`_isAsyncBuilderCacheType` check: in the first field-collection pass, set a
`hasAsyncBuilderField` flag when any non-static field's type is `Future`/`Stream`;
if set, `return` before reporting (mirroring the `mutatesFinalField` /
`hasBareSetState` guards). Rationale: a State with a `Future`/`Stream` field is a
FutureBuilder/StreamBuilder host whose lone scalar is a companion, never the
single synchronous display value the rule targets.

Layer **Hypothesis A** on top for the async-count case that has *no* Future field
(e.g. `_dbCount` loaded in `initState` and stored as plain `int`): if the
`setState` that assigns the lone field is lexically inside an `async` method body,
bail. Detect via the `_SetStateCounterVisitor` — record whether the `setState`
invocation's enclosing `FunctionBody` (`MethodDeclaration.body` /
`FunctionExpression.body`) `is` an async body, and surface an `onAsyncSetState`
callback paralleling `onBareSetState`.

Both are local to the existing visitor/guard structure; neither needs type
resolution.

---

## Fixture Gap

`example/lib/performance/prefer_value_listenable_builder_fixture.dart` should add:

1. **`int _dbCount` filled by `setState(() => _dbCount = await ...)` in an `async initState` helper, no Future field** — expect NO lint (category 1, Hypothesis A).
2. **`Future<T>? _future` + `int _visibleCount` reassigned by `setState(() => _visibleCount += 10)`** — expect NO lint (category 2, Hypothesis B). The Future field must coexist with the scalar reassigned directly in `setState`.
3. **`Future<T>? _future` + `int _rebuildKey` where `setState` assigns both `_rebuildKey++` and `_future = _reload()`** — expect NO lint (category 2 variant; `_future` is async-skipped, `_rebuildKey` is the lone counted field reassigned directly).
4. **`String _displayedTime` set in a manual `widget.notifier.addListener` callback with a `if (next == _displayedTime) return;` diff guard** — expect NO lint (category 6, Hypothesis C).
5. **`bool _isReordering` / `String? _loadingCode` lock set in one `setState`, no Future field, no listener** — decide intended behavior and document; if treated as a lock, Hypotheses A–C do not catch it, so this case needs an explicit decision (lock fields are arguably out of scope for VLB but structurally indistinguishable from a 1-field display State).
6. **Genuine positive control: `int _count` incremented by `setState(() => _count++)` from an `onPressed`, no Future field, no listener, sync** — expect LINT (the rule must still fire on real single-value display state).

The existing `_bad790*` cases must stay `expect_lint`; the new `_good790Async*`,
`_good790FutureCompanion*`, and `_good790NotifierDiff*` cases expect no lint.

---

## Environment

- saropa_lints version: 13.12.2
- Dart SDK version: (downstream `d:\src\contacts` toolchain)
- custom_lint version: n/a — native analyzer plugin (`analysis_server_plugin`)
- Triggering project/file: `d:\src\contacts` — ~38 sites, including:
  - `lib/components/utilities/database_tools/delete_buttons/delete_all_address_lat_long_button.dart:22` (category 1 — `int? _dbCount`)
  - `lib/views/contact/contact_coach_screen.dart:177` (category 1 — `int _dbCount`)
  - `lib/components/static_data/character_event/character_birthday_section.dart:53` (category 2 — `int _visibleCount` + `Future` field)
  - `lib/components/contact_issues/audit_panel_import_review.dart:79` (category 2 — `int _rebuildKey` + `Future` field)
  - `lib/components/home/components/language_picker_dialog.dart:123` (category 3 — `String? _loadingCode` lock)
  - `lib/components/contact/contact_status_list.dart:466` (category 3 — `Map<String,int> _pendingDragOrder` drag-override + `bool _isPersistingDragOrder` lock)
  - `lib/components/primitive/dialog/common_bottom_sheet.dart:87` (category 4 — `bool _blurActive` controller-driven)
  - `lib/components/user/backup_restore/backup_retention_toggle.dart:36` (category 5 — `late bool _isEnabled` Drift-pref mirror)
  - `lib/components/country/timezone/timezone_section.dart:101` (category 6 — `String _displayedTime` notifier-diff cache)
  - `lib/components/contact/detail_panels/email/email_panel.dart:70` (category 3 — `bool _isReordering` reorder lock; raw `setState` clears it, real state flows through FutureBuilder/StreamBuilder + `setStateSafe`)

## Finish Report (2026-06-10)

Fixed in WS-6 for categories 1, 2, 4, and 6 (the report's primary buckets) via Hypotheses A+B+C: bail when the State holds a Future/Stream field (B), assigns its field in an async setState (A), or manually wires a Listenable via .addListener (C). Verified by scan against the real contacts sites: contact_coach_screen (cat 1), character_birthday_section / audit_panel_import_review (cat 2), and timezone_section (cat 6) no longer fire. REMAINING (not fixed, by design): category 3 (transient in-flight lock, e.g. language_picker_dialog:123) and category 5 (persisted-pref mirror) — the report itself flags these as structurally indistinguishable from a single-value display State and needing an explicit product decision, so they are left firing rather than risk suppressing genuine positives.
