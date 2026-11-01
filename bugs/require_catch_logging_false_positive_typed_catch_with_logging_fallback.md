# BUG: `require_catch_logging` — Flags a typed catch whose purpose is control flow when a later generic catch in the same try logs

**Status: Open**

Created: 2026-10-31
Rule: `require_catch_logging`
File: `lib/src/rules/security/security_network_input_rules.dart` (line ~4574)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

Flags a typed catch whose purpose is control flow when a later generic catch in the same try logs. In a downstream app review, 5 of 9 reported sites for this rule were judged false positives.

---

## Attribution Evidence

```bash
grep -rn "'require_catch_logging'" lib/src/rules/
# lib/src/rules/security/security_network_input_rules.dart:4574:    'require_catch_logging',
```

**Emitter registration:** `lib/src/rules/security/security_network_input_rules.dart:4574`
**Diagnostic `source` as seen in Problems panel:** `saropa_lints`
Negative sibling-repo grep: not needed, the label is unambiguous.

---

## Reproducer

```dart
Map<String, dynamic>? rebuild() {
  try {
    return _rebuild();
  } on _NoV1Rebuild {          // LINT — but should NOT lint: expected control flow
    return null;
  } on Object catch (error, stack) {
    debugException(error, stack); // all unexpected errors are logged here
    return null;
  }
}
```

**Real sites reviewed (Saropa Contacts app):** lib/utils/contact/native_v1_raw_json_hash.dart:39; lib/utils/system/haptics/saropa_haptics.dart:193 (sets a missing-plugin flag, generic catch below logs); lib/utils/_dev/sql_sentinel.dart:101,206,216 (documented silent probe for a missing `.cause` getter).

**Frequency:** Always, for the pattern shown.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the code is correct |
| **Actual** | `[require_catch_logging]` reported at each site above |

---

## Root Cause

The rule evaluates each catch clause in isolation. It ignores that a sibling catch in the same try logs everything unexpected, and that a catch with an explanatory comment on a private control-flow exception type is intentional.

---

## Suggested Fix

Skip a typed catch when another catch clause in the same TryStatement logs, or when the caught type is a private class used for control flow, or when the body is empty with a comment.

---

## Fixture Gap

The fixture for `require_catch_logging` should add an expect-NO-lint case for each pattern in the reproducer, plus a near-miss expect-LINT case where the guard is missing.

---

## Environment

- saropa_lints version: current at time of filing (consumer: Saropa Contacts app)
- Dart SDK version: current stable

---

## Info needed to close

Partly fixed: a typed catch is now skipped when a sibling catch in the same `try` logs or rethrows (covers native_v1_raw_json_hash.dart:39 and saropa_haptics.dart:193).

Still flagged, not fixed: the three `sql_sentinel.dart` sites (101, 206, 216), a documented silent probe with no sibling logging catch. Missing to close:
- Confirmation from the owner that "empty/silent body with an explanatory comment" or "caught type is a private control-flow class" should suppress this rule (a security rule; both signals widen the exemption), or that those sites should use `// ignore:` instead.
- The actual source of those three catch clauses (caught type, body, comment) to build a fixture.
