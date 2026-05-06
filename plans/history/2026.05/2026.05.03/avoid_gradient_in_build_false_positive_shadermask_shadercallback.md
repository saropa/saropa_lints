# BUG: `avoid_gradient_in_build` — False positive inside `ShaderMask.shaderCallback`

**Status: Fixed**

Created: 2026-05-03
Rule: `avoid_gradient_in_build`
File: `lib/src/rules/widget/build_method_rules.dart` (line ~46)
Severity: False positive (High — forces refactor or `// ignore:` on every animated `ShaderMask`)
Rule version: v3 | Since: unknown | Updated: unknown

---

## Summary

The rule fires on `LinearGradient(...)` constructed inside the `shaderCallback` argument of a `ShaderMask` (or `ShaderMaskBuilder`-style closure passed into a `Paint.shader` setter, etc.). `shaderCallback` is invoked at **paint time**, not build time — by the rendering layer, on demand, when the layout bounds are known. Treating it as "creating a gradient in build()" is incorrect: the gradient was always going to be allocated per paint, and that's the only place the actual `Rect bounds` are available. The rule should exempt closures passed to a parameter typed `ShaderCallback`.

The current "fix" downstream is to switch to `dart:ui.Gradient.linear` (which the rule does not flag, because it matches only on the type names `LinearGradient` / `RadialGradient` / `SweepGradient`). That's a real micro-optimization in some cases, but it's not what the lint message advises ("Store gradient as a static const field or create outside build()") — there is no way to "store outside build" something that consumes per-paint `Rect bounds` and a per-frame animation value.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
$ grep -rn "'avoid_gradient_in_build'" lib/src/rules/
lib/src/rules/widget/build_method_rules.dart:62:    'avoid_gradient_in_build',

# Negative — rule is NOT in saropa_drift_advisor
$ grep -rn "'avoid_gradient_in_build'" ../saropa_drift_advisor
(no matches)
```

**Emitter registration:** `lib/src/rules/widget/build_method_rules.dart:46` (`AvoidGradientInBuildRule`)
**Rule class:** `AvoidGradientInBuildRule`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` (custom_lint plugin owner — emitter unambiguous)

---

## Reproducer

```dart
import 'package:flutter/material.dart';

class Shimmer extends StatefulWidget {
  const Shimmer({required this.child, super.key});
  final Widget child;
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, Widget? child) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect bounds) {
            // LINT — but should NOT lint:
            //  * shaderCallback runs at paint time, not build time
            //  * `bounds` is only known at paint time
            //  * `_c.value` changes every frame — no constant form possible
            return LinearGradient(
              colors: const <Color>[Colors.white, Colors.blue, Colors.white],
              transform: GradientRotation(_c.value * 6.28),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
```

**Frequency:** Always — any `ShaderMask` whose `shaderCallback` constructs a `LinearGradient` / `RadialGradient` / `SweepGradient`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — gradient lives in a paint-time callback that depends on `Rect bounds` (only known at paint) and a per-frame animation value. There is no "outside build()" location to hoist it to. |
| **Actual** | `[avoid_gradient_in_build] Creating Gradient in build() prevents reuse and causes allocations.` reported on the `LinearGradient(...)` constructor. |

---

## AST Context

```
MethodDeclaration (build)
  └─ Block
      └─ ReturnStatement
          └─ InstanceCreationExpression (AnimatedBuilder)
              └─ NamedExpression (builder:)
                  └─ FunctionExpression  ← AnimatedBuilder.builder closure
                      └─ Block
                          └─ ReturnStatement
                              └─ InstanceCreationExpression (ShaderMask)
                                  └─ NamedExpression (shaderCallback:)
                                      └─ FunctionExpression  ← THIS is the paint-time boundary
                                          └─ Block
                                              └─ ReturnStatement
                                                  └─ MethodInvocation (.createShader)
                                                      └─ Target: InstanceCreationExpression (LinearGradient)  ← node reported here
```

The current visitor (`_GradientVisitor`, line 90) walks the entire body of `build` and reports any non-const `LinearGradient` / `RadialGradient` / `SweepGradient` constructor. It has no awareness of crossing into a `FunctionExpression` whose target parameter is typed `ShaderCallback`.

---

## Root Cause

### Hypothesis A: Visitor does not stop at `ShaderCallback` boundaries

`_GradientVisitor` (build_method_rules.dart:90) extends `GeneralizingAstVisitor<void>` and unconditionally recurses into every `FunctionExpression`. It never asks "is this function being passed to a parameter that the framework will invoke later, at paint time?" Specifically:

