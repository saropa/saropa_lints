# PROPOSAL: Flag Suspicious `super.method()` Override Patterns

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `AvoidUnnecessarySuperRule` (`lib/src/rules/code_quality/unnecessary_code_rules.dart`)

---

## Summary

Add `avoid_suspicious_super_overrides` to flag an overriding method whose body calls `super.methodName()` with a **different** method name, argument count, or argument identity than the enclosing override — a strong signal of a copy-paste mistake (e.g. overriding `dispose()` but calling `super.initState()`, or calling `super.build(context)` with the wrong `context` variable in scope). This is distinct from the existing `AvoidUnnecessarySuperRule`, which flags a *redundant* super call that does nothing beyond the default — this new rule flags a super call that is present but *wrong*.

**Closes gap:** DCM `avoid-suspicious-super-overrides` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

Flutter's `State` lifecycle methods (`initState`, `dispose`, `didUpdateWidget`, `didChangeDependencies`) are commonly copy-pasted between classes, and it is easy to leave a stale `super.oldMethodName()` call behind after renaming an override, or to call the *wrong* lifecycle super method entirely (`super.initState()` inside an overridden `dispose()`), silently breaking the lifecycle contract without a compile error — `super.initState()` is a perfectly legal call from any method in the same class hierarchy. This has caused real dispose-leak and re-init bugs in Flutter apps. DCM ships this check as prior art specifically because the analyzer has no way to know an override "should" call its same-named super method.

---

## Detection / Behavior

For each `MethodDeclaration` that has `@override` (or is a recognized override via `InheritedElement` lookup) and contains a `SuperExpression`-target `MethodInvocation` in its body, flag when:
- The invoked super method's name **differs** from the enclosing override's name (e.g. overriding `dispose()`, calling `super.initState()`).
- OR the invoked super method's name **matches**, but the call's argument list has a different arity than the overriding method's own parameter list where a straight passthrough would be expected (heuristic signal of miswired parameters).

### Should flag (bad code)

```dart
class MyState extends State<MyWidget> {
  @override
  void dispose() {
    super.initState(); // LINT — dispose() override calls super.initState(), not super.dispose()
    _controller.dispose();
    super.dispose();
  }
}
```

### Should pass (good code)

```dart
class MyState extends State<MyWidget> {
  @override
  void dispose() {
    _controller.dispose();
    super.dispose(); // OK — super call matches the overriding method's own name
  }
}
```

---

## Proposed Tier

Tier: Recommended
Justification: This catches a real, silent lifecycle bug class (especially in Flutter `State` classes) with a low false-positive surface — the mismatched-name case is essentially always a mistake. It belongs above Essential only because it needs override/element resolution (not a purely syntactic check), matching where saropa places other override-correctness rules.

---

## Edge Cases

1. **Deliberately calling a *different* super lifecycle method for a documented reason** (rare but possible in mixin-heavy hierarchies) — should flag by default; document that a one-line `// ignore:` with rationale is the escape hatch per project convention.
2. **Multiple `super.` calls in the same override body, one matching and one not** (e.g. calling both `super.dispose()` and `super.initState()` for a mixin reset pattern) — should flag on the mismatched call specifically, not suppress the whole method.
3. **Override with no super call at all** — out of scope; already covered by Flutter's own `@mustCallSuper` analyzer diagnostic where applicable, not duplicated here.
4. **Non-lifecycle overrides** (plain method overriding calling a differently-named super method, e.g. `Comparable.compareTo` calling `super.hashCode`) — should flag using the same name-mismatch heuristic; not Flutter-specific.
5. **Argument-count heuristic on methods with optional/named parameters** — needs discussion; arity mismatch is a weaker signal than name mismatch and may need to start as name-only to avoid false positives, with arity as a stretch goal.

---

## Alternatives Considered

- **Limit to Flutter `State` lifecycle methods only** — rejected as too narrow; DCM's rule is language-general (any override calling a differently-named super method), and the same bug class shows up outside Flutter.
- **Only check arity/argument identity, skip name matching** — rejected; name mismatch is the strongest and lowest-false-positive signal and should ship first.

---

## Decision

---

## Implementation Notes

Element resolution needed to confirm the enclosing method is a genuine override (via `InheritanceManager3` or `element.overriddenElements` equivalent) — see existing override-aware rules for the resolution pattern already used in this codebase.

---

## Commits
