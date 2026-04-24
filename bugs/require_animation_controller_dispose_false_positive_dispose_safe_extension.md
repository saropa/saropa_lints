# BUG: `require_animation_controller_dispose` — Fires on `_controller.disposeSafe()` despite docs listing it as a valid pattern

**Status: Open**

Created: 2026-04-24
Rule: `require_animation_controller_dispose`
File: `lib/src/rules/ui/animation_rules.dart` (line 346)
Severity: False positive (High — forces `// ignore:` on an officially-documented disposal pattern)
Rule version: v2 | Since: unknown | Updated: unknown

---

## Summary

The rule's dartdoc explicitly lists `_controller.disposeSafe()` (and its `?.` / `..` variants) as a recognized disposal pattern, but the detection logic only calls `isFieldCleanedUp(name, 'dispose', ...)` — it never also checks for `'disposeSafe'`. Widgets that use the project's `disposeSafe()` extension method for safe disposal are flagged as if they had no `dispose()` call at all.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'require_animation_controller_dispose'" lib/src/rules/
# lib/src/rules/ui/animation_rules.dart:277:    'require_animation_controller_dispose',

# Negative — rule is NOT in saropa_drift_advisor
grep -rn "'require_animation_controller_dispose'" ../saropa_drift_advisor/
# 0 matches
```

**Emitter registration:** `lib/src/rules/ui/animation_rules.dart:277` (LintCode literal)
**Rule class:** `RequireAnimationControllerDisposeRule` (`lib/src/rules/ui/animation_rules.dart:256`), registered in `lib/saropa_lints.dart:1179`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` (native analyzer plugin via `analysis_server_plugin`)

---

## Reproducer

Minimal reproducer (also matches the real failing site in `contacts/lib/components/primitive/fade/fade_out_on_tap.dart`):

```dart
import 'package:flutter/material.dart';

/// Project-wide extension that wraps the raw dispose() in try/catch and a
/// duration-zero guard. Lives at `lib/utils/primitive/animation_dispose_utils.dart`
/// in the consuming app.
extension AnimationControllerDisposal on AnimationController {
  void disposeSafe() {
    if (duration != Duration.zero) {
      dispose();
      duration = Duration.zero;
    }
  }
}

class FadeOutOnTap extends StatefulWidget {
  const FadeOutOnTap({required this.child, super.key});
  final Widget child;
  @override
  State<FadeOutOnTap> createState() => _FadeOutOnTapState();
}

class _FadeOutOnTapState extends State<FadeOutOnTap>
    with SingleTickerProviderStateMixin {
  // LINT fires here — but should NOT, because dispose() IS called below
  // via the documented `.disposeSafe()` extension variant.
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _animationController.disposeSafe(); // <-- disposal IS present
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
```

**Frequency:** Always — triggers on every `State` subclass that disposes via `disposeSafe()` instead of a literal `dispose()` call.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `_animationController.disposeSafe()` is listed in the rule's own dartdoc (`animation_rules.dart:206-208`) as a valid disposal pattern |
| **Actual** | `[require_animation_controller_dispose] Neglecting to dispose of an AnimationController …` reported on the field declaration, severity `ERROR` |

---

## AST Context

The rule registers on `ClassDeclaration` and iterates `node.body.members`:

```
ClassDeclaration (_FadeOutOnTapState)
  ├─ FieldDeclaration (late final AnimationController _animationController)
  │    └─ VariableDeclaration (_animationController)   ← reporter.atNode(variable)
  ├─ MethodDeclaration (initState)
  │    └─ BlockFunctionBody
  │        └─ ExpressionStatement
  │            └─ AssignmentExpression (_animationController = AnimationController(...))
  └─ MethodDeclaration (dispose)
       └─ BlockFunctionBody                               ← passed to isFieldCleanedUp
           └─ ExpressionStatement
               └─ MethodInvocation (_animationController.disposeSafe())
                   ├─ target: SimpleIdentifier (_animationController)
                   └─ methodName: SimpleIdentifier (disposeSafe)   ← detection misses this
```

The `isFieldCleanedUp('_animationController', 'dispose', disposeBody)` call stringifies `disposeBody` and regex-matches `_animationController\s*(\.|\?\.)\s*dispose\s*\(`. Against the source `_animationController.disposeSafe()`, the pattern consumes `_animationController.dispose` and then requires `\s*\(` — but finds `Safe(`, so the match fails.

---

## Root Cause

### Mechanism

`lib/src/rules/ui/animation_rules.dart:343-346`:

```dart
for (final String name in controllerNames) {
  final bool isDisposed =
      disposeMethodBody != null &&
      isFieldCleanedUp(name, 'dispose', disposeMethodBody);
```

`isFieldCleanedUp` is a regex-based text matcher (`lib/src/target_matcher_utils.dart:62-74`):

