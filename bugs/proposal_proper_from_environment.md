# PROPOSAL: Flag Non-Const `bool`/`int`/`String.fromEnvironment` Calls

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `proper_from_environment` to flag any invocation of `bool.fromEnvironment(...)`, `int.fromEnvironment(...)`, or `String.fromEnvironment(...)` that is not evaluated in a `const` context. These constructors exist specifically to read `--dart-define` build-time flags at compile time; used without `const`, they still compile and run, but silently lose the compile-time evaluation that is the entire point of the API.

**Closes gap:** pyramid_lint `proper_from_environment` (github.com/charlescyt/pyramid_lint). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`bool.fromEnvironment`, `int.fromEnvironment`, and `String.fromEnvironment` are `const` constructors by design — the Dart compiler resolves them at compile time using the `--dart-define=KEY=VALUE` values passed on the build command line, which enables two things a non-const call never gets: (1) genuine compile-time constant folding (the value becomes a literal baked into the compiled output), and (2) dead-code elimination — `if (const bool.fromEnvironment('ENABLE_DEBUG_PANEL'))` lets the compiler tree-shake the entire debug-only branch out of a release build. Writing `final debugEnabled = bool.fromEnvironment('ENABLE_DEBUG_PANEL');` without `const` is legal Dart — the call still executes and still reads the define — but it becomes an ordinary runtime call: no dead-code elimination, no constant folding, and (more subtly) it evaluates once per call site rather than being deduplicated as a shared constant, which can confuse readers into thinking the value might change at runtime when it never can. The bug is invisible in day-to-day testing since the correct value is still returned either way — only build-size and tree-shaking regress silently.

---

## Detection / Behavior

Flag any `MethodInvocation`/instance-creation of `bool.fromEnvironment`, `int.fromEnvironment`, or `String.fromEnvironment` (including their two-argument `defaultValue:` forms) that does not appear in a `const` context — i.e. not preceded by an explicit `const` keyword, and not inside a `const` constructor's initializer list, `const` collection literal, or a context where the surrounding declaration is implicitly const (e.g. a top-level `const` variable).

### Should flag (bad code)

```dart
void configureLogging() {
  final verboseLogging = bool.fromEnvironment('VERBOSE_LOGGING'); // LINT — not const; loses compile-time evaluation and dead-code elimination

  if (verboseLogging) {
    _enableVerboseLogging();
  }
}
```

### Should pass (good code)

```dart
void configureLogging() {
  const verboseLogging = bool.fromEnvironment('VERBOSE_LOGGING'); // OK — const context, resolved at compile time

  if (verboseLogging) {
    _enableVerboseLogging(); // OK — release builds can tree-shake this branch entirely when the define is false
  }
}
```

---

## Proposed Tier

Tier: Recommended
Justification: `fromEnvironment` misuse is a real, silent build-quality regression (lost tree-shaking, larger release binaries) that applies to any project using `--dart-define` build flags — a common and growing pattern for flavor/feature-flag configuration. It is not package-specific (pure Dart SDK API) and the fix is a one-word `const` addition, making it a low-noise, high-value addition suitable above Comprehensive.

---

## Edge Cases

1. **`bool.hasEnvironment('KEY')`** — a related but distinct SDK API; out of scope for this rule (it is boolean-only and separately const-sensitive — could be a future extension, not part of this proposal).
2. **`fromEnvironment` call assigned to a non-const top-level/static `final` variable** — should still flag; `final` alone does not trigger the compiler's constant-folding path.
3. **`fromEnvironment` call already wrapped in `const` via an enclosing `const` collection literal** (e.g. `const [bool.fromEnvironment('A'), bool.fromEnvironment('B')]`) — should pass; the const-ness is inherited from the enclosing literal.
4. **`fromEnvironment` call inside a non-const constructor body assigned to an instance field** — should flag; instance-level assignment in a constructor body cannot be const regardless, so this is a case where the developer should hoist the value to a top-level/static `const` instead — correction message should suggest this.
5. **Third-party wrapper functions that internally call `fromEnvironment`** — should pass at the call site of the wrapper (the rule can only see the literal `fromEnvironment` invocation itself, not indirect calls through a helper function); flag the invocation site inside the wrapper definition instead.

---

## Alternatives Considered

- **Also flag `Duration`/`double` "fromEnvironment"-style manual parsing patterns** (e.g. `int.parse(const String.fromEnvironment('TIMEOUT_MS'))`) — rejected for the initial rule; the const violation for the underlying `String.fromEnvironment` is already caught, and requiring the outer `int.parse` to be const too is a separate, weaker guarantee (parsing itself can't be const unless wrapped further) — out of scope to avoid overreach.
- **Warn instead of flag when `defaultValue:` is omitted** (separate concern: missing default) — rejected; conflates two unrelated issues (const-ness vs. default-value presence) into one rule. Missing `defaultValue:` could be a separate, smaller follow-up proposal if desired.

---

## Decision

---

## Implementation Notes

---

## Commits
