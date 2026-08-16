# Bug: `avoid_gradient_in_build` false-positive inside `AnimatedBuilder.builder` closures

**Status:** Fixed
**Rule:** `avoid_gradient_in_build`
**Severity:** False positive — requires `// ignore:` workaround at each call site

## Description

The rule flags every `LinearGradient` / `RadialGradient` / `SweepGradient` constructor found
inside any method named `build`, exempting only closures named `shaderCallback`
(`_paintTimeCallbackNames = {'shaderCallback'}`). This misses `AnimatedBuilder.builder` (and
`AnimatedWidget.build`) closures, which are functionally paint-time: they re-execute every
animation frame specifically so that animation-dependent constructor arguments (alignment,
colors, stops) can vary per tick.

A gradient whose `begin:` / `end:` / `colors:` depend on `AnimationController.value` *must*
be constructed inside the builder closure — caching it in State would defeat the animation.
The rule's intent (avoid allocating identical gradients 60×/s) does not apply here because
the gradient genuinely changes each frame.

## Reproduction

```dart
class _FooState extends State<Foo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: ...);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(          // <-- FALSE POSITIVE
              begin: Alignment(-1.0 + 2.0 * _c.value, 0),
              end: Alignment(1.0 + 2.0 * _c.value, 0),
              colors: [Colors.red, Colors.blue],
            ),
          ),
          child: child,
        );
      },
      child: const SizedBox(height: 3, width: double.infinity),
    );
  }
}
```

## Suggested fix

Add `'builder'` to `_paintTimeCallbackNames` — or better, walk up to the enclosing
`InstanceCreationExpression` and check whether its static type is `AnimatedBuilder` /
`AnimatedWidget` / `TweenAnimationBuilder`, exempting the closure argument in those cases.

## Affected call site

`lib/components/primitive/hero/accent_gradient_bar.dart` — suppressed with
`// ignore: saropa_lints/avoid_gradient_in_build` and a reference to this bug.

## Finish Report (2026-08-16)

### Defect

`avoid_gradient_in_build` flagged gradient constructors inside `AnimatedBuilder.builder` (and equivalent animation-builder) closures as build-time allocations. Those closures re-execute every animation frame with animation-dependent values, so the gradient intentionally varies per tick — hoisting it would defeat the animation.

### Fix

Added a second exemption gate to `_GradientVisitor.visitFunctionExpression` in `build_method_rules.dart`. When a `FunctionExpression` is the `builder:` named argument of an `AnimatedBuilder`, `ListenableBuilder`, or `TweenAnimationBuilder`, the visitor stops recursion into that closure body — same pattern as the existing `shaderCallback` gate.

The gate walks up the AST: `FunctionExpression` → `NamedExpression` (check arg name is `builder`) → `ArgumentList` → constructor call (check type name is in `_animationBuilderTypes`). Handles both `InstanceCreationExpression` (resolved / explicit `const`/`new`) and `MethodInvocation` (how the parser represents implicit-`new` calls before type resolution).

### Key design decision

Rather than adding `'builder'` to `_paintTimeCallbackNames` (too broad — would suppress the rule on `ListView.builder`, `PageView.builder`, etc.), the fix scopes the exemption to specific animation widget types. This preserves the rule's value for non-animation `builder:` closures.

### Test coverage

- 10 AST-level unit tests in `avoid_gradient_in_build_shadercallback_test.dart` (5 existing + 5 new): `AnimatedBuilder.builder` exempt, `TweenAnimationBuilder.builder` exempt, `ListenableBuilder.builder` exempt, non-animation `builder:` still fires, gradient outside the closure still fires.
- 2 new GOOD fixture examples in `avoid_gradient_in_build_fixture.dart`.
- Test mirror `_CountingGradientVisitor` updated to stay in sync with the real visitor.

### Hardening (post-review)

- Added `ListenableBuilder` and `ValueListenableBuilder` to `_animationBuilderTypes` — both share the same `builder:` re-runs-per-notification contract.
- Documented `AnimatedWidget.build` as a known limitation (requires type-hierarchy resolution, not just AST name matching).
- Added cross-reference comments to other animation-builder name sets in the codebase (`animation_rules.dart`, `compound_performance_patterns.dart`).

### Gate 3: closure-parameter-reference heuristic

Added a widget-name-independent gate: when a gradient constructor is inside a `builder:` closure and its arguments reference a parameter unique to that closure (not `context`/`child`/`_`), the gradient depends on closure-unique data and can't be hoisted. This catches custom animation builders not in the name list (e.g. `CustomAnimWidget(builder: (ctx, animValue, child) => gradient(colors: [animValue]))`).

Implementation: `_gradientDependsOnClosureParams` walks up to find the nearest `builder:` closure, collects its unique parameter names, then runs `_ParamRefChecker` (a `RecursiveAstVisitor`) over the gradient's arguments to check for references.

### Test coverage (final)

- 12 AST-level unit tests (5 existing + 7 new): ShaderCallback gate (5), AnimatedBuilder/TweenAnimationBuilder/ListenableBuilder widget-name gate (3), non-animation widget `builder:` still fires (1), gradient outside closure still fires (1), closure-param-reference gate exempt (1), closure-param-reference gate still fires when no reference (1).
- 2 GOOD fixture examples in `avoid_gradient_in_build_fixture.dart`.

### Files changed

- `lib/src/rules/widget/build_method_rules.dart` — `_animationBuilderTypes` set (4 widgets), `_isAnimationBuilderArg()`, `_gradientDependsOnClosureParams()`, `_findBuilderClosure()`, `_closureUniqueParams()`, `_ParamRefChecker` class
- `test/rules/widget/avoid_gradient_in_build_shadercallback_test.dart` — mirrored all gates + 7 new tests
- `example/lib/build_method/avoid_gradient_in_build_fixture.dart` — 2 GOOD examples
- `CHANGELOG.md` — entry under `[15.0.5]`