```dart
bool isFieldCleanedUp(String fieldName, String methodName, FunctionBody body) {
  return _fieldCleanedUpPattern(fieldName, methodName).hasMatch(body.toSource());
}

RegExp _fieldCleanedUpPattern(String fieldName, String methodName) {
  return RegExp(
    '${RegExp.escape(fieldName)}\\s*(\\.|\\?\\.)\\s*${RegExp.escape(methodName)}\\s*\\(',
  );
}
```

Because `methodName` is escaped and terminated by `\s*\(`, the call with `methodName: 'dispose'` matches ONLY `dispose(` — it cannot match `disposeSafe(` (the `S` breaks the `\s*\(` boundary). The rule therefore has to call `isFieldCleanedUp` a second time with `methodName: 'disposeSafe'` and OR the results — which it does not.

### Comparable correct implementation

`lib/src/rules/packages/bloc_rules.dart:237-240` follows the same safe-variant convention and gets it right:

```dart
final bool isClosed =
    disposeMethod != null &&
    (isFieldCleanedUp(name, 'close', disposeMethod.body) ||
        isFieldCleanedUp(name, 'closeSafe', disposeMethod.body));
```

The animation rule needs the same OR with `'disposeSafe'`.

### Docs/code divergence

`lib/src/rules/ui/animation_rules.dart:202-208` (rule-level dartdoc) promises support for all three shapes:

```
/// - `_controller.dispose()` - standard disposal
/// - `_controller?.dispose()` - null-safe disposal
/// - `_controller..dispose()` - cascade disposal
/// - `_controller.disposeSafe()` - safe disposal extension method
/// - `_controller?.disposeSafe()` - null-safe extension disposal
/// - `_controller..disposeSafe()` - cascade extension disposal
```

The `.dispose()`, `?.dispose()`, `..dispose()` shapes work because the regex's `(\.|\?\.)` branch handles `.` and `?.`, and `..dispose(` contains `.dispose(` as a substring so it matches. The three `disposeSafe` shapes do **not** work for the reason above. Docs were written as if both method names were checked; the implementation only checks one.

A second, smaller docstring inconsistency lives at `lib/src/target_matcher_utils.dart:54`:

```
/// - Safe-call variants: `name?.disposeSafe(`
```

This implies the helper itself handles `*Safe` variants, but it does not — the caller must pass `methodName: 'disposeSafe'` explicitly.

---

## Suggested Fix

**Primary fix** — at `lib/src/rules/ui/animation_rules.dart:343-346`, mirror the `bloc_rules.dart` pattern:

```dart
for (final String name in controllerNames) {
  // Accept both the raw `.dispose()` call and the project-wide `.disposeSafe()`
  // extension (documented at lines 202-208 of this file). The regex in
  // isFieldCleanedUp is anchored to `methodName\s*\(`, so `dispose` will NOT
  // match `disposeSafe(` — both names must be checked separately.
  final bool isDisposed =
      disposeMethodBody != null &&
      (isFieldCleanedUp(name, 'dispose', disposeMethodBody) ||
          isFieldCleanedUp(name, 'disposeSafe', disposeMethodBody));

  if (!isDisposed) {
    // … existing reporter.atNode(variable) block …
  }
}
```

**Secondary fix** — update the docstring at `lib/src/target_matcher_utils.dart:45-60` to remove the misleading "Safe-call variants: `name?.disposeSafe(`" claim, OR change the helper to accept a list of method names and build an alternation (`(dispose|disposeSafe)`) — the former is lower-risk and keeps call sites explicit about which variants they opt into.

---

## Fixture Gap

`example/lib/animation/require_animation_controller_dispose_fixture.dart` should include:

1. **Case: field disposed via `.disposeSafe()` extension** — expect NO lint.
2. **Case: field disposed via `?.disposeSafe()`** — expect NO lint.
3. **Case: field disposed via `..disposeSafe()` cascade** — expect NO lint.
4. **Case: field disposed via `.dispose()` (already covered, keep)** — expect NO lint.
5. **Case: field NEVER disposed** — expect LINT (regression guard).
6. **Case: field with unrelated method `.disposeAll()` only** — expect LINT (prevents accidental substring match if the fix is done by relaxing the `\s*\(` anchor instead of adding an explicit OR).

---

## Changes Made

<!-- Fill in when a fix is written. -->

---

## Tests Added

<!-- List new or updated fixture/test files and what they verify. -->

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 12.4.2 (from `pubspec.yaml:10`)
- Dart SDK version: >=3.9.0 <4.0.0 (from `pubspec.yaml:44`)
- custom_lint version: N/A — this repo is a native analyzer plugin via `analysis_server_plugin`, not `custom_lint`
- Triggering project/file: `d:/src/contacts/lib/components/primitive/fade/fade_out_on_tap.dart` (field `_animationController` on line 35, disposed via `_animationController.disposeSafe()` on line 63)
