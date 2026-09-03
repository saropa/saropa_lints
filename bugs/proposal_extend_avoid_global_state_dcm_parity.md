# PROPOSAL: Extend `avoid_global_state` with Context-Aware Suspicious-Reference Detection

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_global_state`

---

## Summary

Extend `avoid_global_state` to also flag *specific suspicious references* to mutable global/top-level state from within functions and methods — not only the declaration of that state — matching DCM's context-aware `avoid-suspicious-global-reference`.

**Closes gap:** DCM `avoid-suspicious-global-reference` (dcm.dev) — currently PARTIAL via saropa's `avoid_global_state`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" PARTIAL matches table.

---

## Motivation

`AvoidGlobalStateRule` (`lib/src/rules/architecture/structure_rules.dart:451`, code `avoid_global_state`) only inspects top-level declarations:

```dart
context.addCompilationUnit((CompilationUnit node) {
  for (final CompilationUnitMember declaration in node.declarations) {
    if (declaration is TopLevelVariableDeclaration) {
      final VariableDeclarationList variables = declaration.variables;
      if (variables.isConst || variables.isFinal) continue;
      reporter.atNode(declaration);
    }
  }
});
```

It reports once at the `int globalCounter = 0;` declaration site and stops. It never inspects *how* that global is subsequently used. DCM's `avoid-suspicious-global-reference` is context-aware: it flags each individual reference site that is suspicious — for example, a global mutated from inside a widget's `build()` method (a rebuild-time side effect), a global read/written from inside an `async` callback without synchronization, or a global referenced from a `static` factory in a way that couples unrelated call sites. The current saropa rule gives one warning per global variable regardless of how many risky places touch it, and gives none at all for globals declared in files the rule already skipped past (e.g. a global declared `final` but holding a mutable collection, which is currently exempted entirely by `variables.isFinal`).

---

## Detection / Behavior

### Should flag (bad code)

```dart
int _requestCounter = 0; // existing: flagged at declaration

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    _requestCounter++; // LINT — mutates global state during a widget rebuild
    return Text('$_requestCounter');
  }
}

final List<String> _cache = []; // final binding, but mutable contents — currently exempted
void addToCache(String s) {
  _cache.add(s); // LINT — mutates a "final" global's contents from an arbitrary call site
}
```

### Should pass (good code)

```dart
final List<String> _defaults = const ['a', 'b']; // immutable contents — OK

class Repository {
  final List<String> _cache = []; // OK — encapsulated as instance state with controlled access
  void add(String s) => _cache.add(s);
}
```

---

## Proposed Tier

Tier: Recommended (unchanged — same tier as `avoid_global_state`, see `lib/src/tiers.dart:1602`)
Justification: Same architectural category and audience as the existing declaration check; the extension raises detection recall within the same problem space rather than introducing a new severity tier.

---

## Edge Cases

1. **Mutation inside `main()` for one-time app bootstrap** — should pass; a single assignment during startup (before any widget tree exists) is the accepted escape hatch and should not be flagged as "suspicious."
2. **Mutation inside a `build()` method** — should always flag; mutating state during a rebuild is a correctness hazard regardless of how the global was declared (`var`, or `final` holding a mutable collection).
3. **Mutation inside a test file (`test/`, `*_test.dart`)** — should pass; tests routinely reset shared fixtures and this is expected, matching the existing `ProjectContext.isTestFile` convention used elsewhere in the codebase.
4. **`final` top-level variable holding an immutable value (`const` literal, primitive)** — should continue to pass; only `final` variables whose declared type is a mutable collection (`List`, `Map`, `Set`) or a mutable custom class need the new "final but mutable contents" check.
5. **Reference from inside an `isolate` entry point** — should flag with a higher-confidence message, since isolates cannot safely share mutable global state at all (this is exactly the race-condition class DCM's rule targets).

---

## Alternatives Considered

- **Separate new rule** (`avoid_suspicious_global_reference`): rejected. The declaration-time and usage-time checks describe the same underlying hazard (shared mutable global state) and the existing rule's problem message already names the concrete harms ("hidden dependencies," "unreliable tests," "race conditions") that the new reference-site checks make concrete. Splitting into two rules would force users who already have `avoid_global_state` enabled to separately discover and enable a second rule to get equivalent DCM coverage, and would duplicate the correction guidance.

---

## Decision

<!-- Fill in when the proposal is accepted or declined -->

---

## Implementation Notes

Add a second pass in `AvoidGlobalStateRule.runWithReporter` (`lib/src/rules/architecture/structure_rules.dart:481`): collect top-level mutable variable names (including `final` variables whose static type is `List`/`Map`/`Set`/a known-mutable class — this will need `usesTypeResolution = true`, currently `false` at line 468), then register `context.addAssignmentExpression`/`context.addMethodInvocation` visitors scoped to `MethodDeclaration`s that override `build()` (via `InterfaceElement` supertype check) or the `test`/`test/` file heuristic, reporting each suspicious reference site individually. Reference: `lib/src/rules/architecture/structure_rules.dart:451`.

---

## Commits

<!-- Add commit hashes as implementation lands -->
