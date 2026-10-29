# BUG: `avoid_ignoring_return_values` — flags a fire-and-forget project extension that returns `bool` when its name is `dbActivityAdd`

**Status: Open**

Created: 2026-10-29
Rule: `avoid_ignoring_return_values`
File: `lib/src/rules/code_quality/code_quality_avoid_rules.dart` (class ~4263, code ~4282, exemption ~4425)
Severity: False positive
Rule version: v2 | Since: see rule dartdoc | Updated: see rule dartdoc

---

## Summary

The rule has a structural exemption for project-local `extension` methods that return `bool` and are named with a mutate verb (`add*`, `append*`, `insert*`, `remove*`, `update*`, `set*`). The exemption tests only the name PREFIX. The project method `dbActivityAdd()` is the same kind of fire-and-forget mutator, but the verb is a suffix after a `db` prefix, so it is flagged at every call site.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_ignoring_return_values'" lib/src/rules/
# lib/src/rules/code_quality/code_quality_avoid_rules.dart:4282:    'avoid_ignoring_return_values',

# Negative — sibling repo (../saropa_drift_advisor) is not checked out on this machine, so the
# negative grep cannot be run. The diagnostic text below is byte-identical to the LintCode
# message in this repo, plus the `{vN}` suffix, which is the attribution evidence.
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_avoid_rules.dart:4282`; registered at `lib/saropa_lints.dart:2612` (`AvoidIgnoringReturnValuesRule.new`)
**Rule class:** `AvoidIgnoringReturnValuesRule` (`code_quality_avoid_rules.dart:4263`)
**Diagnostic `source` / `owner` as seen in Problems panel:** `source: saropa_lints`, `owner: saropaLintsLsp`

---

## Reproducer

Compiles standalone (plain Dart, no packages). It mirrors the real extensions at
`/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/user_data/activity_drift_extensions_io.dart:213` (`ActivityTypeExtensions.dbActivityAdd`) and `:301` (`ActivityModelExtensions.dbActivityAdd`).

```dart
enum ActivityType { contactGroupDeleteAll }

class ActivityModel {
  const ActivityModel({required this.activityType, this.metadata});
  final ActivityType activityType;
  final String? metadata;
}

/// Fire-and-forget: validates, logs, enqueues the write, returns false only when validation failed.
extension ActivityModelExtensions on ActivityModel {
  bool dbActivityAdd({bool suppressDebugLogging = false, bool validateFields = true}) {
    return true;
  }
}

extension ActivityTypeExtensions on ActivityType {
  bool dbActivityAdd({String? metadata}) => ActivityModel(activityType: this, metadata: metadata).dbActivityAdd();
}

void deleteAll() {
  ActivityType.contactGroupDeleteAll.dbActivityAdd(); // LINT — but should NOT lint (false positive)
  ActivityModel(activityType: ActivityType.contactGroupDeleteAll, metadata: 'x').dbActivityAdd(); // LINT — same
}

void main() => deleteAll();
```

**Frequency:** Always, for each call that discards the `bool`. The rule's own dartdoc says `target.appendNamePart(givenName)` (bool extension mutator) is exempt; only the name shape differs.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic, same as `target.appendNamePart(x)`: a project-local extension method returning `bool` as a "did it happen" flag that call sites deliberately ignore. |
| **Actual** | `[avoid_ignoring_return_values] Return value of this invocation is ignored. Discarding return values can hide bugs where an important result (a Future, a boolean success flag, or a parsed value) is silently lost. Assign the result to a variable or remove the call if it is truly unnecessary. {v2}` at e.g. `contact_points_drift_io.dart` 775:7 (whole expression statement) |

---

## AST Context

```
ClassDeclaration (DatabaseContactPointsIO)
  └─ MethodDeclaration (static dbContactPointsDeleteAll)
      └─ BlockFunctionBody → Block → TryStatement → Block
          └─ ExpressionStatement
              └─ MethodInvocation (ActivityType.ContactPointsDeleteAll.dbActivityAdd())  ← reporter.atNode(expression)
                  methodName.element: MethodElement declared in ExtensionElement `ActivityTypeExtensions`
                  staticType: bool
```

---

## Root Cause

`code_quality_avoid_rules.dart` `runWithReporter` (~4380-4450):

```dart
if (expression is MethodInvocation &&
    methodName != null &&
    returnType != null &&
    returnType.isDartCoreBool &&
    _isMutateVerbName(methodName) &&                       // <-- fails for 'dbActivityAdd'
    _isDeclaredOnLocalExtension(expression.methodName.element, context.filePath)) {
  return;
}
```

`_isMutateVerbName` (~4318) uses `methodName.startsWith(prefix)` for `add|append|insert|remove|update|set` with a camelCase boundary. `dbActivityAdd` starts with `db`, so no prefix matches. Every other condition of the exemption holds (`bool`, declared on an extension, in the project's own package). The built-in `_safeToIgnore` set does not contain it either, and the project config key `safe_to_ignore` lives in a file outside this rule's reach for the fix.

---

## Why the code is correct

`dbActivityAdd()` records an audit-log row. The extension validates, logs, then enqueues the DB write asynchronously ("Fire-and-forget activity recording", `activity_drift_extensions_io.dart` dartdoc). The `bool` is only consumed by one batch-restore loop (`contact_import_records_io.dart:49`) that counts rows. About 190 other call sites deliberately ignore it, because losing one audit row must never block or fail the user action. Assigning to an unused local, or changing the return type to `void` (which breaks the one real consumer), would add noise without removing any risk.

---

## Affected Locations (contacts app)

Line numbers as reported by the diagnostics:

| File | Line |
|---|---|
| `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/user_data/contact_group_drift_io.dart` | 1169, 1641 |
| `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/user_data/contact_points_drift_io.dart` | 775, 917 |
| `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/static_data/country/country_city_drift_io.dart` | 191 |
| `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/user_data/user_preference_save_drift_io.dart` | 165, 285 |
| `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/static_data/country/country_news_media_drift_io.dart` | 140 |
| `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/user_data/facebook_friend_drift_io.dart` | 125, 415 |
| `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/user_data/user_preference_delete_all_drift_io.dart` | 70 |
| `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/static_data/mental_model_drift_io.dart` | 152 |
| `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/static_data/curious_fact_drift_io.dart` | 120 |
| `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/static_data/emergency/emergency_service_delete_drift_io.dart` | 26 |

(`grep -rn "\.dbActivityAdd()" lib/` in the contacts app lists about 190 sites; the same pattern.)

---

## Suggested Fix

Make `_isMutateVerbName` match the verb at the END of a camelCase name as well as at the start: split the name on camelCase boundaries and test whether the first OR last word is in the verb list (`dbActivityAdd` -> last word `Add`). Keep the other three conditions (`bool`, local extension, project package) unchanged, so third-party `bool` validators stay flagged.

---

## Fixture Gap

1. `ActivityType.x.dbActivityAdd();` on a local extension returning `bool` — expect NO lint
2. `model.dbActivityAdd();` same — expect NO lint
3. `list.saveItem(x);` where `saveItem` is a local-extension `bool` method (verb `save` not in list) — expect LINT (unchanged)
4. `thirdPartyExtension.dbThingAdd();` declared in another package — expect LINT (unchanged)
5. `appendNamePart(x)` on local extension — expect NO lint (unchanged)

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- custom_lint version: not used (diagnostic delivered by the `saropaLintsLsp` owner in VS Code, `source: saropa_lints`)
- Triggering project/file: `/Users/craighathaway/Documents/src/contacts` (Flutter app `saropa`); files listed under Affected Locations
