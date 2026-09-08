# BUG: `prefer_late_final` — misses tear-off call sites, undercounting reassignments

**Status: Fixed**

Created: 2026-09-08
Rule: `prefer_late_final`
File: `lib/src/rules/code_quality/code_quality_variables_rules.dart` (line ~3506, `_LateFinalMethodCallCounterVisitor.visitMethodInvocation`)
Severity: False positive
Rule version: v3

---

## Summary

`AvoidLateFinalReassignmentRule` counts how many times a `late` field is
assigned by (a) counting `AssignmentExpression`s inside each method/
constructor body, then (b) for a method containing exactly one such
assignment, multiplying by how many times *that method* is itself called
elsewhere in the class (`_adjustForMethodCallSites`). Step (b)'s call
counter (`_LateFinalMethodCallCounterVisitor`) only recognizes a
`MethodInvocation` node (`_initFutures()`), not a bare method **tear-off**
passed as a value — e.g. `setState(_initFutures)`. A field that is
genuinely reassigned on every call to a re-init method is flagged as a
`prefer_late_final` candidate when one of that method's call sites passes
it as a tear-off (the idiomatic `setState(callback)` pattern) instead of
invoking it directly.

---

## Attribution Evidence

```bash
grep -rn "'prefer_late_final'" lib/src/rules/
# lib/src/rules/code_quality/code_quality_variables_rules.dart:3310:    'prefer_late_final',
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_variables_rules.dart:3310`
**Rule class:** `AvoidLateFinalReassignmentRule` — defined at
`lib/src/rules/code_quality/code_quality_variables_rules.dart:26`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

```dart
import 'package:flutter/material.dart';

class Example extends StatefulWidget {
  const Example({super.key});
  @override
  State<Example> createState() => _ExampleState();
}

class _ExampleState extends State<Example> {
  // Reassigned once directly (initState) and once more via the tear-off
  // passed to setState() in _refresh() — two runtime reassignments, but
  // the rule only sees the direct `_initFutures();` call and reports this
  // as "assigned exactly once" -> LINT (false positive).
  late Future<int> _dataFuture; // LINT — but should NOT lint

  @override
  void initState() {
    super.initState();
    _initFutures();
  }

  void _initFutures() {
    _dataFuture = Future<int>.value(1);
  }

  void _refresh() {
    // Tear-off call site — NOT a MethodInvocation of `_initFutures`, so
    // _LateFinalMethodCallCounterVisitor.visitMethodInvocation never sees
    // it and the call-site adjustment stays at 1 (the initState call only).
    setState(_initFutures);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
```

**Frequency:** Always, whenever a re-init method assigning a `late` field
is invoked from at least one site as a bare tear-off (`setState(fn)`,
`onPressed: fn`, passed to a listener, etc.) rather than a direct call
expression.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `_dataFuture` is reassigned on every `_refresh()` call via the `setState(_initFutures)` tear-off, so `late final` would throw `LateInitializationError` on the second refresh |
| **Actual** | `[prefer_late_final] Late variable is never reassigned after its initial assignment...` reported on the field declaration |

---

## AST Context

```
ClassDeclaration (_ExampleState)
  └─ MethodDeclaration (_refresh)
      └─ Block
          └─ ExpressionStatement
              └─ MethodInvocation (setState)
                  └─ ArgumentList
                      └─ SimpleIdentifier (_initFutures)  ← tear-off, NOT a
                                                              MethodInvocation
                                                              of _initFutures
```

`_LateFinalMethodCallCounterVisitor.visitMethodInvocation` registers on
`MethodInvocation` and checks `node.methodName.name` — it never visits or
recognizes a bare `SimpleIdentifier` argument that happens to name one of
the tracked methods.

---

## Root Cause

`lib/src/rules/code_quality/code_quality_variables_rules.dart:3511-3523`:

```dart
@override
void visitMethodInvocation(MethodInvocation node) {
  final String methodName = node.methodName.name;
  if (counts.containsKey(methodName)) {
    final Expression? target = node.target;
    if (target == null || target is ThisExpression) {
      counts[methodName] = (counts[methodName] ?? 0) + 1;
    }
  }
  super.visitMethodInvocation(node);
}
```

This only fires for `MethodInvocation` AST nodes — a direct call
expression like `_initFutures()`. `setState(_initFutures)` has no
`MethodInvocation` node for `_initFutures` at all; `_initFutures` there is
a bare `SimpleIdentifier` used as an argument (a method tear-off/closure
value). The visitor has no handler for `SimpleIdentifier`/argument-position
references to a tracked method name, so this call site is invisible to
`_adjustForMethodCallSites`, and the field's assignment count stays at 1
(from the single textual assignment inside `_initFutures`, called once
directly from `initState`).

