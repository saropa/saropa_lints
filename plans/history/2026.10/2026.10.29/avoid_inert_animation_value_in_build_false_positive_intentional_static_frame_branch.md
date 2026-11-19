# BUG: `avoid_inert_animation_value_in_build` — flags `animation.value` read on the branch that deliberately paints one static frame, while the animated branch uses `AnimatedBuilder`

**Status: Open**

Created: 2026-10-29
Rule: `avoid_inert_animation_value_in_build`
File: `lib/src/rules/ui/animation_rules.dart` (class at line 3081)
Severity: False positive
Rule version: see diagnostic | Since: unknown | Updated: 17.0.1-beta.2

---

## Summary

`build` chooses between a static frame (reduced motion, or a muted ticker subtree) and an `AnimatedBuilder` for the live case. The static branch reads `animation.value` once on purpose. The rule reports it as an inert animation read.

---

## Attribution Evidence

```bash
grep -rn "'avoid_inert_animation_value_in_build'" lib/src/rules/
# lib/src/rules/ui/animation_rules.dart:3112:    'avoid_inert_animation_value_in_build',
```

**Rule class:** `AvoidInertAnimationValueInBuildRule` (`lib/src/rules/ui/animation_rules.dart:3081`)
**Diagnostic as seen in Problems panel:** `[avoid_inert_animation_value_in_build] Reading an Animation.value inside build() outside of a listening builder produces a static snapshot ... {v1} (line 304, col 65)` (source: saropa_lints)

---

## Reproducer

Standalone (needs the Flutter SDK). Real code: `lib/components/primitive/shimmers/common_shimmer.dart` lines 296-310 (`_CommonShimmerState.build`).

```dart
import 'package:flutter/widgets.dart';

class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.reduced});
  final bool reduced;
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _frame(double t) => Opacity(opacity: t, child: const SizedBox());

  @override
  Widget build(BuildContext context) {
    final Animation<double> animation = _c;
    return widget.reduced
        ? _frame(animation.value) // LINT — but a static frame is the intent of this branch
        : AnimatedBuilder(animation: animation, builder: (BuildContext _, Widget? __) => _frame(animation.value));
  }
}
```

**Frequency:** Always for this pattern.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the live case is already served by an `AnimatedBuilder` in the other branch of the same conditional |
| **Actual** | Diagnostic on `animation.value` in the static branch |

---

## AST Context

`MethodDeclaration(build)` > `BlockFunctionBody` > `VariableDeclarationStatement(shimmer)` > `ConditionalExpression(locallyStatic ? A : B)`; reported node is `PrefixedIdentifier(animation.value)` inside the then-branch `MethodInvocation(_buildFrame(...))` > `ArgumentList` > `ConditionalExpression(motionReduced ? _kShimmerMax : animation.value)`. The else-branch is an `InstanceCreationExpression(AnimatedBuilder)`.

---

## Root Cause

`animation_rules.dart` `_isInertReadInBuild` (line 3205): walks up from the read; stops with "safe" only when it meets a listening-builder callback `FunctionExpression`. The read is in the sibling branch, outside any callback, so it is "inert". `_isReadInListeningBuilderRebuiltWidget` only recognizes reads that feed a widget wrapped by a listening builder, not a conditional whose other branch is the listening builder.

---

## Why the code is correct

The static branch is entered only when `locallyMuted` (the subtree is hidden or its ticker is muted) or `motionReduced` (accessibility). In both cases a frozen frame is the requirement, so nothing should repaint per tick. The live case is handled by the `AnimatedBuilder` in the other branch. A dependency on `TickerMode` (which rebuilds the leaf when the mute flag flips) refreshes the frame when the state changes.

## Affected project locations

- `lib/components/primitive/shimmers/common_shimmer.dart:304`

---

## Suggested Fix

Skip the report when the read is in one branch of a `ConditionalExpression` / `if` whose other branch contains a listening builder over the same animation. Alternatively skip when the enclosing method also builds a listening builder for the same receiver identifier.

---

## Fixture Gap

- GOOD: `reduced ? frame(a.value) : AnimatedBuilder(animation: a, builder: ...)`
- BAD: `return Opacity(opacity: a.value, child: x);` with no listening builder anywhere for `a`

---

## Environment

- saropa_lints version: 17.0.1-beta.2 (installed, hosted); rule logic cross-checked against the repo source (17.0.1-beta.3)
- Dart SDK: Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Triggering project: Saropa contacts app (`/Users/craighathaway/Documents/src/contacts`)

## Status 2026-10-29

Fixed in 17.0.1-beta.4 (see CHANGELOG).
