# `avoid_ignoring_return_values` false positive: property setter assignment

## Status: OPEN

## Summary

The `avoid_ignoring_return_values` rule (v1) fires on `_controller.duration = widget.options.bounceDuration;`, a **property setter assignment** on `AnimationController`. This is a standard Dart setter invocation via the `=` operator — it produces no return value that could be "ignored." The `set duration(Duration? value)` setter on `AnimationController` returns `void`.

The rule's `runWithReporter` method (lines 8394–8396) explicitly guards against non-method-invocation expressions, so the Dart AST should classify this `AssignmentExpression` node as neither `MethodInvocation` nor `FunctionExpressionInvocation`. Yet the diagnostic fires, suggesting the guard is not working for this case.

## Diagnostic Output

```
resource: /D:/src/contacts/lib/components/primitive/swipe/horizontal_swipe_hint_wrapper.dart
owner:    _generated_diagnostic_collection_name_#2
code:     avoid_ignoring_return_values
severity: 2 (info)
message:  [avoid_ignoring_return_values] Return value of this invocation is
          ignored. Discarding return values can hide bugs where an important
          result (a Future, a boolean success flag, or a parsed value) is
          silently lost. Assign the result to a variable or remove the call
          if it is truly unnecessary. {v1}
          Assign the return value to a variable, or use it in an expression.
line:     265, columns 5–66
```

## Affected Source

File: `lib/components/primitive/swipe/horizontal_swipe_hint_wrapper.dart` lines 251 and 265

```dart
/// Starts the "peek" phase - moving content away from center.
void _startPeek() {
  if (!mounted || !widget.options.isActive) return;

  _isPeeking = true;
  _controller.duration = widget.options.peekDuration;  // ← same pattern, may also trigger

  final double targetValue = _peekDirectionMultiplier.toDouble();
  _controller.animateTo(targetValue, curve: Curves.easeOut);
}

/// Starts the "bounce back" phase - returning content to center.
void _startBounceBack() {
  if (!mounted) return;

  _isPeeking = false;
  _controller.duration = widget.options.bounceDuration;  // ← triggers the rule

  _controller.animateTo(0.0, curve: widget.options.bounceCurve);
}
```

Both `peekDuration` and `bounceDuration` are `Duration` (non-nullable). `_controller` is an `AnimationController`. The `duration` setter is a standard `void`-returning setter inherited from `AnimationController`:

```dart
// Flutter SDK: animation_controller.dart
set duration(Duration? value) {
  _duration = value;
}
```

## Root Cause

The rule at `code_quality_rules.dart` lines 8390–8431 registers an `ExpressionStatement` visitor and checks:

```dart
context.addExpressionStatement((ExpressionStatement node) {
  final Expression expression = node.expression;

  // Only check method invocations and function invocations
  if (expression is! MethodInvocation &&
      expression is! FunctionExpressionInvocation) {
    return;  // ← should bail out for AssignmentExpression
  }

  // ... rest of checks ...
  reporter.atNode(expression);
});
```

In standard Dart AST, `_controller.duration = value` is represented as:
- `ExpressionStatement`
  - `AssignmentExpression` (the `expression` property)
    - Left: `PropertyAccess` (`_controller.duration`)
    - Right: `PrefixedIdentifier` (`widget.options.bounceDuration`)

`AssignmentExpression` is **not** a subtype of `MethodInvocation` or `FunctionExpressionInvocation`, so the guard at lines 8394–8396 should cause an early return.

### Possible explanations

1. **AST node type mismatch**: The Dart analyzer or `custom_lint` may represent property setter calls as `MethodInvocation` in some contexts (e.g., when the setter is defined on a class accessed through a field, or when resolution produces a synthetic method call).

2. **Expression unwrapping in `SaropaContext`**: The `addExpressionStatement` registration in `saropa_context.dart` (line 194) delegates to `_visitor.onExpressionStatement`. If the visitor framework unwraps or transforms the `ExpressionStatement.expression` before delivering it to the callback, the node type might differ from the raw AST.

3. **Analyzer version interaction**: Different Dart analyzer versions may classify setter invocations differently in the resolved AST, especially when the target is accessed through multiple property accesses (`widget.options.bounceDuration`).

## Why This Is a False Positive

