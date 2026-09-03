# PROPOSAL: Extend `avoid_always_null_parameters` to Flag Always-Null Local Variables

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_always_null_parameters`

---

## Summary

Extend `avoid_always_null_parameters` to also flag local variables that are declared and never assigned anything other than `null` throughout their lifetime, matching DCM's `avoid-always-null-variables`.

**Closes gap:** DCM `avoid-always-null-variables` (dcm.dev) — currently PARTIAL via saropa's `avoid_always_null_parameters`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" PARTIAL matches table.

---

## Motivation

`avoid_always_null_parameters` (`lib/src/rules/code_quality/code_quality_avoid_rules.dart:2000`) only inspects call sites — it walks `MethodInvocation` and `InstanceCreationExpression` argument lists and flags any `NamedExpression` whose value is a `NullLiteral`:

```dart
context.addMethodInvocation((MethodInvocation node) {
  for (final Expression arg in node.argumentList.arguments) {
    if (arg is NamedExpression && arg.expression is NullLiteral) {
      reporter.atNode(arg);
    }
  }
});
```

This never inspects local variable declarations. A local declared `nullable` and only ever set to `null` (never reassigned to a real value) is dead weight — its type could be simplified, the variable is very likely vestigial from a refactor, or it signals a bug where an assignment was accidentally dropped. DCM's `avoid-always-null-variables` catches this class directly; saropa currently has no local-variable equivalent.

---

## Detection / Behavior

### Should flag (bad code)

```dart
void process() {
  String? result = null; // LINT — declared null, never reassigned to a real value
  if (someCondition) {
    print(result); // still null here, no other assignment exists anywhere in scope
  }
}

void loadUser() {
  User? cachedUser; // LINT — implicitly null, no assignment anywhere in the enclosing scope
  return cachedUser?.name;
}
```

### Should pass (good code)

```dart
void process() {
  String? result;
  if (someCondition) {
    result = fetchValue(); // OK — assigned a non-null value somewhere in scope
  }
  print(result);
}

void loadUser() {
  User? cachedUser = _cache.lookup(id); // OK — initializer is not a null literal
}
```

---

## Proposed Tier

Tier: Professional (unchanged — same tier as `avoid_always_null_parameters`, see `lib/src/tiers.dart:2426`)
Justification: This is the same class of "dead code smell" issue as the existing parameter check — low severity, opt-in beyond Recommended, no false-positive risk once the "any real assignment anywhere in scope" analysis is correct.

---

## Edge Cases

1. **Variable reassigned inside a closure/callback captured later** — should pass; the rule must track assignments across the whole enclosing function body, not just the declaration statement.
2. **Variable assigned only inside a branch that is provably dead (e.g. `if (false)`)** — should still pass; this rule does not do constant-folding/reachability analysis, only lexical assignment-search, to avoid false positives.
3. **`late` variables with no initializer** — out of scope; covered separately by `avoid_unassigned_late_fields` (fields) and the sibling local-variable proposal (`proposal_extend_avoid_unassigned_late_fields_dcm_parity.md`) which addresses "never assigned" rather than "always null."
4. **Field declarations (not locals)** — out of scope for this proposal; only `VariableDeclarationStatement` locals inside function/method bodies are in scope, to keep the extension symmetric with the existing parameter-only rule's narrow, function-body-local nature.
5. **Variable declared `final`/`const` and initialized to `null`** — should flag; a `final` local always null is unambiguously dead and cannot be "fixed" by a later assignment, making it an even stronger signal than the mutable case.

---

## Alternatives Considered

- **Separate new rule** (`avoid_always_null_locals`): rejected. The parameter and local-variable cases share the same underlying smell ("this binding never holds anything but null") and the same fix guidance ("remove it or document why null has meaning"). Splitting them would duplicate the problem message, correction message, and tags, and would force users to opt two rules in/out together for no practical benefit. Extending the existing rule keeps one rule id, one config knob, and one changelog entry to track.

---

## Decision

<!-- Fill in when the proposal is accepted or declined -->

---

## Implementation Notes

Add a `context.addVariableDeclarationStatement` (or walk `FunctionBody` via `context.addBlockFunctionBody`) visitor that, for each local `VariableDeclaration`, checks (a) the initializer is `null` or absent, and (b) no `AssignmentExpression` elsewhere in the enclosing function body assigns a non-null value to that variable name (reuse the `_FieldAssignmentVisitor`-style pattern already used by `AvoidUnassignedLateFieldsRule` in `lib/src/rules/code_quality/code_quality_variables_rules.dart:1638`). Reference: `lib/src/rules/code_quality/code_quality_avoid_rules.dart:2000`.

---

## Commits

<!-- Add commit hashes as implementation lands -->
