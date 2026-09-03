# PROPOSAL: `require_global_key_for_widget` — Flag Widgets That Need an Explicit GlobalKey

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Flag widgets whose state (via `RenderBox`, `RenderObject`, or `State`) is accessed elsewhere via `GlobalKey` lookups but which are not constructed with a `key:` argument, and — narrower and higher-confidence — flag a widget subtree passed to APIs that require a stable identity across parent rebuilds (e.g. `Navigator`, `Hero`, drag-and-drop reorder targets) without an explicit `GlobalKey`.

**Closes gap:** DCM `always-pass-global-key` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

Flutter widgets that need to be located from outside their build subtree — `Form` widgets validated via `formKey.currentState!.validate()`, `Scaffold`s opened via `scaffoldKey.currentState!.openDrawer()`, animation/measurement widgets read via `RenderBox` — silently fail at runtime if the corresponding `GlobalKey` is never actually attached to the widget's `key:` parameter. The compile-time type system cannot catch this: `final formKey = GlobalKey<FormState>();` compiles fine even if no `Form(key: formKey, ...)` exists anywhere in the file, and the failure only surfaces as a null-check crash at first use (`formKey.currentState!.validate()` throws `Null check operator used on a null value`).

This is a common category of "declared a key, forgot to wire it up" bug reported in Flutter community issue trackers. DCM ships `always-pass-global-key` for exactly this pattern. `saropa_lints` has no equivalent — a grep for `GlobalKey` across `lib/src/rules/` finds only incidental mentions inside other rules (forms, riverpod, lifecycle), none of which verify the key is actually attached to a widget constructor.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class LoginForm extends StatelessWidget {
  const LoginForm({super.key});

  @override
  Widget build(BuildContext context) {
    // formKey is declared and later dereferenced via currentState,
    // but never passed to the Form widget's `key:` parameter.
    final formKey = GlobalKey<FormState>(); // LINT
    return Column(
      children: [
        Form(
          child: TextFormField(
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
        ),
        ElevatedButton(
          onPressed: () => formKey.currentState!.validate(),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
```

### Should pass (good code)

```dart
class LoginForm extends StatelessWidget {
  const LoginForm({super.key});

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>(); // OK — attached below
    return Column(
      children: [
        Form(
          key: formKey,
          child: TextFormField(
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
        ),
        ElevatedButton(
          onPressed: () => formKey.currentState!.validate(),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
```

---

## Proposed Tier

Tier: Recommended
Justification: This catches a real runtime crash (null-check on `currentState`), not a style preference, so it belongs above Comprehensive/Pedantic. It stops short of Essential because detection is necessarily heuristic (see Edge Cases) — a state-management-heavy codebase that builds the key-bearing widget in a different file/build method than the read site can produce false negatives, and Essential is reserved for zero-ambiguity checks.

---

## Edge Cases

1. **Key declared and attached in different methods of the same class** (e.g. field-level `final _formKey = GlobalKey<FormState>();`, attached in `build()`) — should pass; requires tracking field-level `GlobalKey` declarations, not just local variables.
2. **Key passed through a parameter to a child widget that attaches it** — should pass but is hard to verify without cross-file/cross-widget flow analysis; scope the rule to same-file, same-class detection only and accept this as a known false-negative class (documented, not silently over-flagged).
3. **Key created but genuinely unused** (dead code) — a separate concern already partially covered by the Dart analyzer's unused-variable diagnostics; this rule should not duplicate that check, only flag "used via `.currentState`/`.currentContext` but never attached."
4. **`GlobalObjectKey` and other `GlobalKey` subclasses** — should be treated the same as `GlobalKey`.
5. **`ValueKey`/`ObjectKey`/`UniqueKey`** — out of scope; this rule targets only `GlobalKey` and subtypes, since only `GlobalKey` exposes `currentState`/`currentContext`/`currentWidget`.

---

## Alternatives Considered

- **Flag every `GlobalKey` declaration missing a paired `key:` argument anywhere in the class** (not just when `.currentState` is dereferenced) — rejected as too broad; a `GlobalKey` stored for later conditional use (e.g. assigned in an `if` branch) would false-positive constantly. Requiring an observed `.currentState`/`.currentContext`/`.currentWidget` read gives higher-precision evidence that the key is meant to be attached now.
- **Whole-program flow analysis for cross-file key passing** — rejected as infeasible at the AST-visitor level `saropa_lints` uses (see `SaropaLintRule`/`SaropaContext` in `lib/src/saropa_lint_rule.dart`); scoped to same-class detection instead, per Edge Case 2.

---

## Decision

Not yet decided.

---

## Implementation Notes

Candidate home: `lib/src/rules/widget/forms_rules.dart` (existing `GlobalKey`-adjacent form rules) or a new rule in `lib/src/rules/widget/widget_patterns_require_rules.dart` alongside other `require_*`-named rules (see `RequireTextOverflowHandlingRule` for the sibling naming/structure pattern — `LintImpact`, `RuleType.codeSmell`, `applicableFileTypes: {FileType.widget}`).

---

## Commits

None yet.
