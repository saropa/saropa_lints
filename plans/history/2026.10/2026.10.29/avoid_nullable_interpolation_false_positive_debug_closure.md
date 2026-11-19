# BUG: `avoid_nullable_interpolation` — False Positive: Interpolation Inside a `debug(() => '...')` Closure

**Status: Fixed**

Created: 2026-10-29
Rule: `avoid_nullable_interpolation`
File: `lib/src/rules/data/type_rules.dart` (line ~567, `_isInsideDeveloperLogCall`)
Severity: False positive
Rule version: v8 | Since: unknown | Updated: 17.0.1-beta.2

---

## Summary

The rule exempts a nullable value interpolated directly into `debug('...')` (developer log call), but not when the message is passed as a closure, `debug(() => '...')`. The closure form is the lazy-message idiom of the app's `debug` helper. The AST walk stops at the closure's `ExpressionFunctionBody` and returns false, so the same developer-log text is flagged.

---

## Attribution Evidence

```bash
grep -rn "'avoid_nullable_interpolation'" lib/src/rules/
# lib/src/rules/data/type_rules.dart:459:    'avoid_nullable_interpolation',
```

**Emitter registration:** `lib/src/rules/data/type_rules.dart:459`
**Rule class:** `AvoidNullableInterpolationRule` (type_rules.dart:440), registered in `lib/saropa_lints.dart:549`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` / `saropaLintsLsp`

---

## Reproducer

Standalone, compiles with `dart run`. Mirrors `contact_import_io.dart:157` where `contactSaropaUUID` is `String?` on the model.

```dart
// Mirrors the app's debug helper: the message may be a String or a lazy closure.
void debug(Object message, {int level = 0}) {
  final Object resolved = message is String Function() ? message() : message;
  print(resolved);
}

class ContactModel {
  ContactModel({this.contactSaropaUUID});
  String? contactSaropaUUID; // nullable, like the real model
}

void main() {
  final ContactModel contact = ContactModel();

  // OK: direct string argument, exempt via _isInsideDeveloperLogCall.
  debug('Restore add failed: `${contact.contactSaropaUUID}`');

  // LINT, but should NOT lint: same developer log text, wrapped in a closure.
  debug(() => 'Restore add failed: `${contact.contactSaropaUUID}`');
}
```

**Frequency:** Always, for every `debug(() => '...$nullable...')`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the literal "null" in a log line is the diagnostic signal (the rule's own comment at type_rules.dart:468-472 says so) |
| **Actual** | `[avoid_nullable_interpolation] Nullable value in string interpolation produces the literal text 'null' instead of a meaningful fallback. Users may see 'Hello null' or 'Order #null' in the UI, which looks like a bug and erodes trust in the application quality and data integrity. {v8}` at the interpolation, e.g. `contact_import_io.dart` 157:65 |

---

## AST Context

```
MethodInvocation (debug)                       <- the developer log call
  └─ ArgumentList
      └─ FunctionExpression  (() => ...)
          └─ ExpressionFunctionBody            <- walk stops here: `current is FunctionBody` -> return false
              └─ StringInterpolation
                  └─ InterpolationExpression (${contact.contactSaropaUUID})  <- node reported
                      └─ PrefixedIdentifier (contact.contactSaropaUUID)  staticType String?
