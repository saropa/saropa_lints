# BUG: `require_app_lifecycle_handling` — Never Checks `dispose()` for `.cancel()`/`.disposal()` of the Flagged Field

**Status: Fixed**

Created: 2026-08-15
Rule: `require_app_lifecycle_handling`
File: `lib/src/rules/architecture/lifecycle_rules.dart` (line ~602)
Severity: False positive
Rule version: v4 | Since: v2.4.0 | Updated: v4.13.0

---

## Summary

The rule demands a `WidgetsBindingObserver`/`didChangeAppLifecycleState`/
`AppLifecycleListener` marker on any `State` class that contains
`Timer(...)`, `Timer.periodic(...)`, or `.listen(...)` anywhere in its method
bodies — it never checks whether the class's `dispose()` method already
cancels the timer/subscription, which is the standard, sufficient Flutter
lifecycle pattern for a foreground-only clock/ticker that doesn't need to
pause on backgrounding. Confirmed false positive on
`_WorldClockListScreenState` in
`lib/views/country/world_clock_list_screen.dart`, whose `Timer? _timer` is
correctly cancelled via `_timer?.cancel()` in `dispose()`.

---

## Attribution Evidence

```bash
grep -rn "'require_app_lifecycle_handling'" lib/src/rules/
# lib/src/rules/architecture/lifecycle_rules.dart:627:    'require_app_lifecycle_handling',
```

**Emitter registration:** `lib/src/rules/architecture/lifecycle_rules.dart:627`
**Rule class:** `RequireAppLifecycleHandlingRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Trimmed from `lib/views/country/world_clock_list_screen.dart`
(`_WorldClockListScreenState`), preserving the exact shape: a periodic
`Timer` field, created in `initState`, cancelled in `dispose`, no
`WidgetsBindingObserver`.

```dart
class WorldClockListScreen extends StatefulWidget {
  const WorldClockListScreen({super.key});
  @override
  State<WorldClockListScreen> createState() => _WorldClockListScreenState();
}

// LINT — but should NOT lint: the Timer is created and cancelled inside the
// same class's own initState/dispose pair, the standard Flutter pattern for
// a foreground-only ticking clock display. No lifecycle pause/resume is
// needed because the widget (and its Timer) simply don't exist while the
// screen isn't mounted.
class _WorldClockListScreenState extends State<WorldClockListScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
```

**Frequency:** Always — any `State` subclass with a `Timer`/`.listen()` and a
correct `dispose()` cancellation, but no `WidgetsBindingObserver`-style hook,
is flagged identically to one that leaks the timer entirely.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic, OR a materially different (lower-severity) message — the resource is provably bounded by the widget's own mount lifecycle via `dispose()`, which is Flutter's standard cleanup contract |
| **Actual** | `[require_app_lifecycle_handling] Timer or subscription detected without lifecycle handling. Stop background work when app is inactive to save battery.` reported at the class name token, identical to the message for a class that never cancels the timer at all |

---

## AST Context

```
ClassDeclaration (_WorldClockListScreenState)   ← context.addClassDeclaration; reported at nameToken
  extendsClause: State<WorldClockListScreen>    ← _extendsState() == true
  (no withClause / implementsClause)            ← _hasLifecycleHandling() checks WidgetsBindingObserver here: absent
  bodyMembers:
    FieldDeclaration (Timer? _timer)
    MethodDeclaration (initState)
      └─ Timer.periodic(...)                    ← _hasBackgroundWork(): regex \bTimer\.periodic\b matches body.toSource()
    MethodDeclaration (dispose)                 ← NEVER INSPECTED by _hasLifecycleHandling or _hasBackgroundWork
      └─ _timer?.cancel()                       ← the exact cleanup the rule claims is missing
