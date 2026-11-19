# BUG: `require_unique_iv_per_encryption` — flags a constant that is only the IV length

**Status: Open**

Created: 2026-10-28
Rule: `require_unique_iv_per_encryption`
File: `lib/src/rules/security/crypto_rules.dart` (line ~500)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: 17.0.1-beta.1

---

## Summary

`const int _credentialIvLength = 12;` is flagged as a static IV. It is the byte length passed to `IV.fromSecureRandom`. Each message gets a fresh random IV, so IV reuse does not occur.

---

## Attribution Evidence

```bash
grep -rn "'require_unique_iv_per_encryption'" lib/src/rules/
# lib/src/rules/security/crypto_rules.dart:500:    'require_unique_iv_per_encryption',
```

---

## Reproducer

```dart
import 'package:encrypt/encrypt.dart' as encrypt;

const int _credentialIvLength = 12; // LINT — but should NOT lint (length, not an IV value)

/// Fresh random 12-byte IV (GCM nonce) per message.
encrypt.IV _newCredentialIv() => encrypt.IV.fromSecureRandom(_credentialIvLength);
```

**Frequency:** Any int constant with `iv` in its name.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic |
| **Actual** | `[require_unique_iv_per_encryption]` on the constant |

---

## Suggested Fix

Only flag constants of IV type or byte-array/string literals used to build an `IV`. Ignore `int` constants, and names ending in `Length`, `Size`, `Bytes`.

---

## Environment

- saropa_lints version: 17.0.1-beta.1
- Triggering project/file: saropa contacts app — `lib/utils/system/encryption/encryption_utils.dart:50`
