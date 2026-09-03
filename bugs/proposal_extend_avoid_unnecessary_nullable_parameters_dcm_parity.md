# PROPOSAL: Extend `avoid_unnecessary_nullable_parameters` to Fields, Return Types, and Local Variables

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_unnecessary_nullable_parameters`

---

## Summary

Extend `avoid_unnecessary_nullable_parameters` to also sweep unnecessarily-nullable field types, return types, and local variable declarations — not just function/method parameters — matching DCM's `prefer-non-nulls`, which is a general nullability sweep across all four declaration kinds.

**Closes gap:** DCM `prefer-non-nulls` (dcm.dev) — currently PARTIAL via saropa's `avoid_unnecessary_nullable_parameters`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" PARTIAL matches table.

---

## Motivation

`lib/src/rules/code_quality/code_quality_variables_rules.dart:826-886` implements `AvoidUnnecessaryNullableParametersRule`. Reading the actual body reveals it is scoped to parameters **and currently never reports anything at all** — the detection loop is a documented stub:

```dart
context.addFunctionDeclaration((FunctionDeclaration node) {
  final FormalParameterList? params = node.functionExpression.parameters;
  if (params == null) return;

  for (final FormalParameter param in params.parameters) {
    TypeAnnotation? type;
    if (param is SimpleFormalParameter) {
      type = param.type;
    } else if (param is DefaultFormalParameter) {
      final FormalParameter normalParam = param.parameter;
      if (normalParam is SimpleFormalParameter) {
        type = normalParam.type;
      }
    }

    if (type == null) continue;

    // Check if nullable
    if (type.question != null) {
      // This is a simplified heuristic
      // Full implementation would analyze call sites
    }
  }
});
```

There is no `reporter.atNode(...)` call anywhere in this method — the `if (type.question != null)` branch is empty. This proposal's scope (fields/returns/locals) is additive regardless, but implementers should be aware the parameter-only baseline this extension builds on needs its own call-site analysis implemented first (or concurrently) for the rule to fire at all; that is a prerequisite bug, not something this proposal's Detection/Behavior section re-specifies. DCM's `prefer-non-nulls` sweeps four declaration kinds — parameters, fields, return types, and local variables — flagging any of them declared nullable (`T?`) when nothing in the analyzable surface (assignments, returns, call sites) ever actually produces or requires `null`. Unnecessary nullability forces every read site to add defensive null checks (`if (x != null)`, `x!`, `x ?? fallback`) for a case that structurally cannot occur, which is exactly the noise `avoid_unnecessary_nullable_parameters`'s own problem message already argues against for parameters — the same argument applies unchanged to fields, returns, and locals.

## Detection / Behavior

### Should flag (bad code)

```dart
class Repository {
  // Field never assigned null, never read for a null case — LINT
  User? _cachedUser;

  Repository() : _cachedUser = User.guest();

  // Return type nullable but every path returns a non-null User — LINT
  User? getUser() {
    return _cachedUser ?? User.guest();
  }

  void load() {
    // Local declared nullable but immediately assigned and never reassigned
    // to null or checked for null before use — LINT
    User? user = User.guest();
    print(user.name);
  }
}
```

### Should pass (good code)

```dart
class Repository {
  User? _cachedUser; // OK — assigned null in at least one code path (e.g. clear())

  void clear() {
    _cachedUser = null;
  }

  User? getUser() {
    return _cachedUser; // OK — genuinely may be null before first load
  }

  void load() {
    User? user; // OK — starts null, guarded before use
    if (_shouldLoad) user = User.guest();
    if (user != null) print(user.name);
  }
}
```

## Proposed Tier

Tier: Professional

Justification: keep parity with the existing rule's tier — `avoid_unnecessary_nullable_parameters` is in `professionalOnlyRules` (`lib/src/tiers.dart` line 2528). Nullability sweeps across fields/returns/locals require the same call-site/assignment analysis depth (and the same false-positive risk without full flow analysis) as the parameter case, so the audience and severity expectations should match.

## Edge Cases

1. **Fields assigned `null` in any constructor, setter, or method body** — must NOT flag; the field is genuinely nullable. Requires scanning the whole class body for any assignment of a `null` literal (or a nullable-typed expression) to the field, not just the declaration site.
2. **Return types where at least one `return` statement (including implicit `null` fall-through, or an early `return null;`/`return;` in a non-void async function) can produce `null`** — must NOT flag. Requires walking all `ReturnStatement`/`ReturnExpression` nodes in the function body, mirroring how `avoid_unnecessary_nullable_parameters` would need to walk call sites.
3. **Local variables declared without an initializer and assigned later inside a conditional** (`User? user; if (cond) user = ...;`) — the declaration is legitimately nullable if it can be read before the conditional assignment; must NOT flag unless flow analysis can prove the variable is always assigned non-null before any read.
4. **Overridden methods/fields (`@override`)** — return-type nullability on an override must match the overridden member's signature; the rule must NOT recommend narrowing a return type in a way that breaks the override contract, so overridden members should be excluded or checked against the supertype's signature.
5. **Public API members (exported library members, public class fields/methods)** — narrowing a public field/return type is a breaking API change for downstream consumers; consider excluding `library` (non-`_`-prefixed, exported) members from local-only tightening, or downgrade severity for public surface vs. private/local scope, since the existing parameter rule's message already frames the risk as "if null support is needed for future callers, add it when the requirement actually arises" — public APIs are the case most likely to need forward compatibility.
6. **Late final fields (`late final T? x;`)** — nullability combined with `late` has different semantics (deferred initialization, not "may be null"); the sweep should recognize `late` and either exclude it or apply a distinct check consistent with the project's `avoid_unassigned_late_fields` rule (see `plans/GAP_ANALYSIS.md`'s adjacent PARTIAL row) to avoid double-flagging the same field from two different rules with conflicting guidance.

## Alternatives Considered

- **New standalone rule** (`prefer_non_nullable_declarations`) covering fields/returns/locals, leaving parameters alone in the existing rule — considered, since the AST entry points differ substantially (`FieldDeclaration`, `MethodDeclaration.returnType`, `VariableDeclarationStatement` vs. `FormalParameterList`). This proposal keeps it as one extended rule to match DCM's single `prefer-non-nulls` rule id and this batch's Related-rules parity framing; if the four checks prove to have very different false-positive rates in practice, split by declaration kind as a follow-up rather than gating the whole extension on getting all four right at once.
- **Full dataflow/nullability analysis (never-null-narrowing via the analyzer's type-promotion engine)** — would be the most accurate approach but is a much larger investment than an AST sweep; start with the same call-site/assignment-literal heuristic style the parameter rule already documents wanting ("Full implementation would analyze call sites"), and treat true flow-sensitive analysis as a stretch goal.

---

## Decision

---

## Implementation Notes

Implement (or finish implementing — see Motivation) the parameter call-site analysis first, since the extension shares its core helper (`_isNullEverAssignedOrReturned`-style check) across all four declaration kinds. Add `context.addFieldDeclaration`, extend the existing `context.addFunctionDeclaration`/`addMethodDeclaration` callbacks to also inspect `returnType`, and add `context.addVariableDeclarationStatement` (or equivalent) for locals, all in `lib/src/rules/code_quality/code_quality_variables_rules.dart` near `AvoidUnnecessaryNullableParametersRule`.

---

## Commits