```

---

## Root Cause

`type_rules.dart:567-586`, `_isInsideDeveloperLogCall`, walks `node.parent` upward. The first ancestor reached is `StringInterpolation`, then `ExpressionFunctionBody`. At line 581 the loop has `if (current is FunctionBody) return false;` ("Stop at any function body"). A `MethodInvocation` named `debug` exists above the closure, but the walk never reaches it. The `FunctionBody` stop is meant to stop attributing a log call in one scope to code in another scope. For an immediately-passed closure argument of the log call itself, that cut is wrong: the closure body is the log message.

---

## Why the code is correct

The string is only built when debug logging is on, and only goes to the developer log. No user sees it. The nullable value is logged on purpose so a missing UUID shows as `null` in the log. Adding `?? ''` would hide the very failure the line reports.

---

## Affected project locations (saropa contacts app, scan of 2026-10-29; line numbers as scanned)

- `lib/database/drift_middleware/event_data/event_range_io.dart:386:43` (`options.includeEventTypes`, `List<EventLabelTypes>?`)
- `lib/database/drift_middleware/event_data/event_range_io.dart:652:30` (`range`, `DateTimeRange?`)
- `lib/database/drift_middleware/static_data/contact/contact_star_trek_drift_io.dart:574:31` (`speciesName`, `String?`)
- `lib/database/file_backup/import/contact_import_io.dart:157:65` (`contact.contactSaropaUUID`, `String?`)
- `lib/database/file_backup/import/contact_import_io.dart:202:68` (`contact.contactSaropaUUID`, `String?`)
- `lib/database/drift_middleware/user_data/contact_query_io.dart:157:49` (`allContactFromDatabase?.length`, `int?`, inside `debug(() => '...')`)
- `lib/database/drift_middleware/static_data/emergency/emergency_service_list_drift_io.dart:28:53` (`phoneNumber`, `String?`)
- `lib/database/drift_middleware/static_data/emergency/emergency_service_list_drift_io.dart:57:44` (`phoneNumber`, `String?`, adjacent-string closure)
- `lib/database/drift_middleware/static_data/emergency/emergency_service_list_drift_io.dart:64:40` (`phoneNumber`, `String?`, adjacent-string closure)
- `lib/database/models/schema/user_data/coaching_session_db_model.dart:261:42` (`sessionStatusJson`, `String?`, adjacent-string closure with `level:` named argument)
- `lib/database/drift_middleware/user_data/personality_quiz_drift_io.dart:364:48` (`id`, `int?`, `debug(() => 'Missing or invalid [id]: `$id`', level: DebugLevels.Warning)`)
- `lib/database/drift_middleware/user_data/contact_group_drift_io.dart:1184:17` (`contactGroupName`, `String?`; multi-line `debug(() => ...)` message)
- `lib/database/drift_middleware/user_data/contact_group_drift_io.dart:1185:48` (`contactGroupSaropaUUID`, `String?`)
- `lib/database/drift_middleware/user_data/contact_group_drift_io.dart:2037:19` (`contactGroupSaropaUUID`, `String?`)
- `lib/database/drift_middleware/user_data/contact_group_drift_io.dart:2083:46` (`groupName`, `String?`; `debug(() => 'Missing [groupName]: `$groupName`', level: DebugLevels.Warning);`)
- `lib/database/drift_middleware/user_data/contact_group_drift_io.dart:2183:42` (`contactGroupSaropaUUID`, `String?`)
- `lib/database/drift_middleware/user_data/contact_group_drift_io.dart:2197:16` (`contactGroupSaropaUUID`, `String?`)
- `lib/database/drift_middleware/user_data/user_preference_delete_all_drift_io.dart:147:50` (`deletedCount`, `int?`; `debug(() => '[boxUserPreferences] Removed `$deletedCount`');`)
- `lib/database/drift_middleware/user_data/contact_drift_io.dart:1815:61` (`activityType`, `ActivityType?`)
- `lib/database/drift_middleware/user_data/contact_drift_io.dart:1825:71` (`contact.name.sentenceName`)
- `lib/database/drift_middleware/user_data/contact_drift_io.dart:2502:131` (`existing.contactSaropaUUID`, `String?`)
- `lib/database/drift_middleware/user_data/contact_drift_io.dart:2596:65` (`contactSaropaUUID`, local `String?` reassigned earlier in the method, so not promoted inside the closure)
- `lib/database/drift_middleware/static_data/medical_condition_drift_io.dart:370:29` (`group?.name`)
- `lib/database/drift_middleware/static_data/contact/contact_superhero_marvel_drift_io.dart:388:29` (`group?.name`)
- `lib/database/drift_middleware/user_data/activity_drift_extensions_io.dart:87:19` (`activityDb.activityType`, `ActivityType?`; non-null proved by an earlier `activityDb.activityType == null` return that does not promote a property)
- `lib/database/file_backup/backup_export_dispatcher.dart:336:71` (`count`, `int?`, after `count == null || count <= 0` returned)
- `lib/database/file_backup/backup_export_dispatcher.dart:345:79` (`report?.length`, `int?`)

---

## Suggested Fix

In `_isInsideDeveloperLogCall`, when the walk reaches a `FunctionBody` whose parent is a `FunctionExpression` that is a direct argument of a `MethodInvocation` (or sits in a named argument), continue the walk from that `FunctionExpression` instead of returning false. Keep the stop for every other `FunctionBody` (method and function declarations, closures stored in variables).

---

## Fixture Gap

Fixture for `avoid_nullable_interpolation` should include:

1. `debug('x ${nullable}')` — expect NO lint (exists)
2. `debug(() => 'x ${nullable}')` — expect NO lint
3. `debug(() => 'x ' 'y ${nullable}', level: Warning)` (adjacent strings, named arg) — expect NO lint
4. `final cb = () => 'x ${nullable}'; debug(cb)` — expect LINT (closure not a direct argument)
5. `Text(() { return 'x ${nullable}'; }())` — expect LINT

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- custom_lint version: not used (analyzer plugin via VS Code extension)
- Triggering project/file: Saropa contacts app, `lib/database/file_backup/import/contact_import_io.dart:157`

---

## Additional affected locations (appended 2026-10-29)

Same lazy `debug(() => '...')` closure pattern (`_isInsideDeveloperLogCall`, `lib/src/rules/data/type_rules.dart:567`, stops at `if (current is FunctionBody) return false;` line 581). Lines as reported by the diagnostics, project `contacts`:

- `/Users/craighathaway/Documents/src/contacts/lib/database/models/schema/user_data/contact_group_db_model.dart` 207:17-207:34 and 207:56-207:86 (`$contactGroupName`, `${modelContactGroupType?.name}`), 368:41-368:58 (`$jsonIndustryType`), 382:45-382:66 (`$jsonContactGroupType`)
- `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/static_data/contact/contact_harry_potter_drift_io.dart` 453:29-453:58 (`${harryPotterHouseName?.name}`)
- `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/event_data/contact_event_io.dart` 346:32-346:38 (`debug(() => '[range]: `$range`')`)
