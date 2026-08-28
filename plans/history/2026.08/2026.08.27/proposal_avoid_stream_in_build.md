# PROPOSAL: `avoid_stream_in_build` — Detect Stream creation inside build methods

**Status: Implemented**

Created: 2026-08-27
Type: New rule
Related rules: `avoid_future_in_build` (sibling proposal)

---

## Summary

Flag `StreamBuilder` widgets whose `stream:` argument is a method invocation (not a field reference), when the `StreamBuilder` is inside a `build()` method of a `StatelessWidget` or inside `build()` of a `StatefulWidget` without a matching cached field. This catches the pattern where a new Stream subscription is created on every rebuild.

---

## Motivation

Audit of `d:\src\contacts` found 2 `StreamBuilder` instances where the stream was created inline in `build()` — one in a `StatelessWidget` (new subscription every parent rebuild) and one in a nested builder callback (new subscription every outer-stream emission). Both cause unnecessary Drift watch re-subscriptions and potential UI flicker.

The correct pattern is to cache the Stream in a `State` field (via `initState`) and pass the cached field to `StreamBuilder`, recreating only in `didUpdateWidget` when inputs change.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Model>>(
      stream: DatabaseIO.watchAll(), // LINT — method invocation in build
      builder: (context, snapshot) => ListView(...),
    );
  }
}

// Nested builder — inner stream created on every outer emission
StreamBuilder<Outer>(
  stream: _outerStream,
  builder: (context, outerSnap) {
    return StreamBuilder<Inner>(
      stream: DatabaseIO.watchByIds(outerSnap.data!.ids), // LINT
      builder: (context, innerSnap) => Widget(...),
    );
  },
)
```

### Should pass (good code)

```dart
class _MyWidgetState extends State<MyWidget> {
  late final Stream<List<Model>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = DatabaseIO.watchAll();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Model>>(
      stream: _stream, // OK — field reference
      builder: (context, snapshot) => ListView(...),
    );
  }
}
```

---

## Proposed Tier

Tier: Recommended
Justification: Same rationale as `avoid_future_in_build` — creating a new Stream subscription on every rebuild causes unnecessary I/O and risks visual flicker. Streams are heavier than Futures (they hold open a database watcher) so the cost is higher.

---

## Edge Cases

1. **`Stream.value(x)` or `Stream.empty()`** — should pass (no I/O).
2. **Nested builder callbacks** — the inner `stream:` is technically not directly in `build()` but in a closure called from build. The rule should walk up through closures/callbacks to determine if the enclosing method is `build()`.
3. **`StatelessWidget`** — always flag method invocations in `stream:`, since there is no State to cache in.
4. **`StatefulWidget` with `??=` pattern** — `_stream ??= method()` should pass (caching idiom).

---

## Alternatives Considered

- **Lint only StatelessWidget usage** — misses the nested-builder case where even a StatefulWidget can create inline streams inside callbacks.

---

## Decision

Accepted and implemented as an enhancement to the existing `avoid_stream_in_build` rule (v2 → v3). The rule already detected `StreamController()` inside `build()`; v3 adds detection of `StreamBuilder(stream: method())` with safe-constructor and `??=` exclusions. Kept in the same rule rather than creating a separate one — both patterns cause the same problem (stream recreation on rebuild).

---

## Implementation Notes

Detection approach:
1. Register on `InstanceCreationExpression` where the type is `StreamBuilder`
2. Find the `stream:` named argument
3. Check if the argument expression is a `MethodInvocation` or `FunctionExpressionInvocation`
4. Walk up the AST through closures/builders to confirm we're inside a `build()` method
5. Exclude `??=` assignments and `Stream.value()`/`Stream.empty()` constructors

Could share infrastructure with `avoid_future_in_build` — both rules detect "async-source method invocation inside build's subtree."

---

## Commits

<!-- Add commit hashes as implementation lands -->

---

## Finish Report (2026-08-27)

The `avoid_stream_in_build` rule (v2) only detected `StreamController()` instantiation inside widget `build()` methods. The proposal identified a second, more common anti-pattern: passing a method invocation directly to `StreamBuilder(stream: method())`, which creates a new stream subscription on every rebuild.

### Changes

**Rule enhancement (`lib/src/rules/core/async_rules.dart`):**
- Added Pattern 2: a `_StreamInBuildVisitor` (RecursiveAstVisitor) walks the `build()` body, finds `StreamBuilder` instances, and flags method invocations passed to the `stream:` named argument.
- Safe constructors (`Stream.value()`, `Stream.empty()`, `Stream.fromIterable()`) are excluded — they involve no I/O and are deterministic.
- The `??=` caching idiom (`stream: _s ??= method()`) is excluded — the `AssignmentExpression` wrapper causes the value expression to fail the `is MethodInvocation` type check; `_unwrapAssignment` explicitly returns `null` for `??=` to make this intentional.
- Pattern 1 (StreamController detection) refactored into `_isInsideBuildMethod` for clarity; behavior unchanged.
- `_isWidgetClass` helper checks `StatelessWidget`, `StatefulWidget`, and `*State` supertypes (matches the sibling `AvoidFutureInBuildRule` pattern — duplication noted as future extraction candidate).
- Problem message bumped from `{v2}` to `{v3}`.

**Fixture (`example/lib/async/avoid_stream_in_build_fixture.dart`):**
- Three BAD cases: StreamController in build, StreamBuilder with inline method, nested builder with inner inline method.
- Five GOOD near-miss cases: cached field reference, Stream.value(), Stream.empty(), Stream.fromIterable(), `??=` caching idiom.
- `expect_lint` markers placed line-precisely above the violating expression.

**Review-driven corrections:**
- Removed dead `_isNullAwareAssignmentTarget` function — the `??=` exclusion was working by accident (type mismatch at the `is MethodInvocation` check, not via the dedicated function). Replaced with `_unwrapAssignment` that correctly handles the `AssignmentExpression` wrapper.
- Added missing fixture cases: `Stream.fromIterable()` and `??=` caching idiom.
- Fixed `expect_lint` placement on `BadStreamControllerWidget` (was above method signature, now above the violating `StreamController()` line).

**Hardening pass (post-review):**
- Extracted `isWidgetOrStateClass` and `isInsideBuildMethod` into `lib/src/target_matcher_utils.dart` as shared utilities — replaces private `_isWidgetClass` in both `AvoidStreamInBuildRule` and `AvoidFutureInBuildRule`. Uses `endsWith('Widget')` / `endsWith('State')` to cover third-party widget bases (HookWidget, ConsumerWidget, ConsumerState, etc.).
- Bumped `RuleCost` from `low` to `medium` — Pattern 2 adds a `RecursiveAstVisitor` walk of every widget build body.

### Not changed

- No quick fix added — the correct fix depends on whether the widget should be converted to StatefulWidget (for StatelessWidget cases) or just caching the stream (for StatefulWidget cases).
- 10+ other files across the codebase also have private `_isWidgetClass` / `_isInsideBuildMethod` duplicates — migrating those to the shared utility is a separate refactoring task.
