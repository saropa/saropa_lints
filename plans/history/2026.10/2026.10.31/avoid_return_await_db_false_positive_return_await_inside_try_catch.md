# BUG: `avoid_return_await_db` — Flags `return await dbCall()` inside try/catch, where the await is required for the catch to see async errors

**Status: Fixed**

Created: 2026-10-31
Rule: `avoid_return_await_db`
File: `lib/src/rules/resources/db_yield_rules.dart` (line ~537)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

Flags `return await dbCall()` inside try/catch, where the await is required for the catch to see async errors. In a downstream app review, 21 of 23 reported sites for this rule were judged false positives.

---

## Attribution Evidence

```bash
grep -rn "'avoid_return_await_db'" lib/src/rules/
# lib/src/rules/resources/db_yield_rules.dart:537:    'avoid_return_await_db',
```

**Emitter registration:** `lib/src/rules/resources/db_yield_rules.dart:537`
**Diagnostic `source` as seen in Problems panel:** `saropa_lints`
Negative sibling-repo grep: not needed, the label is unambiguous.

---

## Reproducer

```dart
Future<bool> persist() async {
  try {
    return await DatabaseContactIO.dbContactUpdate(contact: contact); // LINT — but should NOT lint
  } on Object catch (error, stack) {
    debugException(error, stack);
    return false;
  }
}
```

**Real sites reviewed (Saropa Contacts app):** lib/utils/contact/email/email_default_channel_service.dart:142; lib/utils/contact/native_contact_write_verify.dart:22; lib/utils/contact/phone/phone_default_channel_service.dart:182; lib/database/drift_middleware/user_data/event_action_drift_io.dart:252; and 17 more with the same shape.

**Frequency:** Always, for the pattern shown.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the code is correct |
| **Actual** | `[avoid_return_await_db]` reported at each site above |

---

## Root Cause

Without `await`, the returned future completes after the try block exits, so the catch never runs. The Dart lint `unnecessary_await_in_return` itself exempts this case. The rule does not check for an enclosing TryStatement (or `finally`).

---

## Suggested Fix

Skip when the ReturnStatement is inside the body of a TryStatement that has at least one catch clause or a finally block.

---

## Fixture Gap

The fixture for `avoid_return_await_db` should add an expect-NO-lint case for each pattern in the reproducer, plus a near-miss expect-LINT case where the guard is missing.

---

## Environment

- saropa_lints version: current at time of filing (consumer: Saropa Contacts app)
- Dart SDK version: current stable

---

## Resolution

Fixed in `AvoidReturnAwaitDbRule`: a `return await <db write>` inside the body of a `TryStatement` with at least one catch clause or a finally block is skipped. Returns in catch/finally clauses or unguarded code still lint. Fixture cases added (try/catch, try/finally good; return in catch bad) and verified with `dart run saropa_lints:scan --tier comprehensive` on a scratch copy (3 expected hits only).