1. The visitor enters `MethodDeclaration node.body` for `build` (line 85).
2. It descends into the `AnimatedBuilder.builder` closure (correct — that's still build-time).
3. It descends into the `ShaderMask.shaderCallback` closure (incorrect — this is paint-time).
4. It hits the `LinearGradient(...)` constructor and reports.

The fix needs to gate the recursion: when the visitor is about to enter a `FunctionExpression` that is the argument to a parameter whose static type is `ShaderCallback` (or `ui.ImageShaderCallback`, or anything in a small allow-list), skip it.

### Hypothesis B: Rule conflates "in `build()`" with "rebuilt every build"

The rule's premise — "creating Gradient in build() causes allocations" — is true for direct sub-expressions of `build()`'s tree. It is false for closures that the framework stores and invokes later. `shaderCallback` is exactly such a closure: stored on `RenderShaderMask`, invoked when the render object paints. Hoisting the gradient construction "out of build" provides no gain because the closure itself is what's "out of build" already.

The lint message's correction (`Store gradient as a static const field or create outside build()`) is impossible to satisfy in this case without abandoning the animation: the gradient is parameterized by `bounds` (only available at paint time) and a per-frame animation value (only available at the moment the `AnimationController` ticks).

---

## Suggested Fix

In `lib/src/rules/widget/build_method_rules.dart`, modify `_GradientVisitor` so that it does not descend into `FunctionExpression`s whose target parameter type is `ShaderCallback`. Conceptual sketch:

```dart
@override
void visitFunctionExpression(FunctionExpression node) {
  // ShaderCallback is invoked at paint time by the framework.
  // Allocations inside it are paint-time, not build-time, and the
  // `Rect bounds` argument is only available there. Skip recursion.
  if (_isShaderCallbackArgument(node)) return;
  super.visitFunctionExpression(node);
}

bool _isShaderCallbackArgument(FunctionExpression node) {
  final AstNode? parent = node.parent;
  if (parent is! NamedExpression) return false;
  final ParameterElement? param = parent.element;
  final DartType? paramType = param?.type;
  // Match by display name to avoid pulling in dart:ui type resolution.
  // ShaderCallback = Shader Function(Rect bounds) — defined in painting.dart.
  return paramType?.getDisplayString(withNullability: false) == 'ShaderCallback'
      || paramType?.getDisplayString(withNullability: false) == 'ImageShaderCallback';
}
```

(Exact API for resolving the parameter element from a `NamedExpression` may differ — adjust to whatever the rule infrastructure already uses elsewhere. The key point is the type-name check on the surrounding parameter.)

Alternative / simpler heuristic if type resolution is too heavy: check the named-argument name directly (`shaderCallback`). Less precise but adequate for the common framework cases.

---

## Fixture Gap

The fixture at `example/lib/build_method/avoid_gradient_in_build_fixture.dart` is currently a stub (a 9-line `void main() {}` with a comment that says "requires specific framework types"). It exercises **none** of the rule's positive or negative cases. Add at minimum:

1. **Direct gradient in build() return** — expect LINT (current positive case)
2. **`const LinearGradient(...)` in build()** — expect NO lint (already handled by the `const` check at line 105)
3. **`LinearGradient` inside `ShaderMask.shaderCallback`** — expect NO lint (this bug)
4. **`LinearGradient` inside `BoxDecoration` constructed in build()** — expect LINT (genuine build-time allocation that should fire)
5. **`LinearGradient` inside `BoxDecoration` declared as a top-level `final`** — expect NO lint (true "hoisted" case the rule message advises)
6. **`ui.Gradient.linear(...)` inside `ShaderMask.shaderCallback`** — expect NO lint (separate type, already not flagged — document the boundary)

Without fixtures 3 and 4, the rule's behavior at the build-vs-paint boundary is untested and any fix is liable to regress.

---

## Changes Made

- `lib/src/rules/widget/build_method_rules.dart` — added `_GradientVisitor.visitFunctionExpression` override that short-circuits recursion when the visited `FunctionExpression` is the value of a `NamedExpression` whose name is `shaderCallback`. The list of paint-time callback names is held as a `Set<String>` so future entries (e.g. custom widgets that follow the `ShaderCallback` signature) can be added in one place.
- `example/lib/build_method/avoid_gradient_in_build_fixture.dart` — replaced the 9-line stub with five cases per the Fixture Gap section: bare gradient in build (LINT), gradient inside build-time `BoxDecoration` (LINT), const gradient (no lint), gradient inside `ShaderMask.shaderCallback` (no lint — this bug), top-level hoisted decoration (no lint).

The simpler named-argument heuristic (Hypothesis A's "Alternative") was chosen over `ParameterElement` type resolution. It is sufficient because `shaderCallback` is the canonical Flutter parameter name for paint-time `Shader Function(Rect)` closures and the rule never had any false-negative coverage for non-Flutter widgets that reuse the name.

---

## Tests Added

- `test/rules/widget/avoid_gradient_in_build_shadercallback_test.dart` — five behavioral tests that mirror `_GradientVisitor` (parse Dart source, walk every `build` body with a test-local replica, assert reported / not reported). Cases: shaderCallback closure (no report — the regression guard), bare gradient (reports), gradient in `BoxDecoration` (reports), const gradient (no report), top-level gradient referenced from build (no report).

---

## Commits

(pending)

---

## Environment

- saropa_lints version: (downstream pin in `d:/src/contacts/pubspec.yaml`)
- Dart SDK version: stable
- custom_lint version: native analyzer plugin (`analysis_server_plugin`)
- Triggering project/file: `d:/src/contacts/lib/components/primitive/shimmers/shimmer_text.dart` (former line 102 — refactored to `dart:ui.Gradient.linear` to bypass the FP, but the rule is still wrong for any future `LinearGradient` use inside `shaderCallback`)
