# PROPOSAL: Flag `exit()` Calls Outside `main()`

**Status: Implemented**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `avoid_exit_outside_entrypoint` to flag calls to `dart:io`'s `exit()` from anywhere other than the top-level `main()` function — calling `exit()` deep inside application logic (a service, a widget callback, a helper function) terminates the entire process immediately, skips `finally` blocks, and bypasses any cleanup, making it untestable and a landmine for anyone who calls that code path indirectly.

**Closes gap:** many_lints `avoid_exit_outside_entrypoint`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`exit()` is a blunt instrument: it terminates the VM immediately, without running pending `finally` blocks, stream close handlers, or async cleanup. Calling it from anywhere but the program's entrypoint hides a process-kill inside what looks like ordinary logic, and any test or caller that exercises that code path takes the whole test runner down with it.

---

## Detection / Behavior

Flag any `MethodInvocation` of `exit(...)` (from `dart:io`) whose enclosing function is not the top-level `main` function of the entrypoint file.

### Should flag (bad code)

```dart
void validateConfig(Config config) {
  if (!config.isValid) {
    exit(1); // LINT — exit() outside main(), skips cleanup, untestable
  }
}
```

### Should pass (good code)

```dart
void main(List<String> args) {
  final config = loadConfig(args);
  if (!config.isValid) {
    exit(1); // OK — top-level entrypoint
  }
}
```

---

## Proposed Tier

Tier: Recommended
Justification: A process-killing call hidden away from the entrypoint is a real correctness/testability hazard in any CLI or server-side Dart package, not just a style nit.

---

## Edge Cases

1. **`exit()` inside a function called directly and only from `main()`** — needs discussion; a strict AST-scope check (enclosing function literal is `main`) is simplest and most predictable, even though it will flag a one-line helper that only `main` calls. Document this as by-design.
2. **`exit()` inside a test file (`test/*.dart`)** — should flag; tests should use `expect`/`throwsA`, never terminate the runner.
3. **Flutter app code (no `dart:io` `exit` available on web/relevant platforms)** — should pass silently if `exit` is unresolved/unavailable; rely on type resolution to confirm it's `dart:io`'s `exit`, not a user-defined function named `exit`.
4. **`Isolate.exit()`** — should pass; different semantics (terminates only the isolate, can carry a result), out of scope for this rule.

---

## Alternatives Considered

- **Ban `exit()` entirely** — rejected; CLI tools legitimately need it at the entrypoint to set a non-zero exit code.

---

## Decision

---

## Implementation Notes

- Rule class: `AvoidExitOutsideEntrypointRule` in `lib/src/rules/flow/control_flow_rules.dart`
- Tier: Recommended (WARNING severity)
- Detection: flags bare `exit()` calls (no target) outside top-level `main()` function
- Uses `requiredPatterns => {'exit'}` for cheap pre-filter
- `Isolate.exit()` passes because it has a target (`node.target != null`)
- AST walk checks `FunctionDeclaration.name.lexeme == 'main'` with `parent is CompilationUnit`

---

## Commits
