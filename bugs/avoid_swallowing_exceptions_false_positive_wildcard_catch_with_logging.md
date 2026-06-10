# BUG: `avoid_swallowing_exceptions` — Fires on `catch (_)` wildcard even when the body logs

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-10
Rule: `avoid_swallowing_exceptions`
File: `lib/src/rules/flow/error_handling_rules.dart` (line ~77-102)
Severity: False positive
Rule version: v5 | Since: (pre-13.x) | Updated: v13.12.2

---

## Summary

`avoid_swallowing_exceptions` flags any catch clause whose declared exception
parameter is never referenced in the body. When the parameter is the Dart
**wildcard** `_`, it can never be referenced by design — `_` is the
intentional "I am deliberately not naming this" sentinel — yet the rule treats
the unused `_` as a swallowed exception and fires. This happens even when the
catch body clearly handles the situation (logs a debug line, returns a recovery
value). The result: the canonical "expected, deliberately-discarded exception"
pattern (`} on SpecificException catch (_) { … log … return fallback; }`) is
flagged, forcing an `// ignore:` on idiomatic code.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_swallowing_exceptions'" lib/src/rules/
# lib/src/rules/flow/error_handling_rules.dart:65:    'avoid_swallowing_exceptions',

# Negative — rule is NOT in the sibling drift-advisor repo
grep -rn "avoid_swallowing_exceptions" ../saropa_drift_advisor/lib/
# 0 matches
```

**Emitter registration:** `lib/src/rules/flow/error_handling_rules.dart:65`
**Rule class:** `AvoidSwallowingExceptionsRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#5`

---

## Reproducer

```dart
class CapabilityProbe {
  Future<bool> hasEffectiveLocationAccess() async {
    try {
      final Object? position = await _getLastKnownPosition();
      return position != null;
    } on PermissionDeniedException catch (_) {
      // Deliberately discarded: this exception is an EXPECTED control-flow
      // signal during a silent capability probe (permission never requested).
      // The `_` wildcard documents "intentionally not handling the object".
      // Body still LOGS and returns a recovery value — nothing is swallowed.
      _debug('getLastKnownPosition: PermissionDeniedException (no OS grant on file)');
      return false; // LINT — but should NOT lint (false positive)
    }
  }

  Future<Object?> _getLastKnownPosition() async => null;
  void _debug(String _) {}
}

class PermissionDeniedException implements Exception {}
```

**Frequency:** Always, whenever the catch parameter is `_` (or `__`, etc.) — the
wildcard form. The body can log, recover, and return; the rule still fires
because the wildcard is (necessarily) never referenced.

Real site in `d:\src\contacts`:
- `lib/utils/user/native_permissions/location_permission.dart:126` —
  `} on gl.PermissionDeniedException catch (_) { if (DebugType.Location.isDebug) { debug(...); } return false; }`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic. `catch (_)` is the explicit "deliberately ignore this exception object" form; the body logs and returns a recovery value, which is exactly "handled". |
| **Actual** | `[avoid_swallowing_exceptions] Catch block swallows exception without logging, rethrowing, or handling it` reported at the catch clause. |

---

## AST Context

```
MethodDeclaration (hasEffectiveLocationAccess)
  └─ TryStatement
      └─ CatchClause                              ← node reported here
          exceptionType: PermissionDeniedException
          exceptionParameter: CatchClauseParameter (name == '_')   ← wildcard, never referenceable
          └─ Block
              └─ IfStatement(... _debug('...'))   ← logging present
              └─ ReturnStatement(false)           ← recovery value
```

---

## Root Cause

`lib/src/rules/flow/error_handling_rules.dart:77-102`, `runWithReporter`:

```dart
final CatchClauseParameter? exceptionParam = node.exceptionParameter;
if (exceptionParam == null) return;

final String exceptionName = exceptionParam.name.lexeme;   // '_'
bool exceptionUsed = false;
body.visitChildren(
  _IdentifierUsageVisitor(exceptionName, () { exceptionUsed = true; }),
);
if (!exceptionUsed) {
  reporter.atNode(node);   // <-- fires: '_' is never referenced
}
```

The rule's sole signal for "handled" is **whether the named exception variable
is referenced** in the body. The Dart wildcard `_` is, by language semantics, a
non-binding placeholder that cannot be referenced — so `exceptionUsed` is always
`false` for `catch (_)`, and the rule always fires. Two distinct problems:

1. **Wildcard not recognized as deliberate-ignore.** A parameter named `_`
   (and the all-underscores family `__`, `___`) is the canonical "I intend to
   discard this" marker. The rule should treat a wildcard exception parameter as
   intentional and not equate it with swallowing — OR fall through to a
   body-content check instead of the variable-reference check.

2. **No body-content / logging fallback.** Unlike the sibling
   `require_catch_logging` rule (which text-scans the catch body for logging
   tokens and rethrow before flagging — `security_network_input_rules.dart:4354-4368`),
   `avoid_swallowing_exceptions` has no logging/rethrow/recovery detection. Its
   own correction message even accepts "handle it with a user-visible message or
   **recovery action**", but the detection only checks the exception-variable
   reference. A body that logs and returns a recovery value is "handled" by the
   message's own standard, yet still flagged.

---

## Suggested Fix

In `lib/src/rules/flow/error_handling_rules.dart`, `runWithReporter`:

1. **Skip wildcard parameters.** After reading `exceptionName`, return early when
   it is the wildcard:

   ```dart
   final String exceptionName = exceptionParam.name.lexeme;
   // `_` (and `__`, `___`) is Dart's non-binding wildcard: a deliberate
   // "discard this object" marker that cannot be referenced. Treating its
   // (forced) non-use as swallowing flags idiomatic deliberate-ignore catches.
   if (RegExp(r'^_+$').hasMatch(exceptionName)) return;
   ```

2. **Add a logging/rethrow/recovery fallback** (mirroring `require_catch_logging`):
   before reporting, scan `body.toSource()` for the same logging-token /
   `rethrow` / `throw` patterns that `RequireCatchLoggingRule` uses, and a
   `return`/recovery statement, and suppress when present. This aligns detection
   with the rule's own correction message ("log, rethrow, or handle with a
   recovery action") and removes the double-jeopardy with `require_catch_logging`,
   which already owns the "no logging" concern.

The minimal fix is (1); (2) closes the broader gap and is recommended.

---

## Fixture Gap

The fixture at `example*/lib/flow/avoid_swallowing_exceptions_fixture.dart`
should include:

1. `} on FooException catch (_) { log('...'); return fallback; }` — expect NO lint (wildcard + logging + recovery)
2. `} on FooException catch (_) { return fallback; }` — design decision: with fix (1) expect NO lint (wildcard is deliberate); without fix (2) this still recovers
3. `} catch (e) { /* never uses e */ doUnrelated(); }` — expect LINT (named param genuinely unused, true positive)
4. `} catch (e) { log(e); }` — expect NO lint (named param used, regression guard)

---

## Environment

- saropa_lints version: 13.12.2
- Dart SDK version: >=3.9.0 <4.0.0 (per pubspec environment constraint)
- analyzer: >=9.0.0 <13.0.0
- Triggering project/file: `d:\src\contacts` — `lib/utils/user/native_permissions/location_permission.dart:126`
