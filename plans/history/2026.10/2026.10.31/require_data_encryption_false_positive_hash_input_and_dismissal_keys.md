# BUG: `require_data_encryption` — Flags SharedPreferences-style writes whose key/value is a hash input or a dismissal flag, not sensitive data

**Status: Open**

Created: 2026-10-31
Rule: `require_data_encryption`
File: `lib/src/rules/security/security_auth_storage_rules.dart` (line ~1370)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

Flags SharedPreferences-style writes whose key/value is a hash input or a dismissal flag, not sensitive data. In a downstream app review, 6 of 6 reported sites for this rule were judged false positives.

---

## Attribution Evidence

```bash
grep -rn "'require_data_encryption'" lib/src/rules/
# lib/src/rules/security/security_auth_storage_rules.dart:1370:    'require_data_encryption',
```

**Emitter registration:** `lib/src/rules/security/security_auth_storage_rules.dart:1370`
**Diagnostic `source` as seen in Problems panel:** `saropa_lints`
Negative sibling-repo grep: not needed, the label is unambiguous.

---

## Reproducer

```dart
static Future<void> dismiss(SuccessMilestone milestone) =>
    SuccessCardGate.write(<String>[SuccessCardGate.milestoneKey(milestone.id)]); // LINT — but should NOT lint
// Key is a card id; stored value is a dismissal marker.
```

**Real sites reviewed (Saropa Contacts app):** lib/utils/success_cards/success_milestone.dart:103, cleanup_card_resolver.dart:137, weekly_digest_resolver.dart:84, contact_anniversary_resolver.dart:207; lib/utils/contact/native_read_hash.dart:71 and :90 (StringBuffer building a hash input, `write` is StringBuffer.write).

**Frequency:** Always, for the pattern shown.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the code is correct |
| **Actual** | `[require_data_encryption]` reported at each site above |

---

## Root Cause

The rule matches the method name `write` (and similar) on any receiver, including `StringBuffer.write`, and does not consider whether the key or payload is sensitive.

---

## Suggested Fix

Restrict to receivers whose static type is a storage API (SharedPreferences, file, Hive box), and require a sensitive key name or value type (token, password, secret). Exclude `StringBuffer`/`StringSink`.

---

## Fixture Gap

The fixture for `require_data_encryption` should add an expect-NO-lint case for each pattern in the reproducer, plus a near-miss expect-LINT case where the guard is missing.

---

## Environment

- saropa_lints version: current at time of filing (consumer: Saropa Contacts app)
- Dart SDK version: current stable

---

## Resolution

Fixed in `lib/src/rules/security/security_auth_storage_rules.dart`:

- A receiver whose static type is `StringBuffer` or `StringSink` is skipped (covers `native_read_hash.dart:71/:90`).
- For a static call on a capitalised class receiver, the `ClassName.` qualifier is stripped from the scanned arguments, so `SuccessCardGate.write([SuccessCardGate.milestoneKey(id)])` no longer matches "card" from the class name (covers the four success-card resolver sites). `Secret.write(Secret.password)` and `Secret.write(secretValue)` still flag.

Fixture: `example/lib/security/require_data_encryption_fixture.dart` (new good cases and a near-miss bad case). Verified with `dart run saropa_lints:scan --resolve --tier comprehensive` on a scratch copy: only the sensitive-payload cases flagged. Rule tests and `dart analyze` pass.
