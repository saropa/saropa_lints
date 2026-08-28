# Fix: avoid_future_in_build and pass_existing_future_to_future_builder detection gaps

Two existing lint rules — `avoid_future_in_build` (Essential tier) and `pass_existing_future_to_future_builder` (Essential tier) — were silently missing most violations in real projects. An audit of ~65 call sites in a production codebase found zero hits from either rule.

## Root Causes

### avoid_future_in_build (v2→v3)

`_FutureCreationVisitor` used a hardcoded name-prefix heuristic (`fetch`, `load`, `get`, `retrieve`, `download`, `upload`, `request`) to decide whether a method invocation was async. Any method not matching those prefixes — `contacts()`, `queryAll()`, `computeStats()`, `DatabaseIO.process()` — was invisible to the rule. The prefix list was removed; the visitor now flags ALL method invocations passed as the `future:` argument of a `FutureBuilder` inside a `build()` method.

Additionally, the visitor now detects non-deterministic `Future` constructors (e.g. `Future(() => ...)`) in `future:` arguments, while exempting `Future.value()` and `Future.error()` which are deterministic with no I/O.

The `??=` caching idiom (`_f ??= method()`) is naturally safe: in the AST, the `MethodInvocation`'s parent is `AssignmentExpression`, not `NamedExpression`, so the `parent is NamedExpression` guard never matches it.

### pass_existing_future_to_future_builder (v8→v9)

The rule previously flagged `Future.value()` and `Future.error()` constructors as violations. These are deterministic with no I/O and safe to call in `build()`. The rule now exempts them.

The cache-method exemption (`_isCacheMethodCall`) was evaluated for tightening but left unchanged. The broad heuristic (any private method call on a class with any `Future<T>?` field) was deliberately chosen to avoid the false positive documented in `plans/history/2026.06/2026.06.01/pass_existing_future_to_future_builder_false_positive_private_method_returning_cached_field.md`. Tightening to require method-name ↔ field-name overlap would reintroduce that FP for common naming patterns (field `_cache`, method `_load()`).

## Hardening

### Widget class detection broadened
Both `_isWidgetClass` methods in `async_rules.dart` were updated from exact-match (`StatelessWidget`, `StatefulWidget`, `contains('State')`) to suffix-match (`endsWith('Widget')`, `endsWith('State')`, `contains('State<')`). This catches third-party widget bases like `HookWidget`, `ConsumerWidget`, `ConsumerStatefulWidget`.

### FutureBuilder scoping
`_FutureCreationVisitor` now checks that the `future:` NamedExpression is inside a `FutureBuilder` constructor specifically, not any widget with a `future:` parameter. Prevents false positives on custom widgets.

### @cachedFuture annotation
New `package:saropa_lints/annotations.dart` exports a `@cachedFuture` annotation. `_isCacheMethodCall` checks for this annotation on the method declaration (AST-only, same-class resolution) before falling back to the heuristic. This gives users explicit control when their naming convention doesn't match the heuristic.

## Files Changed

- `lib/src/rules/core/async_rules.dart` — `_FutureCreationVisitor` rewritten, `_isWidgetClass` broadened, FutureBuilder scoping added
- `lib/src/rules/widget/widget_lifecycle_rules.dart` — `Future.value()`/`Future.error()` exemption, `@cachedFuture` annotation support
- `lib/annotations.dart` — new file: `@cachedFuture` annotation
- `CHANGELOG.md` — entries under [Unreleased]

## Finish Report (2026-08-27)

All 184 affected tests pass (async_rules_test: 104, widget_lifecycle_rules_test: 73, cache_method_test: 7). No fixture changes required — existing fixtures cover the behavioral contract. The proposal (`bugs/proposal_avoid_future_in_build.md`) was closed as duplicate and archived to `plans/history/2026.08/2026.08.27/`.
