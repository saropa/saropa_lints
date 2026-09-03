# PROPOSAL: Extend `avoid_unassigned_late_fields` to Cover Unassigned Local Variables

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_unassigned_late_fields`

---

## Summary

Extend `avoid_unassigned_late_fields` to also flag local variables that are declared without an initializer and then read before any assignment reaches them along some code path, matching DCM's `avoid-unassigned-local-variable`.

**Closes gap:** DCM `avoid-unassigned-local-variable` (dcm.dev) — currently PARTIAL via saropa's `avoid_unassigned_late_fields`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" PARTIAL matches table.

---

## Motivation

`AvoidUnassignedLateFieldsRule` (`lib/src/rules/code_quality/code_quality_variables_rules.dart:1672`, code `avoid_unassigned_late_fields`) is scoped exclusively to class fields:

```dart
context.addClassDeclaration((ClassDeclaration node) {
  ...
  for (final ClassMember member in node.bodyMembers) {
    if (member is FieldDeclaration && member.fields.isLate) {
      for (final VariableDeclaration variable in member.fields.variables) {
        if (variable.initializer == null) {
          lateFields[variable.name.lexeme] = variable.name;
        }
      }
    }
  }
  // then scans constructors/methods for assignments to lateFields
});
```

It walks `ClassDeclaration.bodyMembers` and only considers `late` fields. It never visits function/method bodies looking for local `VariableDeclarationStatement`s with no initializer. Dart's own analyzer already prevents *reading* a definitely-unassigned local via flow analysis in most cases (`used before it's initialized`), but that compiler error only fires on code paths the analyzer can prove always read before write — it does not fire for locals that are provably assignable-but-conditionally-unassigned in a way DCM's rule additionally flags as a readability/maintainability smell (e.g., a local declared far from its first assignment, or assigned only inside one branch of a multi-branch conditional while read unconditionally afterward through a path the compiler's flow analysis cannot fully rule out without `late`).

---

## Detection / Behavior

### Should flag (bad code)

```dart
void process(bool condition) {
  String result; // LINT — declared without initializer
  if (condition) {
    result = 'yes';
  }
  // no assignment on the `else` path
  print(result); // read reachable without any assignment on some path
}
```

### Should pass (good code)

```dart
void process(bool condition) {
  String result = condition ? 'yes' : 'no'; // OK — always assigned
  print(result);
}

void processLate() {
  String result; // OK — every path assigns before the read
  result = fetchValue();
  print(result);
}
```

---

## Proposed Tier

Tier: Recommended (unchanged — same tier as `avoid_unassigned_late_fields`, see `lib/src/tiers.dart:1620`)
Justification: Same "runtime crash risk from unassigned binding" category as the existing field check; local variables carry the equivalent risk (a `LateError`/`used before it's initialized` failure) and the detection cost is comparable (single-function-body scan vs. single-class scan).

---

## Edge Cases

1. **Variable read-before-write already rejected by the Dart compiler** (definite-assignment analysis) — should pass; this proposal must not duplicate diagnostics the analyzer already emits as compile errors. The rule should only fire on patterns the compiler's flow analysis does not already reject (e.g., a `late` local declared without initializer, or a non-`late` local the compiler happens to allow via a narrow provable-path guarantee that is still fragile/hard-to-read).
2. **`late` local variables specifically** (`late String result;` inside a function body) — should flag directly; these bypass the compiler's definite-assignment check entirely (that is exactly why `late` exists) and are the clearest DCM-equivalent case, structurally identical to the existing late-field check.
3. **Variable assigned in every branch of an exhaustive `switch`** — should pass; the rule must understand exhaustive switch coverage, not just "some assignment exists somewhere."
4. **Variable declared and used only inside a loop where the first iteration always assigns before any read** — should pass; avoid flagging idiomatic accumulator patterns.
5. **Field declarations** — remain covered by the existing, unmodified late-field logic; this proposal only adds a parallel local-variable check, it does not change field handling.

---

## Alternatives Considered

- **Separate new rule** (`avoid_unassigned_local_variable`): rejected. The local-variable and late-field checks solve the same problem (a declared binding that can be read before it holds a value) using the same core technique — collect declarations without initializers, then verify every reachable read is preceded by an assignment — differing only in which AST scope (class body vs. function body) is scanned. Extending keeps one rule id and one problem-message/correction-message pair covering "unassigned binding" end-to-end, matching how the existing rule's message already generalizes ("Accessing an unassigned ... field throws ... at runtime") to a wording that applies equally to locals.

---

## Decision

<!-- Fill in when the proposal is accepted or declined -->

---

## Implementation Notes

Add a `context.addBlockFunctionBody`/`context.addMethodDeclaration` visitor in `AvoidUnassignedLateFieldsRule.runWithReporter` (`lib/src/rules/code_quality/code_quality_variables_rules.dart:1699`) that collects local `VariableDeclarationStatement`s with no initializer (prioritizing `late` locals, which bypass compiler definite-assignment checking entirely), then reuses an assignment-tracking visitor modeled on the existing `_FieldAssignmentVisitor` (line 1638) scoped to the enclosing function body instead of the enclosing class. Reference: `lib/src/rules/code_quality/code_quality_variables_rules.dart:1672`.

---

## Commits

<!-- Add commit hashes as implementation lands -->
