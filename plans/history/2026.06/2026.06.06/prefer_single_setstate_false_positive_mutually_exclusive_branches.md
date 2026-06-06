# BUG: `prefer_single_setstate` — flags setState calls in mutually-exclusive control-flow branches

**Status: Fixed** (2026-06-06, rule version v4)

Created: 2026-06-06
Rule: `prefer_single_setstate`
File: `lib/src/rules/widget/build_method_rules.dart` (line ~831, `runWithReporter`)
Severity: False positive
Rule version: v3 → v4

---

## Summary

`prefer_single_setstate` counts `setState` invocations per *lexical* execution
scope (the method body, each closure) and flags when a scope makes more than
one. It does not account for control flow: `setState` calls sitting in
mutually-exclusive branches — separate `if` arms, early-return guards, distinct
`switch`/`case`s, or a `catch` block — can never both execute in a single pass,
so they cannot be "combined into a single call". The rule reports them anyway.

## Attribution Evidence

```
$ grep -rn "'prefer_single_setstate'" lib/src/rules/
lib/src/rules/widget/build_method_rules.dart:819:    'prefer_single_setstate',
```

The matcher walks each scope and reports when `scopeCount > 1`, treating the
whole method body as one scope (only nested closures are deferred):

```dart
final List<AstNode> scopes = <AstNode>[node.body];
...
scope.visitChildren(_SetStateCountVisitor(
  onSetState: (MethodInvocation inv) { scopeCount++; firstInScope ??= inv; },
  onNestedClosure: scopes.add,
));
if (scopeCount > 1 && firstInScope != null) { firstMergeable = firstInScope; break; }
```

There is no awareness of `return` statements, `if`/`else` exclusivity,
`switch` cases, `try`/`catch` separation, or an `await` BETWEEN two setStates
(the canonical loading-state pattern: `setState(busy=true)` → `await work()` →
`setState(busy=false)`, which run at different microtask times and cannot be
merged without dropping the in-progress UI).

## Reproducer

```dart
// LINT (false positive) — each setState is on a distinct, mutually-exclusive
// execution path; none can be merged.
Future<void> _save() async {
  try {
    if (_busy) return;
    setState(() => _busy = true);          // path A (entry)
    final bool ok = await _doWork();
    if (!ok) {
      if (mounted) setState(() => _busy = false);  // path B (failure) — returns
      return;
    }
    if (mounted) setState(() => _busy = false);     // path C (success)
  } catch (_) {
    if (mounted) setState(() => _busy = false);     // path D (error)
  }
}

// LINT (false positive) — loading-state pattern: the two setStates are
// separated by an await and run at different times; merging would drop the
// in-progress spinner.
Future<void> _import() async {
  setState(() => _importing = true);   // before the await — show spinner
  await _add();
  if (!mounted) return;
  setState(() => _importing = false);  // after the await — hide spinner
}

// SHOULD STILL LINT — two setState calls on the SAME straight-line path.
void _bad() {
  setState(() => _a = 1);
  setState(() => _b = 2);   // mergeable: combine into one setState
}
```

## Expected vs Actual

| Shape | Expected | Actual |
|---|---|---|
| setState in `if`-arm + early-return guard | OK | LINT |
| setState in `try` body + `catch` block | OK | LINT |
| setState in two distinct `switch` cases | OK | LINT |
| setState before + after an `await` (loading state) | OK | LINT |
| two sequential setState on one path | LINT | LINT |

## Root Cause

The scope model is purely lexical. Mutual exclusion is a *control-flow*
property: statements separated by a `return`, or living in sibling `if`/`else`
/`case`/`catch` blocks, are never both reached. Separation by an `await` is a
*temporal* property: the two setStates fire in different microtasks and a merge
would erase the in-progress UI. Counting either together produces "combine
these" advice that is impossible to follow.

## Suggested Fix

Only count `setState` calls that are *reachable together* within a scope.
Practical approximations, cheapest first:

1. Do not count a `setState` that is preceded by an unconditional `return`
   in the same block (early-return guards).
