# BUG: `prefer_platform_widget_adaptive` — reports every `MaterialApp`

**Status: Fixed**

Created: 2026-11-26
Rule: `prefer_platform_widget_adaptive`
File: `lib/src/rules/config/platform_rules.dart` (line ~396)
Severity: False positive
Rule version: not stated in the rule source

---

## Summary

Every `MaterialApp` construction is reported, with no check for platform adaptation. No code using `MaterialApp` can satisfy the rule.

---

## Attribution Evidence

```bash
grep -rn "'prefer_platform_widget_adaptive'" lib/src/rules/
# lib/src/rules/config/platform_rules.dart:383:    'prefer_platform_widget_adaptive',
```

**Emitter registration:** `lib/src/rules/config/platform_rules.dart:383`
**Rule class:** `PreferPlatformWidgetAdaptiveRule` — registered in `lib/saropa_lints.dart:2162`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Derived from reading the rule source. Not executed.

```dart
import 'package:flutter/material.dart';

Widget failureScreen() => MaterialApp( // LINT — but should NOT lint
  theme: ThemeData(platform: TargetPlatform.iOS),
  home: const Scaffold(body: SizedBox()),
);
```

**Frequency:** Always

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic |
| **Actual** | `[prefer_platform_widget_adaptive]` reported on the line marked LINT |

---

## AST Context

```
FunctionDeclaration (failureScreen)
  └─ ExpressionFunctionBody
      └─ InstanceCreationExpression (MaterialApp)  ← reported
```

---

## Root Cause

`runWithReporter` (lines ~396-400) returns only when the constructor name is not `MaterialApp`, then reports. The adaptation described in the doc comment is never inspected.

---

## Suggested Fix

Report only when concrete non-adaptive evidence exists (for example Material-only controls where an `.adaptive` constructor is available), or remove the rule.

---

## Fixture Gap

1. `MaterialApp` with platform-aware theme — expect NO lint

---

## Environment

- saropa_lints version: 17.9.1 (rule source read at this version)
- Dart SDK version: not recorded
- Triggering project/file: a private Flutter app

---

## Finish Report (2026-11-26)

**Behavior change** (`lib/src/rules/config/platform_rules.dart`, rule version v2): the rule no longer reports `MaterialApp`. It now reports the default constructor of Flutter Material controls that have an unused `.adaptive` constructor (`Checkbox`, `CheckboxListTile`, `CircularProgressIndicator`, `Radio`, `RadioListTile`, `RefreshIndicator`, `Slider`, `Switch`, `SwitchListTile`), unless the control sits under or after a platform branch. `AlertDialog` is left to `prefer_adaptive_dialog`. Tier assignment is unchanged.

**Limits:** the rule needs resolved elements, so the unresolved `scan` reports nothing for it. The widget list is fixed in code. Projects can see new diagnostics where there were none.

Tests: `dart test test/rules/config/prefer_platform_widget_adaptive_behavior_test.dart test/rules/config/platform_rules_test.dart` - passed.
