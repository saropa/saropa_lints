# BUG: `require_late_initialization_in_init_state` — Fires on Reassignment Inside an `onPressed` Callback (Not Build-Path Initialization)

**Status: Open**

Created: 2026-05-31
Rule: `require_late_initialization_in_init_state`
File: `lib/src/rules/architecture/lifecycle_rules.dart` (line 387)
Severity: False positive
Rule version: v3 | Since: v?.?.? | Updated: v?.?.?

---

## Summary

The rule uses a regex over the build method's entire source text to look for `<lateField> =` assignments and flags the build method when any match is found. It does NOT distinguish between:

1. **Direct assignment in the synchronous build call path** — the REAL violation the rule is designed to catch (recreates the value every rebuild).
2. **Assignment inside a UI callback** — `onPressed`, `onTap`, `setState(() => ...)`, etc. — which is NOT a violation (the callback only runs on user action, not on every rebuild).
3. **Reassignment** (where the field was already initialized in `initState`) — also NOT a violation.

Cases (2) and (3) are standard, correct patterns. The rule's regex fires on all three.

---

## Attribution Evidence

```bash
$ grep -rn "'require_late_initialization_in_init_state'" D:/src/saropa_lints/lib/src/rules/
D:/src/saropa_lints/lib/src/rules/architecture/lifecycle_rules.dart:406:    'require_late_initialization_in_init_state',
```

Single match — rule is unambiguously emitted by `saropa_lints`. Class: `RequireLateInitializationInInitStateRule` at line 387.

---

## Reproducer

Minimal Dart code: `late int _currentLimit` is correctly initialized in `initState`. Inside `build`, an `onPressed` callback reassigns it via `setState`. This is a standard "View All / load more" pattern.

```dart
import 'package:flutter/material.dart';

class Demo extends StatefulWidget {
  const Demo({super.key, this.initialLimit = 10});
  final int initialLimit;

  @override
  State<Demo> createState() => _DemoState();
}

class _DemoState extends State<Demo> {
  // Uninitialized `late` field — assigned in initState below.
  late int _currentLimit;

  @override
  void initState() {
    super.initState();
    // CORRECT initialization site.
    _currentLimit = widget.initialLimit;
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      // Callback fires on user tap, NOT on every rebuild.
      // This is a legitimate reassignment, not a late-field initialization.
      onPressed: () => setState(() {
        _currentLimit = 0;
      }),
      child: Text('Show all ($_currentLimit)'),
    );
    // FALSE POSITIVE: rule reports the build method.
  }
}
```

**Frequency:** Always — whenever a `late` field is reassigned anywhere in the lexical body of `build()`, even inside a deferred callback.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the `late` field is properly initialized in `initState`; the `onPressed` reassignment runs only on user interaction. |
| **Actual** | `[require_late_initialization_in_init_state] Late field initialized in build() ...` reported on the entire build method node. |

---

## AST Context

```
MethodDeclaration (build)                       ← rule reports HERE
  └─ FunctionBody
      └─ ReturnStatement
          └─ InstanceCreationExpression (TextButton)
              └─ ArgumentList
                  └─ NamedExpression (onPressed:)
                      └─ FunctionExpression           ← inside this closure
                          └─ MethodInvocation (setState)
                              └─ FunctionExpression
                                  └─ ExpressionStatement
                                      └─ AssignmentExpression (_currentLimit = 0)
                                          ← regex matches here, but this code
                                            runs only on tap, not every build
```

The rule's `_checkBuildMethodForLateAssignments` (line 450) calls `body.toSource()` and runs `RegExp('(?:^|[^\\w])(?:this\\.)?$fieldName\\s*=\\s*[^=]')` against the full source string. Any textual match — including matches inside nested `FunctionExpression` closures, `setState` callbacks, builder lambdas, or `onPressed` / `onTap` handlers — causes the build method to be reported.

---

## Root Cause

**Mechanism:** The rule's detection uses string-based regex matching over the build method body's source text instead of walking the AST. This loses the structural context that would let it distinguish:

- An `AssignmentExpression` whose enclosing `FunctionBody` is the `build` method itself (synchronous build path — real violation).
- An `AssignmentExpression` whose enclosing `FunctionBody` is a nested `FunctionExpression` (a callback — runs only when invoked, not every build).