2. Treat each branch of an `IfStatement` (then/else), each `SwitchCase`/
   `SwitchPatternCase` body, and the `catch`/`finally` blocks of a
   `TryStatement` as separate counting scopes — analogous to how nested
   closures are already deferred via `onNestedClosure`.
3. Do not count two setStates across an intervening `await` (an
   `AwaitExpression` statement between them) — they fire in different
   microtasks and serve the loading-state pattern.

Only flag when ≥2 setState calls remain in the SAME reachable, synchronous
straight-line segment.

## Fixture Gap

Add fixtures: setState in `if`/`else` arms (no lint), setState in try body +
catch (no lint), setState after an early-return guard then another later (no
lint), and two sequential setState on one path (still lint).

## Affected sites in Saropa Contacts (inline-ignored pending this fix)

- `lib/views/contact/contact_avatar_crop_screen.dart:231` — `_onSave` (try body + catch)
- `lib/views/contact/contact_avatar_crop_screen.dart:249` — `_onCropped` (switch case + catch)
- `lib/views/contact/contact_avatar_crop_screen.dart:266` — `_compressAndSave` (4 early-return/branch guards)
- `lib/views/_developer/email_signature_parser_panel.dart:117` — setState(importing=true) before `await dbContactAdd`, setState(importing=false) after (loading-state, await-separated)

---

## Finish Report (2026-06-06)

Fixed by replacing the lexical setState counter with a control-flow- and
await-aware segment scan. The old `_SetStateCountVisitor` descended the whole
method body (deferring only nested closures) and counted every `setState`
against one scope. The new `_findMergeableSetState` / `_scanScopeSegments` walk
each scope's statements in order and flag only when ≥2 setState calls land in
the same synchronous straight-line segment.

Two independent mechanisms suppress the false positives:

1. **Branch deferral** (suggested fix point 2). Each mutually-exclusive branch
   is handed to the worklist as its own scope, so calls that can never both run
   in one pass are never counted together:
   - `IfStatement` — `then` and `else` arms deferred (condition stays on the
     straight-line path).
   - `SwitchStatement` — each `SwitchMember` (case/default) deferred.
   - `TryStatement` — body, each `catch` body, and `finally` deferred.
2. **Await barrier** (suggested fix point 3). An `await` anywhere in a statement
   ends the current segment: setState calls before and after a suspension fire
   in different frames and cannot merge. This covers the loading-state idiom
   `setState(busy=true); await …; setState(busy=false)` even when the trailing
   call is unguarded (the panel site below).

### Suggested fix point 1 (early-return guards) — folded into point 2

Not implemented as a separate mechanism, and not needed: in every reported
shape the `return` lives inside an `if`-arm, which branch deferral already makes
its own scope. A bare unconditional `return` followed by more code is dead code
(rare) and could only ever cause an under-report, never a false positive.

### Verification

Verified via `dart run saropa_lints scan` against a standalone widget-shaped
reproducer (`extends State<…>`). Note: the example fixture dir is excluded from
analysis, and a `*_test.dart` filename is classified as a test file — neither is
a "widget" file, so `applicableFileTypes: {FileType.widget}` skips the rule
there; only a non-test `.dart` file with a `State` subclass exercises it.

- BAD (flagged): two sequential setStates on one path; two inside one `if`-arm;
  two unconditional setStates with no `await` between them.
- GOOD (clean): if/else arms; try body vs. catch; two switch cases; the
  real-world branch-guards-across-await shape from the reproducer; the
  loading-state pattern (`setState(true); await; setState(false)`).

`dart analyze lib` clean; `build_method_rules_test.dart` passes. Rule version
bumped v3 → v4 (message + dartdoc). Fixtures added to
`example/lib/build_method/prefer_single_setstate_fixture.dart`. CHANGELOG
updated under `[Unreleased]`.

### Saropa Contacts inline ignores can be removed

All four affected sites are now covered (sites 1–3 by branch deferral, site 4 by
the await barrier); the pending inline ignores can be dropped once this ships.
