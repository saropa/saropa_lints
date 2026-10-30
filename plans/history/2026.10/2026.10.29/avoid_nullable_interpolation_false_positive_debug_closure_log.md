# BUG: `avoid_nullable_interpolation` — developer-log exemption skipped for the lazy closure form `debug(() => '...$x')`

**Status: Fixed**

Created: 2026-10-29
Rule: `avoid_nullable_interpolation`
File: `lib/src/rules/data/type_rules.dart` (line ~459; `_isInsideDeveloperLogCall` ~567)
Severity: False positive
Rule version: v8 | Since: unknown | Updated: 17.0.1-beta.2

---

## Summary

The rule intentionally exempts nullable interpolations inside `debug(...)`, `print(...)`, `log(...)` etc. (`_developerLogCallTargets`, line ~481). The exemption walk stops at the first `FunctionBody`, so `debug(() => 'x $nullable')` (a lazy-message closure, the common logging form in this project) is never recognized and the rule reports it.

---

## Attribution Evidence

```bash
grep -rn "'avoid_nullable_interpolation'" lib/src/rules/
# lib/src/rules/data/type_rules.dart:459:    'avoid_nullable_interpolation',
```

**Emitter registration:** `lib/src/rules/data/type_rules.dart:459`
**Rule class:** `AvoidNullableInterpolationRule` (type_rules.dart:440) — registered in `lib/saropa_lints.dart:549`
**Diagnostic `source` / `owner`:** `saropa_lints` / `saropaLintsLsp`

---

## Reproducer

Copied from `lib/database/drift_middleware/user_data/contact_avatar_drift_io.dart` lines 1469-1474 and `lib/database/drift_middleware/user_data/calendar_event_drift_io.dart` line 775. `debug` is the project's lazy log helper (`lib/utils/_dev/debug.dart`); a standalone stand-in:

```dart
// Stand-in for the project's lib/utils/_dev/debug.dart helper.
void debug(Object? messageOrBuilder, {int? level}) {}

class Example {
  static void missingAvatar(String? contactSaropaUUID) {
    debug(() => 'Missing [avatar] for [contactSaropaUUID] `$contactSaropaUUID`'); // LINT — should NOT lint
  }

  static void saved(int? count, int skippedCount) {
    debug(() => 'Batch saved $count events (skipped $skippedCount duplicates)'); // LINT — should NOT lint
  }

  static void species(String? name) {
    debug(
      () =>
          'Found rows '
          'for [species]: ${name?.length}', // LINT — should NOT lint
    );
  }
}
```

**Frequency:** Always, for every `debug(() => ...)` / `print(() => ...)` closure form with a nullable interpolation.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic (developer-facing log output; the rule's own doc says the literal "null" is the diagnostic signal) |
| **Actual** | `[avoid_nullable_interpolation] Nullable value in string interpolation produces the literal text 'null' instead of a meaningful fallback. ... {v8}` e.g. `contact_avatar_drift_io.dart` 1473:60-1473:78, `calendar_event_drift_io.dart` 784:34 |

---

## AST Context

```
MethodDeclaration (_debugMissingAvatar)
  └─ BlockFunctionBody
      └─ ExpressionStatement
          └─ MethodInvocation (debug)                       <- the exempt call target
              └─ ArgumentList
                  └─ FunctionExpression  (() => ...)
                      └─ ExpressionFunctionBody             <- walk STOPS here (type_rules.dart:581)
                          └─ StringInterpolation
                              └─ InterpolationExpression ($contactSaropaUUID)  <- reported
```

---

## Root Cause

`type_rules.dart:567-586` `_isInsideDeveloperLogCall` walks up from the `InterpolationExpression`:

```
if (current is MethodInvocation) return _developerLogCallTargets.contains(current.methodName.name);
if (current is FunctionExpressionInvocation) return false;
if (current is InstanceCreationExpression) return false;
if (current is FunctionBody) return false;     // line 581
```

For the closure form the parent chain is `StringInterpolation -> ExpressionFunctionBody -> FunctionExpression -> ArgumentList -> MethodInvocation(debug)`. `ExpressionFunctionBody` is a `FunctionBody`, so line 581 returns `false` before the `MethodInvocation(debug)` is reached. The comment on that line ("a log call in one scope ... interpolation in another") targets a body that contains statements; a single-expression closure passed directly as an argument to the log call is the same scope.

---

## Why the code is correct

The strings are developer log messages built lazily (`debug(() => ...)` evaluates the closure only when debug output is enabled). A literal "null" in a log line is the intended signal; no user ever sees it.

---

## Affected project locations

- `lib/database/drift_middleware/user_data/contact_avatar_drift_io.dart:1311` (`${row?.image.length}`), `:1312`, `:1321` (`$contactSaropaUUID`), `:1473`
- `lib/database/drift_middleware/user_data/calendar_event_drift_io.dart:784`
- `lib/database/drift_middleware/static_data/contact/contact_rick_morty_drift_io.dart:400` (`${species?.name}`)
- `lib/database/drift_middleware/static_data/contact/contact_star_wars_drift_io.dart:500`
- `lib/database/drift_middleware/static_data/contact/contact_superhero_dc_drift_io.dart:408` (`${group?.name}`)
- `lib/database/drift_middleware/user_data/user_preference_reset_homepage_drift_io.dart:85`
- `lib/database/models/schema/user_data/calendar_event_db_model.dart:185`

(Line numbers are approximate after local edits; locate by message.)

---

## Suggested Fix

In `_isInsideDeveloperLogCall`, treat an `ExpressionFunctionBody` whose `FunctionExpression` is a direct argument of a call as transparent: when `current is FunctionBody`, continue the walk if `current.parent is FunctionExpression` and that expression's parent is an `ArgumentList` (or `NamedExpression` inside one); only stop on a `BlockFunctionBody` that is not directly an argument. Then the `MethodInvocation` check on the next hops decides.

---

## Fixture Cases

```dart
void debug(Object? m) {}

void f(String? s) {
  debug(() => 'a $s');            // expect NO lint
  debug(() => 'a ${s?.length}');  // expect NO lint
  print('a $s');                  // expect NO lint (already works)
  final Widget w = Text('a $s');  // expect LINT (UI text)
  final String t = 'a $s';        // expect LINT
  final Function g = () => 'a $s'; // expect LINT (closure not passed to a log call)
}
```

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Triggering project/file: `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/user_data/contact_avatar_drift_io.dart`
