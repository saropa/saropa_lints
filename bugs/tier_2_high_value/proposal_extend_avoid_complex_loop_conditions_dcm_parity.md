# PROPOSAL: Extend `avoid_complex_loop_conditions` with an Unmodified-Loop-Condition Check

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_complex_loop_conditions`

---

## Summary

Extend `avoid_complex_loop_conditions` to also flag loops whose condition variables are never mutated anywhere inside the loop body — a staleness/infinite-loop risk distinct from the existing operator-count complexity check — matching DCM's `avoid-unmodified-loop-condition`.

**Closes gap:** DCM `avoid-unmodified-loop-condition` (dcm.dev) — currently PARTIAL via saropa's `avoid_complex_loop_conditions`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" PARTIAL matches table.

---

## Motivation

`AvoidComplexLoopConditionsRule` (`lib/src/rules/code_quality/code_quality_control_flow_rules.dart:26`, code `avoid_complex_loop_conditions`) measures a purely syntactic complexity metric — the count of `&&`/`||` operators in the condition expression:

```dart
void _checkCondition(Expression condition, SaropaDiagnosticReporter reporter) {
  final int operatorCount = _countLogicalOperators(condition);
  if (operatorCount > _maxOperators) {
    reporter.atNode(condition);
  }
}
```

It never inspects the loop *body*. A `while (isRunning)` condition has an operator count of zero and will never trigger this rule, yet if `isRunning` is never reassigned anywhere inside the loop body (and never captured/mutated via a passed-in mutable reference the analyzer can see), the loop cannot terminate through normal execution — it either infinite-loops or relies on an external mechanism (another isolate, a signal handler) the reader cannot see locally, which is exactly the readability/correctness hazard DCM's `avoid-unmodified-loop-condition` targets. This is orthogonal to condition complexity: a *simple* condition that is *never modified* is arguably a stronger signal of a bug than a complex one that clearly is being updated.

---

## Detection / Behavior

### Should flag (bad code)

```dart
void run() {
  bool isRunning = true;
  while (isRunning) { // LINT — `isRunning` never reassigned inside the loop body
    doWork();
  }
}

void countUp() {
  int i = 0;
  for (; i < 10;) { // LINT — `i` never mutated in the condition or body
    print('waiting');
  }
}
```

### Should pass (good code)

```dart
void run() {
  bool isRunning = true;
  while (isRunning) {
    isRunning = _checkShouldContinue(); // OK — condition variable is mutated in the body
  }
}

for (int i = 0; i < 10; i++) { // OK — standard for-loop increment mutates the condition variable
  print(i);
}
```

---

## Proposed Tier

Tier: Professional (unchanged — same tier as `avoid_complex_loop_conditions`, see `lib/src/tiers.dart:2435`)
Justification: Same "loop termination reasoning" category as the existing check; the new detection is a sibling analysis over the same `WhileStatement`/`DoStatement`/`ForStatement` visitor registrations already in place, with comparable false-positive risk once external-mutation escape hatches (below) are respected.

---

## Edge Cases

1. **Condition variable mutated via a method call that could mutate captured state** (`while (isRunning) { controller.stop(); }` where `stop()` sets a field the closure captures) — should pass; the rule must treat any call on an object/closure that could plausibly reach the condition variable as a potential mutation, to avoid false positives on completion-callback and controller patterns. This means the check should look for *any* assignment to the condition variable OR any call that takes the condition variable's containing object as a target, not require a literal `isRunning = ...` assignment.
2. **Condition depends on a field of `this` mutated by another method** (`while (_shouldContinue) {...}` where `_shouldContinue` is set by a callback registered elsewhere) — should pass by default; fields are more likely to be mutated from outside the loop's lexical scope (e.g. a listener), so this check should be scoped to local variables only, not instance/top-level fields, to keep the detection precise and avoid flooding common reactive patterns with false positives.
3. **`break`/`return` inside the loop body as the only exit mechanism** — should pass; an unconditional `break` reachable on some path is a valid, common termination strategy and the rule must recognize it (scan for `BreakStatement`/`ReturnStatement` in the body) before flagging on condition-mutation absence alone.
4. **`for` loop where the increment clause itself mutates the condition variable** — should pass via the existing for-loop condition/increment coupling; this is the standard, always-safe case.
5. **`await`-ed async call inside the loop body whose side effect is invisible to the AST** (e.g. `await stream.first` implicitly stops the loop) — should pass; presence of any `await` expression in the body is a reasonable heuristic escape hatch since external completion cannot be proven statically.

---

## Alternatives Considered

- **Separate new rule** (`avoid_unmodified_loop_condition`): considered, since the detection technique (body-mutation search) is unrelated to the existing operator-counting technique. However, both checks answer the same underlying question users configure this rule for — "can I trust this loop's termination logic just by reading the condition?" — and keeping them under one rule id means a project that enables loop-condition scrutiny gets both the complexity signal and the staleness signal from a single toggle, matching how the existing rule's problem message already frames the category broadly ("difficult to reason about when the loop terminates").

---

## Decision

<!-- Fill in when the proposal is accepted or declined -->

---

## Implementation Notes

Add a `_checkUnmodified(Expression condition, Set<String> conditionVars, Statement body, SaropaDiagnosticReporter reporter)` helper alongside `_checkCondition` in `AvoidComplexLoopConditionsRule` (`lib/src/rules/code_quality/code_quality_control_flow_rules.dart:79`), called from the same `WhileStatement`/`DoStatement`/`ForStatement` visitors already registered at lines 60-76. Collect `SimpleIdentifier` names referenced in the condition, then walk the loop body with a `RecursiveAstVisitor` checking for `AssignmentExpression`/`PostfixExpression`/`PrefixExpression` targeting those names, or a `BreakStatement`/`ReturnStatement`/`await` escape hatch, before reporting. Reference: `lib/src/rules/code_quality/code_quality_control_flow_rules.dart:26`.

---

## Commits

<!-- Add commit hashes as implementation lands -->