### Hypothesis A (confirmed): missing tear-off/argument-reference detection in the call-site counter

The counter needs a second visitor path (or an additional check inside
`visitMethodInvocation`/a new `visitSimpleIdentifier` override) that
recognizes a tracked method name used as a bare identifier in argument
position (or assigned to a variable, or passed to any higher-order
function — `setState`, `addPostFrameCallback`, `Timer`, `.then()`, an
`onPressed:`/`onTap:` callback slot, etc.) as an additional potential call
site, and either counts it conservatively (+1, since the tear-off could be
invoked any number of times including zero) or — safer given the rule
already treats "exactly 1 assignment" as the trigger — suppresses the
report entirely when a tracked method is referenced as a tear-off anywhere
in the class, since the actual runtime call count for a first-class
function value cannot be statically bounded from the declaration site.

---

## Suggested Fix

In `_LateFinalMethodCallCounterVisitor`, add:

```dart
@override
void visitSimpleIdentifier(SimpleIdentifier node) {
  // Skip the identifier when it IS the invocation's method name (already
  // handled by visitMethodInvocation) to avoid double-counting.
  if (node.parent is MethodInvocation &&
      (node.parent! as MethodInvocation).methodName == node) {
    super.visitSimpleIdentifier(node);
    return;
  }
  if (counts.containsKey(node.name) &&
      node.staticElement is MethodElement) {
    // Tear-off reference — the method could be invoked any number of
    // times at runtime through this callback, so treat conservatively:
    // bail out of the "exactly once" classification for every field this
    // method assigns, rather than guessing a call count.
    tornOffMethods.add(node.name);
  }
  super.visitSimpleIdentifier(node);
}
```

then in `_adjustForMethodCallSites`, exclude any method present in
`tornOffMethods` from the "assigned exactly once" report path entirely
(treat as unknown/unbounded call count rather than folding it into the
arithmetic `callCount - 1` adjustment, since a tear-off's actual
invocation count isn't statically knowable).

---

## Fixture Gap

The fixture (find via `grep -rn 'AvoidLateFinalReassignmentRule\|prefer_late_final' example_packages/`) should include:

1. **A `late` field reassigned via a direct call in one method, and via a
   tear-off of that same method passed to `setState`/a callback slot in
   another** — expect NO lint (this report's reproducer).
2. Keep existing **single-assignment, no tear-off anywhere** case — expect
   LINT (already covered, must still fire).
3. **Tear-off passed to something that is provably called at most once**
   (e.g. a one-shot `Future.then`) — currently unclear whether this should
   still lint; flag as a discussion point during fix review since the
   conservative "bail out on any tear-off" fix above would also suppress
   this case.

---

## Changes Made

`lib/src/rules/code_quality/code_quality_variables_rules.dart`:

- `_LateFinalMethodCallCounterVisitor` gained a `tornOffMethods` set and a
  `visitSimpleIdentifier` override. It skips the identifier when it's the
  method name of the `MethodInvocation` it's part of (already handled by
  `visitMethodInvocation`), otherwise flags a tracked method name resolving
  to a `MethodElement` as torn off (`node.element is MethodElement` — the
  analyzer 12 element-model accessor, not the removed `staticElement`).
- `_adjustForMethodCallSites`: for any method present in `tornOffMethods`,
  bump the field's assignment count by 1 (moving it off the "assigned
  exactly once" trigger) instead of folding it into the `callCount - 1`
  arithmetic — a tear-off's true invocation count can't be bounded
  statically, so this suppresses the report entirely for that field rather
  than guessing a count.

Per the report's "Fixture Gap" discussion point (Hypothesis A case 3, a
tear-off passed to a provably-single-call site like `Future.then`): not
special-cased. The fix suppresses on *any* tear-off reference, which is the
conservative and correct choice — proving a callback runs at most once
would require call-graph reasoning this rule doesn't do, and a false
negative (missing a genuine late-final candidate) is preferable to the
crash-risk false positive this bug reports.

---

## Tests Added

`example/lib/code_quality/prefer_late_final_fixture.dart`: added
`_GoodPreferLateFinalTearOffCallSite`, mirroring the bug's reproducer
(`setState(_initFutures)` pattern) — a field assigned by a method that is
both called directly (`init()`) and passed as a bare tear-off to another
method (`scheduleCallback(_refresh)`). Expects NO lint.

Verified with the in-repo scanner (unit tests are instantiation pins only,
not behavior proof — see `reference_verify_rule_behavior_scan_cli` memory):

```
dart run saropa_lints scan example/lib/code_quality --tier comprehensive \
  --files prefer_late_final_fixture.dart --format json --resolve
```

