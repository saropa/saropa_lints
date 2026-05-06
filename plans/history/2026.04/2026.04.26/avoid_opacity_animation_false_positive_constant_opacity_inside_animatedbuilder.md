# `avoid_opacity_animation` — false positive: rule fires on a `Opacity` widget with a *constant* opacity value when the widget happens to sit inside an `AnimatedBuilder` whose animation drives a *sibling* property (an icon switch, a color, etc.)

**Status:** Open

Filed: 2026-04-26
Rule: `avoid_opacity_animation`
File: `lib/src/rules/ui/...` — needs grep confirmation
Severity: False positive
Rule version: v3 | Severity in code: WARNING | Impact: medium

---

## Summary

The rule's stated purpose: avoid animating `Opacity` via `setState` because every frame triggers a full subtree rebuild; `FadeTransition` is the GPU-friendly alternative.

The detection logic, however, does not check whether the `Opacity` widget's `opacity:` argument is actually animated. It triggers as long as an `Opacity` widget appears anywhere inside an `AnimatedBuilder` (or similar animation source). When the animation drives a *different* property — a switch between two icon constants, a color change, a layout decision — and the `Opacity` widget is being used purely as a static dimmer with a hard-coded opacity value, no per-frame opacity recomputation occurs and no rebuild cost is incurred for the `Opacity` itself.

Replacing it with `FadeTransition(opacity: animation, ...)` would *introduce* an animation that didn't exist before, producing visible flicker on every animation tick where there should be none.

---

## Attribution Evidence

```bash
$ grep -rn "'avoid_opacity_animation'" lib/src/rules/
# (run in saropa_lints checkout — confirm the rule lives here)
```

To be confirmed during investigation. Diagnostic source label is `dart` (saropa_lints native plugin); rule name follows saropa_lints conventions.

---

## Reproducer

Consumer project: `D:\src\contacts`. Site: `lib/components/primitive/panels/common_title_panel.dart:171`.

```dart
final Widget? trailing = widget.isExpandable
    ? AnimatedBuilder(
        animation: _expandAnimation,
        builder: (BuildContext context, Widget? child) {
          // The animation drives the icon SWAP only.
          final ThemeCommonIcon chevronIcon = _expandAnimation.value > 0.5
              ? ThemeCommonIcon.PanelCollapse
              : ThemeCommonIcon.PanelExpand;

          return Opacity(
            opacity: 0.6,                                // ← CONSTANT — not animated
            child: CommonIcon(                            // LINT fires on this Opacity
              iconCommon: chevronIcon,
              options: CommonIconOptions(
                sizeCommonFont: widget.options.titleHeadingType.fontSize,
                colorCommon: widget.options.colorCommon,
              ),
            ),
          );
        },
      )
    : null;
```

The opacity is hard-coded `0.6`. It does not reference `_expandAnimation.value` or any other animation source. The `AnimatedBuilder` rebuilds at the animation's rate, but the `Opacity` widget receives the same `0.6` every frame — there is no opacity animation happening.

The rule's fix recommendation (`Replace the Opacity widget with FadeTransition(opacity: animation, child: ...) driven by an AnimationController`) would change the visual — `FadeTransition` driven by `_expandAnimation` would fade the icon from 0 to 1 (or whatever curve the animation produces), which is **not what this code does**.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic. The `Opacity` widget's `opacity:` argument is a constant numeric literal, not an expression that depends on the animation value. There is no per-frame opacity recomputation. |
| **Actual** | `[avoid_opacity_animation]` fires on the `Opacity` widget purely because it appears inside an `AnimatedBuilder`. |

---

## AST Context

```
InstanceCreationExpression (AnimatedBuilder)
  └─ ArgumentList
      └─ NamedExpression (builder:)
          └─ FunctionExpression
              └─ Block / ReturnStatement
                  └─ InstanceCreationExpression (Opacity)              ← reported here
                      └─ ArgumentList
                          └─ NamedExpression (opacity: 0.6)            ← constant literal
                              └─ DoubleLiteral (0.6)
                          └─ NamedExpression (child: ...)
```

The rule reports without checking whether the `opacity:` argument's expression references the animation, references `setState`-driven state, or contains any variable at all.

---

## Root Cause

### Hypothesis: rule treats `Opacity` inside `AnimatedBuilder` as inherently animated

A correct rule must ask: *is the `opacity:` argument's expression a constant numeric literal?* If yes, no per-frame opacity computation happens and the rule should not fire.

A heuristic that closes the false positive without false-negative regression:

1. Locate the `Opacity` widget instantiation.
2. Find the `opacity:` argument's expression.
3. If the expression is a `NumericLiteral` (or evaluates to a compile-time constant), do not report.
4. Otherwise, the expression *might* be animation-driven, and the rule fires as before.

A stricter check additionally inspects whether the expression references the enclosing `AnimatedBuilder`'s `animation:` argument or any `AnimationController` field — but the simple "constant literal exemption" closes 100% of cases like the one filed here.

---

## Suggested Fix

In the rule's `runWithReporter`, before emitting:

```dart
context.addInstanceCreationExpression((InstanceCreationExpression node) {
  if (node.constructorName.type.name.lexeme != 'Opacity') return;

  // Only fire when the opacity value could change per frame. A constant
  // numeric literal cannot animate and should not trigger this rule.
  for (final Expression arg in node.argumentList.arguments) {
    if (arg is NamedExpression && arg.name.label.name == 'opacity') {
      final Expression value = arg.expression;
      if (value is DoubleLiteral || value is IntegerLiteral) {
        return;  // constant — no animation possible
      }
      // Otherwise: any non-literal expression is potentially animation-driven.
      break;
    }
  }

  // Existing detection: check for enclosing AnimatedBuilder / setState etc.
  if (_isInsideAnimationContext(node)) {
    reporter.atNode(node);
  }
});
```

---

## Fixture Gap

The fixture should include:

1. **`Opacity(opacity: _ctrl.value, child: …)` inside `AnimatedBuilder`** — expect LINT (genuine animated opacity)
2. **`Opacity(opacity: 0.6, child: …)` inside `AnimatedBuilder` where the animation drives a sibling property only** — expect NO lint *(currently false positive)*
3. **`Opacity(opacity: 0.6, child: …)` outside any animation context** — expect NO lint
4. **`AnimatedOpacity(opacity: _isShown ? 1 : 0, …)`** — expect NO lint (correct usage, framework-provided)
5. **`Opacity(opacity: ternary based on a non-animation `bool`, …)` inside `AnimatedBuilder`** — judgment call: probably NO lint, since the bool isn't tied to the animation. Currently false positive.

---

## Downstream

Tracked in `contacts/`. `// ignore: avoid_opacity_animation` added at `lib/components/primitive/panels/common_title_panel.dart:171` once this bug exists.

---

## Environment

- saropa_lints version: 12.5.1+
- Dart SDK: 3.9.x
- Triggering project: `d:/src/contacts`
- Platform: Windows 11