1. **Setter assignments have no meaningful return value** — In Dart, setter calls via `=` are `void`. There is nothing to "assign to a variable."
2. **The diagnostic message is misleading** — "Assign the return value to a variable" makes no sense for a setter assignment. You cannot write `final x = (_controller.duration = value);` and get anything useful.
3. **This is idiomatic Dart** — Reassigning `AnimationController.duration` before calling `animateTo()` is the standard Flutter pattern for changing animation speed mid-flight. Every Flutter developer writes this.

## Scope of Impact

Any property setter assignment on any object will potentially trigger this false positive. Common patterns affected:

```dart
// AnimationController duration changes
_controller.duration = const Duration(milliseconds: 300);

// Text editing controller value
_textController.text = 'new value';

// Scroll controller offset (if exposed as setter)
_scrollController.initialScrollOffset = 0.0;

// Any custom class setter
myObject.config = newConfig;
```

This is extremely common in Flutter state management and lifecycle code.

## Recommended Fix

### Approach A: Explicitly skip `AssignmentExpression` (defensive, recommended)

Add an explicit type check before the existing guard to make the exclusion unambiguous:

```dart
context.addExpressionStatement((ExpressionStatement node) {
  final Expression expression = node.expression;

  // Property setter assignments (e.g., obj.prop = value) have no
  // meaningful return value — skip them unconditionally.
  if (expression is AssignmentExpression) return;

  // Only check method invocations and function invocations
  if (expression is! MethodInvocation &&
      expression is! FunctionExpressionInvocation) {
    return;
  }

  // ... rest of existing logic unchanged ...
});
```

This is the simplest fix: `AssignmentExpression` can never produce an "ignored return value" because setters return `void`.

### Approach B: Investigate why the type guard fails

If `AssignmentExpression` is NOT reaching the callback (i.e., the guard at 8394–8396 is working correctly for most cases), then the issue is that the Dart analyzer is representing this specific setter call as a `MethodInvocation`. In that case:

```dart
if (expression is MethodInvocation) {
  methodName = expression.methodName.name;
  returnType = expression.staticType;

  // Skip setter methods — they appear as MethodInvocation with '=' suffix
  // or have void return type from the setter definition
  if (methodName.endsWith('=')) return;
}
```

### Approach C: Combine both checks

Add Approach A as a primary guard and Approach B as a secondary safety net.

**Recommendation:** Approach A alone is sufficient and defensive. Even if the current guard at 8394–8396 works for most setter assignments, adding an explicit `AssignmentExpression` check makes the intent clear and prevents future regressions if the analyzer's AST representation changes.

## Test Fixture Updates

### New GOOD cases (should NOT trigger)

```dart
import 'package:flutter/animation.dart';

// GOOD: Property setter assignment — no return value to capture.
void goodSetterAssignment(AnimationController controller) {
  controller.duration = const Duration(milliseconds: 300);
}

// GOOD: Setter on a field accessed through property chain.
void goodChainedSetter(AnimationController controller) {
  controller.duration = Duration(milliseconds: controller.value.toInt());
}

// GOOD: Compound property setter (different target types).
void goodVariousSetters() {
  final TextEditingController textController = TextEditingController();
  textController.text = 'hello';

  final ScrollController scrollController = ScrollController();
  scrollController.initialScrollOffset;  // getter read (separate concern)
}
```

### Existing BAD cases (should still trigger)

```dart
// BAD: Return value of map() is ignored — this is the rule's primary target.
// expect_lint: avoid_ignoring_return_values
void badIgnoreReturn() {
  final list = [1, 2, 3];
  list.map((e) => e * 2);
}
```

## Environment

- **saropa_lints version:** 5.0.0-dev.1 (rule version v1)
- **Dart SDK:** 3.x
- **Trigger project:** `D:\src\contacts`
- **Trigger file:** `lib/components/primitive/swipe/horizontal_swipe_hint_wrapper.dart:265`
- **Trigger expression:** `_controller.duration = widget.options.bounceDuration;`
- **Expression AST type:** `AssignmentExpression` (expected), possibly `MethodInvocation` (if analyzer resolves setter as method)
- **Target type:** `AnimationController` (Flutter SDK)
- **Setter:** `set duration(Duration? value)` — returns `void`
- **RHS type:** `Duration` (non-nullable)

## Severity

Low — info-level diagnostic. The false positive recommends assigning the return value of a void setter to a variable, which is nonsensical. However, the impact scope is broad: every property setter assignment in the project could potentially trigger this, making it noisy in IDE diagnostics.