Before fix (with `--resolve`, so the element resolution the fix relies on
is present): `prefer_late_final` fired on both the intended BAD case
(line 8) and the new tear-off GOOD case (line 27) — 2 diagnostics.

After fix: `prefer_late_final` fires only once, on line 8 (the genuine
single-assignment case). The tear-off case at line 27 no longer lints.

Note: an unresolved scan (no `--resolve`) is a false negative for this
fix — `node.element` needs full resolution to identify the tear-off as a
`MethodElement`; without `--resolve` the fix's condition never triggers
and the false positive reappears. Always verify this rule with
`--resolve`.

Ran the full existing suite (`test/rules/code_quality/code_quality_rules_test.dart`,
221 tests) — all pass, no regression.

---

## Commits

- `3b0050d1` — fix: prefer_late_final no longer flags fields reassigned via method tear-offs

---

## Finish Report (2026-09-08)

`AvoidLateFinalReassignmentRule`'s `prefer_late_final` heuristic undercounted
runtime reassignments of a `late` field when the field's assigning method
was invoked at one site as a direct call and at another as a bare tear-off
(e.g. `setState(_initFutures)`). The tear-off call site was invisible to
`_LateFinalMethodCallCounterVisitor`, which only recognized
`MethodInvocation` nodes, so the rule treated a genuinely-reassigned field
as a single-assignment `late final` candidate and its own quick fix
(`AddLateFinalFix`) would introduce a real `LateInitializationError` crash
if applied.

`_LateFinalMethodCallCounterVisitor` gained a `visitSimpleIdentifier`
override that recognizes a tracked method name referenced outside its own
`MethodInvocation.methodName` position, resolved to a `MethodElement`, as a
tear-off. `_adjustForMethodCallSites` now bumps the assignment count for any
field assigned by a torn-off method above the `count == 1` trigger, rather
than folding an unbounded runtime call count into the existing
`callCount - 1` arithmetic.

Verified with the resolved-AST scan CLI
(`dart run saropa_lints scan --resolve`): before the fix, `prefer_late_final`
fired on both the genuine single-assignment case and the new tear-off
fixture case (2 diagnostics); after, only the genuine case fires (1
diagnostic). The existing 221-test `code_quality_rules_test.dart` suite and
the 16-test `false_positive_fixes_test.dart` fixture-coverage suite both
pass unchanged. Code review (`/code-review medium`) found no issues in the
changed file; two findings surfaced were in unrelated concurrent work
(`code_quality_avoid_rules.dart`, `ios_capabilities_permissions_rules.dart`)
and are out of scope for this fix.

Deliberately out of scope: the bug report's Hypothesis A case 3 (a tear-off
passed to a provably-single-call callback, e.g. one-shot `Future.then`) is
not special-cased — the fix suppresses on any tear-off reference
unconditionally, since proving a callback runs at most once would require
call-graph reasoning this rule does not implement, and a missed genuine
`late final` candidate is the safer failure mode than the crash-risk false
positive this bug reports.

### Hardening follow-up (2026-09-08)

Two additional fixture cases exercise edges the original fix wasn't tested
against: a tear-off reference registered inside a constructor body rather
than a method (`_GoodPreferLateFinalTearOffInConstructor`, confirming
`_LateFinalMethodCallCounterVisitor`'s `ConstructorDeclaration` traversal
path also feeds `visitSimpleIdentifier`), and a field whose assigning
method already has 2 direct call sites (triggering the pre-existing
`callCount - 1` arithmetic) that is *also* torn off elsewhere
(`_GoodPreferLateFinalMultiCallAndTearOff`, confirming the tear-off `+1`
bump doesn't misbehave when stacked on the older adjustment path). Both
verified suppressed via `--resolve` scan; `prefer_late_final` still fires
exactly once across all fixture classes (the one genuine case).

`PreferLateFinalRule`'s class-level DartDoc — previously a `duplicate
string literal` doc misattributed to this class, an unrelated pre-existing
documentation bug with no bearing on rule behavior — was replaced with an
accurate description of the rule plus a BAD/GOOD example demonstrating the
tear-off exemption directly in the rule source, rather than leaving that
behavior documented only in this bug archive.

Not addressed (documented as open risk, not fixed): whether `MethodElement`
is stable across future analyzer versions, tear-offs stored in an
intermediate variable before being passed to a callback
(`final cb = _method; setState(cb);`), and named-constructor / getter /
`Function.apply` tear-off shapes. These remain the same blind spots noted
in the original handoff reflection.

---

## Environment

- saropa_lints version: v3 (rule version)
- Triggering project/file: `d:/src/contacts` —
  `lib/components/contact/contact_points_list_widget.dart:43`
  (`_contactPointsFuture`, reassigned via `initState() -> _initFutures()`
  directly and via `_refresh() -> setState(_initFutures)` at line 94)
