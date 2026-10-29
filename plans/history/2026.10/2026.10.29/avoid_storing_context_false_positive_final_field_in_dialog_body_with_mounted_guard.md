# BUG: `avoid_storing_context` — Parent Context Passed To A Dialog Body And Guarded By mounted

**Status: Open**

Created: 2026-10-29
Rule: `avoid_storing_context`
File: `lib/src/rules/core/context_rules.dart (line ~54)`
Severity: False positive

---

## Summary

A dialog body widget receives the opener screen's `BuildContext` as a `final` constructor field. The context is only used synchronously, after `parentContext.mounted` is checked, to open a follow-up screen once the dialog has closed. The rule reports the field declaration without looking at how it is used. The rule's own correction text ("check if the widget is still mounted before using it") is what the code does.

---

## Attribution Evidence

```bash
grep -rn "'avoid_storing_context'" lib/src/rules/
# lib/src/rules/core/context_rules.dart:71:    'avoid_storing_context',
# class AvoidStoringContextRule (context_rules.dart:54)
```

---

## Reproducer

```dart
// Needs the Flutter SDK (package:flutter/material.dart).
import 'package:flutter/material.dart';

class ConflictBody extends StatelessWidget {
  const ConflictBody({super.key, required this.parentContext});

  /// Context of the screen that opened the dialog.
  final BuildContext parentContext; // LINT - should NOT lint (only used behind a mounted check)

  void ask(BuildContext dialogContext) {
    Navigator.of(dialogContext).pop();
    if (!parentContext.mounted) return;
    Navigator.of(parentContext).push(MaterialPageRoute<void>(builder: (_) => const SizedBox()));
  }

  @override
  Widget build(BuildContext context) => TextButton(onPressed: () => ask(context), child: const Text('Ask'));
}
```
Project source: `lib/components/contact/detail_panels/event/event_calendar_conflict_dialog.dart:70` (field), used at lines 150-153 after `if (!parentContext.mounted) return;`.

**Frequency:** Always for a `BuildContext` field.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic on a final field whose every read is preceded by `<field>.mounted` checking (early return or `if`) |
| **Actual** | `[avoid_storing_context] Storing a BuildContext in a field or variable for later use is dangerous ... {v4}` at 70:22-35 |

---

## AST Context

```
ClassDeclaration (_ConflictBody extends StatelessWidget)
  └─ FieldDeclaration (final BuildContext parentContext)
      └─ VariableDeclarationList (type: BuildContext)
          └─ VariableDeclaration (parentContext)   <- reported (reporter.atNode(variable))
```

---

## Root Cause

`context.addFieldDeclaration` (context_rules.dart:84) skips only function-typed fields (line 90). For each variable it checks `_isContextType(type)` (type string contains `BuildContext`) and reports (line 95). Field usage, `final`-ness, and the owning class kind (`StatelessWidget` vs `State`) are never examined, so a guarded, synchronously used context field is treated like a context cached across async gaps.

---

## Why the Code Is Correct

The context belongs to a screen that outlives the dialog it opened. Every use is behind `parentContext.mounted`, so a disposed context is never dereferenced. The alternative (a callback created by the opener) captures the same context in a closure and adds no safety.

---

## Affected Project Locations

`lib/components/contact/detail_panels/event/event_calendar_conflict_dialog.dart` line 70.

---

## Suggested Fix

Skip a `final` field of type `BuildContext` when every `SimpleIdentifier` reference to it in the class is either `<field>.mounted` or sits after an early-return `if (!<field>.mounted)` / inside `if (<field>.mounted)` in the same block.

---

## Fixture Cases

```dart
// LINT expected (late, assigned from State.context, used after await without a check)
// OK expected (final field, only used after `if (!parentContext.mounted) return;`)
```

---

## Environment

- saropa_lints: 17.0.1-beta.2 (installed in the downstream project); rule line numbers below read from the local checkout (pubspec 17.0.1-beta.3), where the cited logic is unchanged.
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Downstream project: Saropa Contacts (`/Users/craighathaway/Documents/src/contacts`), Flutter app.
- Diagnostic `source` / `owner` in Problems panel: `saropa_lints` / `saropaLintsLsp`

## Status 2026-10-29

Fixed in 17.0.1-beta.4 (see CHANGELOG).