```

---

## Root Cause

`RequireAppLifecycleHandlingRule.runWithReporter`
(`lib/src/rules/architecture/lifecycle_rules.dart:637-649`):

```dart
context.addClassDeclaration((ClassDeclaration node) {
  if (!_extendsState(node)) return;
  if (_hasLifecycleHandling(node)) return;
  if (_hasBackgroundWork(node)) {
    reporter.atToken(node.nameToken, code);
  }
});
```

`_hasLifecycleHandling` (lines 657-686) only looks for three specific
markers: a `WidgetsBindingObserver` mixin/interface, a
`didChangeAppLifecycleState` method, or an `AppLifecycleListener` field. It
never iterates `node.bodyMembers` looking for a `dispose()` method, and never
cross-references the field name captured by `_hasBackgroundWork` (which
doesn't capture a field name at all — see below) against anything inside
`dispose()`.

`_hasBackgroundWork` (lines 692-702) is a source-text regex scan
(`_timerConstructorPattern`, `_timerPeriodicPattern`, `_listenCallPattern`)
over every `MethodDeclaration`'s `toSource()` in the class, independently of
`dispose()`. It returns `true` the moment ANY method body contains
`Timer(`, `Timer.periodic(`, or `.listen(` — including a match found inside
`dispose()` itself (the cancellation call reads `_timer?.cancel()`, which
does not match those patterns, but if the class additionally had, say, a
`.listen()` teardown helper called from `dispose()`, it could ironically
trigger `_hasBackgroundWork` from inside the very method meant to prove
cleanup).

There is no code path anywhere in this rule that reads `dispose()`'s body and
checks it for `.cancel()`, `.close()`, or reassignment to `null` of the same
field the `Timer`/`.listen()` call was assigned to. The rule's own doc
comment context (lines 581-601) shows only the `WidgetsBindingObserver`
pattern as "Good" — it never considers "create in `initState`, cancel in
`dispose()`, no lifecycle-state pause needed" as a distinct, valid case.

---

## Suggested Fix

Track the field name each `Timer`/`StreamSubscription` is assigned to (via a
proper AST walk of `initState`'s `AssignmentExpression`/`VariableDeclaration`
targets, mirroring the existing `_assignmentTargetFieldName` helper already
defined earlier in this same file at lines 551-560), then search `dispose()`
specifically for a `<fieldName>?.cancel()` / `<fieldName>.cancel()` call on
that same field. Only flag when no such cancellation is found AND no
lifecycle-observer marker exists — i.e., treat "cancelled in dispose" and
"paused via app-lifecycle hook" as two independently sufficient answers, not
require the latter unconditionally.

---

## Fixture Gap

The fixture at
`example*/lib/architecture/require_app_lifecycle_handling_fixture.dart`
should include:

1. `Timer.periodic` created in `initState`, cancelled via `<field>?.cancel()`
   in `dispose()`, no `WidgetsBindingObserver` — expect NO lint
2. `Timer.periodic` created in `initState`, `dispose()` present but does NOT
   cancel the timer — expect LINT (current true-positive case, must keep
   working)
3. `.listen()` subscription assigned to a field, cancelled in `dispose()` —
   expect NO lint
4. `Timer.periodic` with a genuine `WidgetsBindingObserver` pause/resume
   pattern — expect NO lint (current behavior, must keep working)

---

## Changes Made

`lib/src/rules/architecture/lifecycle_rules.dart` (`RequireAppLifecycleHandlingRule`):

- `_hasBackgroundWork` now skips `dispose()` itself when scanning for
  `Timer`/`Timer.periodic`/`.listen()` occurrences (it only starts scanning
  cleanup calls, not new background work).
- Added `_isCleanedUpInDispose`, which walks every `Timer`/`Timer.periodic`/
  `.listen()` call site in the class (via a new `_BackgroundWorkVisitor` AST
  walk, plus inline `FieldDeclaration` initializers), finds the class's
  `dispose()` method, and checks — using the existing `isFieldCleanedUp`
  helper from `target_matcher_utils.dart` — whether every field-attributed
  call site is `.cancel()`ed or `.close()`d there.
- `runWithReporter` now treats "canceled/closed in `dispose()`" as
  independently sufficient alongside the existing
  `WidgetsBindingObserver`/`didChangeAppLifecycleState`/
  `AppLifecycleListener` markers; only flags when neither is present.
- If a background-work call site isn't assigned to an identifiable class
  field (local variable, fire-and-forget, or dispose() doesn't exist), the
  rule falls back to the original conservative behavior and still flags —
  no regression on the true-positive (leak) case. This also covers a class
  that mixes one field-tracked, properly-canceled Timer with a second,
  untracked fire-and-forget one: the untracked call site alone forces the
  flag, even though the tracked field passes cleanly on its own — a review
  pass caught this as a would-be false negative in an earlier draft of the
  fix, where only named fields were checked and an untracked sibling could
  slip through unnoticed.
- Bumped rule doc to `Rule version: v5`, updated the problem/correction
  messages to mention the dispose-cleanup path, and added a second "Good"
  example to the class doc comment.

## Tests Added

`example/lib/lifecycle/require_app_lifecycle_handling_fixture.dart` — added
the four cases from the Fixture Gap section above:

1. `_WorldClockListScreenState` — Timer created in `initState`, canceled in
   `dispose()`, no observer — verified NO lint.
2. `_bad463b__LeakyDisposeState` — Timer created in `initState`, `dispose()`
   present but does not cancel it — verified still LINTs (true positive
   preserved).
3. `_good463c__SubscriptionCanceledState` — `.listen()` subscription field
   canceled in `dispose()` — verified NO lint.
4. `_good463__MyState` — existing `WidgetsBindingObserver` case — verified
   still NO lint.
5. `_bad463d__MixedTrackedAndUntrackedState` — one field-tracked Timer
   properly canceled in `dispose()`, plus a second, untracked
   fire-and-forget `Timer.periodic()` — verified still LINTs (added after a
   deep-review pass flagged this as a would-be false negative).

Verified by copying the fixture to a scratch project (outside `example/`,
since the scan CLI's own `/example` path exclusion prevents scanning
`example/` directly) and running
`dart run saropa_lints scan <scratch> --tier comprehensive --files lib/fixture.dart --format json`:
`require_app_lifecycle_handling` fired exactly on the three BAD cases
(`_bad463__MyState`, `_bad463b__LeakyDisposeState`,
`_bad463d__MixedTrackedAndUntrackedState`) and stayed silent on the three
GOOD cases.

Also ran `test/rules/architecture/lifecycle_rules_test.dart`,
`test/integrity/saropa_lints_test.dart`, and
`test/integrity/anti_pattern_detection_test.dart` — all pass.

---

## Commits

_Pending — committed alongside this archival._

---

## Finish Report (2026-08-15)

`require_app_lifecycle_handling` flagged every `State` subclass using a
`Timer`/`Timer.periodic`/`.listen()` call without a
`WidgetsBindingObserver`-style lifecycle marker, without ever checking
whether `dispose()` already canceled/closed the field it was assigned to —
the standard, sufficient Flutter cleanup pattern for a foreground-only
ticker. The rule now treats "canceled/closed in `dispose()`" as an
independently sufficient answer alongside the lifecycle-observer markers,
via a new AST walk that attributes each background-work call site to a
class field (when possible) and checks that field's cleanup in `dispose()`.
A call site that cannot be attributed to a named field — a local variable,
a fire-and-forget call — still forces the class to be flagged, even when
every other, field-tracked call site in the same class is properly
canceled; this closes a would-be false-negative gap surfaced during review
of an earlier draft of the fix that checked named fields only. The fixture
gained five new/exercised cases spanning the dispose-cancel good path, the
still-must-flag leak path, a canceled stream subscription, the pre-existing
observer path, and the mixed tracked/untracked regression case.

---

## Environment

- saropa_lints version: (repo HEAD at filing time)
- Dart SDK version: n/a
- custom_lint version: n/a
- Triggering project/file: downstream Flutter/Dart app (contacts),
  `lib/views/country/world_clock_list_screen.dart` (`_WorldClockListScreenState`),
  2 occurrences reported against `lib/main.dart` region per prior triage —
  the reproducible, file-verified instance is `world_clock_list_screen.dart`;
  the mechanism (dispose-cancel never checked) applies identically wherever
  this shape occurs.
