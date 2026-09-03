# PROPOSAL: Extend `banned_identifier_usage` to Cover Declaration Names, Not Just Usage Sites

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `banned_identifier_usage`

---

## Summary

Extend `banned_identifier_usage` to also match banned patterns against declaration names — class, method, and variable names as they are *declared*, not only against `SimpleIdentifier` usage sites — matching DCM's `avoid-banned-names`.

**Closes gap:** DCM `avoid-banned-names` (dcm.dev) — currently PARTIAL via saropa's `banned_identifier_usage`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" PARTIAL matches table.

---

## Motivation

`BannedUsageRule` (`lib/src/rules/code_quality/code_quality_avoid_rules.dart:4441`, code `banned_identifier_usage`) registers a single visitor:

```dart
context.addSimpleIdentifier((SimpleIdentifier node) {
  final name = node.name;
  for (final ban in entries) {
    if (!ban.matchesName(name)) continue;
    ...
    reporter.atNode(node);
    return;
  }
});
```

`SimpleIdentifier` fires at every reference to a name — including the declaration's own name token in most declaration contexts — but the rule was designed and documented (`See analysis_options_custom.yaml banned_usage for the configured reason`) around banning specific identifiers such as deprecated API symbols or forbidden helper functions, not around policing *new* declaration names. DCM's `avoid-banned-names` is explicitly a naming-convention gate: it flags when a **class, method, or variable is declared** with a banned name pattern (e.g. `temp`, `data`, `foo`, `Manager` suffix), independent of whether that name is ever referenced elsewhere. A project wants to stop a bad name from being *introduced* — the current rule only reliably fires when the name is *invoked/read*, and depending on `matchesName`'s pattern semantics (exact vs. regex) may not treat class/method declaration identifiers as a distinct, intentional category at all.

---

## Detection / Behavior

### Should flag (bad code)

```dart
// analysis_options_custom.yaml: banned_usage includes pattern "Manager" for classes
class UserManager { // LINT — declared class name matches banned pattern
  void temp() {} // LINT — declared method name matches banned pattern "temp"
}

void doStuff() {
  var data = fetchThings(); // LINT — declared variable name matches banned pattern "data"
}
```

### Should pass (good code)

```dart
class UserRepository { // OK — no banned pattern in the declared name
  void loadProfile() {} // OK
}

void doStuff() {
  var userProfiles = fetchThings(); // OK — descriptive name, no banned pattern
}
```

---

## Proposed Tier

Tier: Professional (unchanged — same tier as `banned_identifier_usage`, see `lib/src/tiers.dart:1836`)
Justification: Same opt-in, project-config-driven nature as the existing rule (`banned_usage` in `analysis_options_custom.yaml`); this is a detection-surface extension, not a new severity class.

---

## Edge Cases

1. **Parameter names** — should flag; DCM's declaration-name check applies to any declared binding, and a banned pattern in a parameter name is as much a naming violation as a local variable.
2. **Getter/setter names** — should flag using the method-name path; getters/setters are still `MethodDeclaration`s in the AST.
3. **Field names inherited via `@override`** — should pass; the name was declared in a superclass/interface the project does not control, so flagging the override would produce an unfixable diagnostic.
4. **Positional record field names** (`(int, String) x`) — should pass; record field names are structural, not declarations the author freely chooses in the same sense as a class/method/variable.
5. **Existing usage-site matching** — must remain unchanged; this proposal is additive (new declaration-node visitors), not a replacement of the current `SimpleIdentifier` visitor, so existing configs banning API usage (not just declarations) keep working.

---

## Alternatives Considered

- **Separate new rule** (`avoid_banned_declaration_names`): rejected. Both checks share the exact same configuration surface (`banned_usage_config.bannedUsageEntries` in `analysis_options_custom.yaml`) and the same `ban.matchesName(name)` pattern-matching helper. Splitting them would force users to configure and enable two rules to get DCM-equivalent coverage from one config block, and would duplicate the `configAliases`/problem-message wiring for no detection benefit — the two checks are two visitor registrations sharing one rule.

---

## Decision

<!-- Fill in when the proposal is accepted or declined -->

---

## Implementation Notes

Add `context.addClassDeclaration`, `context.addMethodDeclaration`, and `context.addVariableDeclaration` visitors alongside the existing `context.addSimpleIdentifier` one in `BannedUsageRule.runWithReporter` (`lib/src/rules/code_quality/code_quality_avoid_rules.dart:4471`), each checking the declared name token (`node.name.lexeme`) against the same `entries` list and reusing the existing `allowedFiles` exemption logic. Reference: `lib/src/rules/code_quality/code_quality_avoid_rules.dart:4441`.

---

## Commits

<!-- Add commit hashes as implementation lands -->
