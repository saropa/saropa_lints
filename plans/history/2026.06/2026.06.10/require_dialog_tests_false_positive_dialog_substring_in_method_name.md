# BUG: `require_dialog_tests` — Fires on any method name containing "Dialog" (l10n getter, not a dialog)

**Status: Fixed**

Created: 2026-06-10
Rule: `require_dialog_tests`
File: `lib/src/rules/testing/testing_best_practices_rules.dart` (line ~3625)
Severity: False positive
Rule version: v2

---

## Summary

The rule wants `pumpAndSettle()` after a dialog is shown in a test. It identifies "a dialog is shown" by `methodName == 'showDialog' || methodName.contains('Dialog')`. The substring match flags any invocation whose name merely contains "Dialog" — e.g. a localization getter `emergencyDirectoryDialogHeader('Australian', 'Banks')` that returns a `String`. No dialog is shown, no `pumpAndSettle` is appropriate, yet the call is reported.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'require_dialog_tests'" lib/src/rules/
# lib/src/rules/testing/testing_best_practices_rules.dart:3613:    'require_dialog_tests',

# Negative — NOT in sibling repo
grep -rn "'require_dialog_tests'" ../saropa_drift_advisor/lib/
# 0 matches
```

**Emitter registration:** `lib/src/rules/testing/testing_best_practices_rules.dart:3613`
**Rule class:** `RequireDialogTestsRule`
**Diagnostic `source` / `owner`:** `dart` / `_generated_diagnostic_collection_name_#5`

---

## Reproducer

```dart
testWidgets('localized headers resolve', (WidgetTester tester) async {
  final AppLocalizations s = await pumpAndGetS(tester);

  // LINT (false positive): emergencyDirectoryDialogHeader is an l10n STRING
  // getter — its name contains "Dialog", but it shows no dialog. There is
  // nothing to pumpAndSettle.
  expect(
    s.emergencyDirectoryDialogHeader('Australian', 'Banks'),
    equals('Australian Banks'),
  );
});
```

Real site: `D:\src\contacts\test\lib\l10n\localization_test.dart:229`.

**Frequency:** Always, for any method/getter whose name contains the substring "Dialog" (e.g. `*DialogHeader`, `*DialogTitle`, `buildDialogText`, `dialogLabelFor`) invoked inside a test without a following `pumpAndSettle`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `emergencyDirectoryDialogHeader` returns a `String`; it does not display a dialog. |
| **Actual** | `[require_dialog_tests] Dialog test may be incomplete. Ensure pumpAndSettle after showing dialog...` reported at the invocation. |

---

## AST Context

```
MethodInvocation (testWidgets)
  └─ FunctionExpression → Block
      └─ ExpressionStatement
          └─ MethodInvocation (expect)
              └─ ArgumentList
                  └─ MethodInvocation (emergencyDirectoryDialogHeader)  ← node reported here
                      staticType (return) = String
```

---

## Root Cause

`testing_best_practices_rules.dart:3625-3646`:

```dart
context.addMethodInvocation((MethodInvocation node) {
  if (node.methodName.name != 'showDialog' &&
      !node.methodName.name.contains('Dialog')) {   // <-- substring match
    return;
  }
  if (!_isInsideTestForDialog(node)) return;
  ...
  if (!afterDialog.contains('pumpAndSettle')) {
    reporter.atNode(node);
  }
});
```

`name.contains('Dialog')` matches any identifier with "Dialog" anywhere in it, with no check that the call actually displays a dialog. There is no verification that:
- the return type is `Future` / `void` (a getter returning `String` cannot be a dialog launcher), or
- the callee resolves to a known dialog-showing API (`showDialog`, `showGeneralDialog`, `showDialogCommon`, `showModalBottomSheet`, etc.).

So the localization getter `emergencyDirectoryDialogHeader` (returns `String`) is treated as a dialog launch, and because there is no `pumpAndSettle` after it (correctly — there is no dialog), the rule reports.

---

## Suggested Fix

Replace the bare substring match with a targeted check:

- Match `showDialog` and a small allowlist of dialog-showing APIs by name: `showDialog`, `showGeneralDialog`, `showDialogCommon`, `showAdaptiveDialog`, `showModalBottomSheet`, `showCupertinoDialog`. (Project-specific launchers can be added.)
- AND/OR require the invocation's static return type to be awaitable (`Future` / `void`); a `String`-returning getter is never a dialog launch.

Combining the two (allowlist OR `Future`-returning + name contains "Dialog") removes the false positive while still catching custom dialog helpers.

---

## Fixture Gap

`example*/lib/testing/require_dialog_tests_fixture.dart` should include:

1. `await showDialog(...)` with no following `pumpAndSettle` — expect LINT.
2. `await showDialogCommon(...)` then `await tester.pumpAndSettle();` — expect **NO** lint.
3. `expect(s.emergencyDirectoryDialogHeader('a', 'b'), '...')` — expect **NO** lint (String getter, "Dialog" in name only).
4. `final title = buildDialogTitle();` (returns String) — expect **NO** lint.

---

## Environment

- saropa_lints version: ^13.12.2
- Dart SDK version: >=3.10.7 <4.0.0
- custom_lint version: native analyzer plugin (analysis_server_plugin), not custom_lint
- Triggering project/file: `D:\src\contacts\test\lib\l10n\localization_test.dart:229`

## Finish Report (2026-06-10)

Fixed in WS-5. Replaced the bare `name.contains('Dialog')` with: a known-launcher allowlist (`showDialog`, `showGeneralDialog`, `showAdaptiveDialog`, `showDialogCommon`, `showModalBottomSheet`, `showCupertinoDialog`, `showCupertinoModalPopup`) OR a `*Dialog*` call whose static return type is a CONFIRMED awaitable (Future/void). Unresolved (null) type is treated as not-a-launch (real launchers are caught by name). Verified: real site `localization_test.dart:229` now clean. Fixture extended: `example/lib/testing_best_practices/require_dialog_tests_fixture.dart`.