Lines 459–465 in `lib/src/rules/architecture/lifecycle_rules.dart`:

```dart
final String bodySource = body.toSource();
final assignmentPatterns = fieldList
    .map(
      (fieldName) =>
          RegExp('(?:^|[^\\w])(?:this\\.)?$fieldName\\s*=\\s*[^=]'),
    )
    .toList();

for (var i = 0; i < fieldList.length; i++) {
  if (assignmentPatterns[i].hasMatch(bodySource)) {
    reporter.atNode(buildMethod);
    return;
  }
}
```

The regex has no way of knowing whether the matched assignment sits at depth 0 in the build method (real violation) or depth N inside a closure (not a violation).

A second mechanism error: the rule also doesn't check whether `initState` already assigns the field. A `late` field that's correctly initialized in `initState` then reassigned elsewhere isn't a "late initialization" problem at all — it's a normal mutable State field. Cases (2) and (3) in Summary both flow from these two oversights.

### Hypothesis A: walk the AST instead of regex

Replace the regex pass with a `RecursiveAstVisitor` that:

1. Visits `AssignmentExpression` nodes inside the build method body.
2. For each, walks UP the AST until either:
   - It hits a `FunctionExpression` whose parent is something other than the build's direct `FunctionBody` (= the assignment is inside a callback → skip), OR
   - It reaches the build method itself directly (= synchronous build path → confirm reassignment).
3. If the assignment is on the synchronous build path AND the field is in `lateFields` AND `initState` does NOT also assign the field, report the violation.

The "initState also assigns it" check (#3) eliminates the reassignment FP as well — a field initialized once in initState is no longer "late uninitialized" by the time build runs.

### Hypothesis B: cheap heuristic without full AST walk

Strip nested function expression bodies from `bodySource` before running the regex. The build method's "synchronous body" is everything NOT inside a `FunctionExpression { ... }` block. Less accurate but cheaper than a full AST walk; still better than the current regex.

---

## Suggested Fix

Implement Hypothesis A. Net change:

- Replace lines 459–474 with an AST visitor.
- Add a pre-pass that collects field names assigned in `initState` and excludes them from `lateFields` before scanning build.
- Add the four fixture cases below.

---

## Fixture Gap

The fixture (search for `require_late_initialization_in_init_state` under `example*/lib/`) should include these cases. Search for the existing fixture file before adding — likely at `example/lib/architecture/require_late_initialization_in_init_state_fixture.dart`.

1. **GOOD — `late` field assigned in `initState`, reassigned inside `onPressed` callback in build.** Reproducer above. Expect: no lint.
2. **GOOD — `late` field assigned in `initState`, reassigned inside `setState(() { ... })` callback in build.** Same shape, different surface. Expect: no lint.
3. **BAD — `late` field NOT assigned in `initState`, assigned directly in build's synchronous return statement.** Expect: lint fires.
4. **BAD — `late` field NOT assigned in `initState`, assigned in a `FutureBuilder.builder` callback that runs every rebuild.** Expect: lint fires. (Edge: `builder` IS technically a callback, but it runs on every build — confirms the rule should look at when the callback runs, not just that it's a callback.)

Case 4 is the hard one and shows why a structural test ("is this an `onPressed`/`onTap`?") is brittle; the right test is "does this callback run as part of every rebuild?", which is hard to know in general. A safer bet is the "initState already assigned it" check (#3 in Hypothesis A) — that alone covers most real-world cases including the `onPressed` reassignment pattern.

---

## Changes Made

<!-- Empty until a fix lands upstream. -->

---

## Tests Added

<!-- Empty until a fix lands upstream. -->

---

## Commits

<!-- Empty until a fix lands upstream. -->

---

## Environment

- saropa_lints version: 13.11.1
- Dart SDK version: (project pinned, see contacts/pubspec.yaml)
- Triggering project: `d:/src/contacts` (Saropa Contacts)
- Triggering file: `lib/components/contact/companion/contact_companion_list.dart:128` (build method), assignment at line 269 inside `onPressed: () => setStateSafe(() { _currentLimit = 0; })`

---

## Downstream Workaround

Until the fix lands, the downstream site carries a one-line `// ignore: require_late_initialization_in_init_state -- <rationale>` directive on the build method's `@override` line referencing this bug file.
