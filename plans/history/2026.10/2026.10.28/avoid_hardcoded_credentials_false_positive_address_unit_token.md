# BUG: `avoid_hardcoded_credentials` — flags the string `'unit'` as a credential

**Status: Open**

Created: 2026-10-28
Rule: `avoid_hardcoded_credentials`
File: `lib/src/rules/security/security_auth_storage_rules.dart` (lines ~39 and ~199; the name is registered twice)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: 17.0.1-beta.1

---

## Summary

A constant named `_unitToken` with value `'unit'` (an address normalization token for apartment/flat/suite) is flagged. The name contains `token`, so the rule treats the literal as a secret. A short plain word is not a credential.

---

## Attribution Evidence

```bash
grep -rn "'avoid_hardcoded_credentials'" lib/src/rules/
# lib/src/rules/security/security_auth_storage_rules.dart:39:    'avoid_hardcoded_credentials',
# lib/src/rules/security/security_auth_storage_rules.dart:199:    'avoid_hardcoded_credentials',
```

Note: two classes use the same rule name; the fix agent should check which one fires.

---

## Reproducer

```dart
class AddressNormalizer {
  /// Canonical token for the unit designator (apartment, flat, suite).
  static const String _unitToken = 'unit'; // LINT — but should NOT lint
}
```

**Frequency:** Any `*token*` named constant holding a short plain-word literal.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic. Linguistic token, not an auth token |
| **Actual** | `[avoid_hardcoded_credentials]` on the literal |

---

## Suggested Fix

Do not match the bare word `token` in the variable name; require `authToken`, `accessToken`, `apiToken`, `bearer` etc. Or require the literal to look like a secret (length, mixed character classes, or known prefixes).

---

## Environment

- saropa_lints version: 17.0.1-beta.1
- Triggering project/file: saropa contacts app — `lib/utils/address/address_normalize_utils.dart:34`
