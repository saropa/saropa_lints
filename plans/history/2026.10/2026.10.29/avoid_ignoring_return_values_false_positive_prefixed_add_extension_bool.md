# BUG: `avoid_ignoring_return_values` — mutate-verb exemption misses local extension `dbActivityAdd()` (verb not at the start of the name)

**Status: Open**

Created: 2026-10-29
Rule: `avoid_ignoring_return_values`
File: `lib/src/rules/code_quality/code_quality_avoid_rules.dart` (line ~4282; exemption ~4350-4440)
Severity: False positive
Rule version: v2 | Since: unknown | Updated: 17.0.1-beta.2

---

## Summary

The rule exempts project-local extension methods that return `bool`, are named with a mutate verb prefix (`add`, `append`, `insert`, `remove`, `update`, `set`) and are declared on an extension. `_isMutateVerbName` only accepts a name that STARTS with the verb. Project naming convention is a domain prefix (`db`) then the verb: `dbActivityAdd`, `dbActivityAddForContact`. These record an activity row fire-and-forget; the `bool` is a "did it queue" convenience flag. They are reported.

---

## Attribution Evidence

```bash
grep -rn "'avoid_ignoring_return_values'" lib/src/rules/
# lib/src/rules/code_quality/code_quality_avoid_rules.dart:4282:    'avoid_ignoring_return_values',
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_avoid_rules.dart:4282`
**Rule class:** `AvoidIgnoringReturnValuesRule` — registered in `lib/saropa_lints.dart:2612`
**Diagnostic `source` / `owner`:** `saropa_lints` / `saropaLintsLsp`

---

## Reproducer

Copied from `lib/database/drift_middleware/user_data/activity_drift_extensions_io.dart` lines 205-222 and 298-304 (declarations) and `lib/database/drift_middleware/static_data/emergency/emergency_tip_drift_io.dart` lines 216-220 (call). Standalone:

```dart
enum ActivityType { StaticEmergencyTipAddList, ContactAvatarDeleteAll }

class ActivityModel {
  ActivityModel({required this.activityType, this.metadata});
  final ActivityType activityType;
  final String? metadata;
}

/// Declared in the project's own package, on an extension.
extension ActivityModelExtensions on ActivityModel {
  /// Fire-and-forget: enqueues the write; bool = enqueued/validated.
  bool dbActivityAdd({bool suppressDebugLogging = false}) => true;
}

extension ActivityTypeExtensions on ActivityType {
  bool dbActivityAdd({String? metadata}) =>
      ActivityModel(activityType: this, metadata: metadata).dbActivityAdd();
}

void run(List<int> diffObjects) {
  ActivityModel(
    activityType: ActivityType.StaticEmergencyTipAddList,
    metadata: diffObjects.length.toString(),
  ).dbActivityAdd(); // LINT — should NOT lint (local extension, bool, "add" verb)

  ActivityType.ContactAvatarDeleteAll.dbActivityAdd(); // LINT — should NOT lint
}
```

**Frequency:** Always, every statement-position call of these extensions.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: same convention as `list.add` / `appendNamePart` that the rule already exempts |
| **Actual** | `[avoid_ignoring_return_values] Return value of this invocation is ignored. ...{v2}` at e.g. `emergency_tip_drift_io.dart` 217:7 |

---

## AST Context

```
MethodDeclaration (dbEmergencyTipAddList)
  └─ BlockFunctionBody / TryStatement / Block
      └─ ExpressionStatement                       <- visited (line 4388)
          └─ MethodInvocation (.dbActivityAdd)     <- reported (expression)
              target: InstanceCreationExpression (ActivityModel(...))
```

---

## Root Cause

`code_quality_avoid_rules.dart:4350` `_isMutateVerbName('dbActivityAdd')`: for each prefix it calls `methodName.startsWith(prefix)`. `'dbActivityAdd'.startsWith('add')` is false, so the exemption chain at lines ~4434-4441 (`returnType.isDartCoreBool && _isMutateVerbName(...) && _isDeclaredOnLocalExtension(...)`) is false and the rule reaches `reporter.atNode(expression)` (line ~4467). `_isDeclaredOnLocalExtension` is true here (extension in the project's own package), `isDartCoreBool` is true; the name test is the only failing condition.

---

## Why the code is correct

The call records a log row asynchronously (`unawaited` inside); success or failure is already logged inside. A caller has nothing to do with the flag. The same-package, extension-declared, bool-returning, mutate-verb-named combination is exactly what the rule already treats as safe; only the naming style differs.

---

## Affected project locations

- `lib/database/drift_middleware/user_data/contact_avatar_drift_io.dart:737`, `:1343`
- `lib/database/drift_middleware/user_data/calendar_event_drift_io.dart:616`
- `lib/database/drift_middleware/static_data/contact/contact_rick_morty_drift_io.dart:210`, `:482` (`dbActivityAddForContact`)
- `lib/database/drift_middleware/static_data/emergency/emergency_tip_drift_io.dart:217`
- `lib/database/drift_middleware/static_data/contact/contact_star_wars_drift_io.dart:267`, `:575`
- `lib/database/drift_middleware/static_data/contact/contact_superhero_dc_drift_io.dart:179`
- `lib/database/drift_middleware/static_data/contact/contact_public_figure_drift_io.dart:193`, `:801`
- `lib/database/drift_middleware/user_data/user_preference_reset_homepage_drift_io.dart:45`
- `lib/database/drift_middleware/user_data/app_dialog_activity_sink.dart:40`

(Line numbers approximate; locate by `dbActivityAdd` statements. Many more exist in the project, e.g. `lib/main.dart:626`.)

---

## Suggested Fix

Make `_isMutateVerbName` camelCase-aware anywhere in the name: split the name into camelCase words and accept when the LAST word (or any word) equals a verb (`dbActivityAdd` -> `[db, Activity, Add]`, last word `Add`; `dbActivityAddForContact` -> contains `Add`). Keep the `bool` + local-extension guards so third-party validators stay flagged.

---

## Fixture Cases

```dart
extension E on Model {
  bool dbActivityAdd() => true;
  bool dbActivityAddForContact() => true;
  bool validateEmail() => true;
}

void f(Model m) {
  m.dbActivityAdd();           // expect NO lint
  m.dbActivityAddForContact(); // expect NO lint
  m.validateEmail();           // expect LINT (not a mutate verb)
}
```

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Triggering project/file: `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/static_data/emergency/emergency_tip_drift_io.dart`
