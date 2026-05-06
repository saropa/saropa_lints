# BUG: `require_data_encryption` — Already-Encrypted Value Wrongly Flagged

**Status: Fixed**

Created: 2026-04-29
Rule: `require_data_encryption`
File: `lib/src/rules/security/security_auth_storage_rules.dart` (line ~1213)
Severity: False positive
Rule version: v6 | Since: ? | Updated: 2026-04-29

---

## Summary

The rule fires on `db.update(...).write(Companion(privateKey: Value(encryptedPrivateKey), ...))` when the value passed in has already been encrypted upstream. The rule's keyword check operates on the lowercased argument source — so a parameter NAMED `privateKey` (or anything containing the substring `privatekey`/`password`/`secret`/`token`) is flagged regardless of whether the value being passed is plaintext or ciphertext. The rule does not look for `encrypt*` patterns inside the argument expression, only inside the receiver (target). It cannot tell that a variable named `encryptedPrivateKey` is the result of `toFirebaseEncrypted(...)`.

---

## Attribution Evidence

```bash
# Positive
grep -rn "'require_data_encryption'" lib/src/rules/
# lib/src/rules/security/security_auth_storage_rules.dart:1242:    'require_data_encryption',

# Negative
grep -rn "'require_data_encryption'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/src/rules/security/security_auth_storage_rules.dart:1242`
**Rule class:** `RequireDataEncryptionRule`
**Diagnostic `source` / `owner`:** `dart`

---

## Reproducer

Real source: `d:/src/contacts/lib/database/drift_middleware/user_data/user_public_private_keys_drift_io.dart` lines 65–76 (the UPDATE branch).

```dart
// privateKey is encrypted BEFORE storage:
String? encryptedPrivateKey = toFirebaseEncrypted(keysToSave.privateKey);
if (encryptedPrivateKey == null) return false;

// LINT — but should NOT lint. The value passed is already ciphertext;
// the variable name signals that, and the upstream encryption is in the
// same function. The rule cannot data-flow this and over-reports.
await (db.update(db.userPublicPrivateKeys)..where(...))
    .write(
      UserPublicPrivateKeysCompanion(
        privateKey: Value<String?>(encryptedPrivateKey),  // already encrypted
        publicKey: Value<String?>(keysToSave.publicKey),
        updatedAt: Value<DateTime?>(now),
      ),
    );
```

The rule's argument-source check lowercases the source to `userpublicprivatekeyscompanion(privatekey: value<string?>(encryptedprivatekey), ...)`. That string contains the keyword `privatekey` from the **field name** (and also from the **prefix of `encryptedprivatekey`**), so the rule reports.

**Frequency:** Always — fires on any Drift `Companion` insert/update where the field is named with a sensitive keyword, even when the assigned value is already encrypted.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the argument expression is a variable whose source name contains `encrypt*` (e.g., `encryptedPrivateKey`, `cipherText`, `aesEncoded`), OR when the local declaration of that variable is the return value of a method whose name contains `encrypt`/`cipher`/`hash` (e.g., `toFirebaseEncrypted(...)`). The current keyword scan over the lowercased argument source matches the FIELD NAME `privateKey` which is structurally required by the schema and unavoidable. |
| **Actual** | `[require_data_encryption] Unencrypted sensitive data exposes credentials...` reported on the entire `await ...write(...)` expression. |

---

## AST Context

```
ExpressionStatement
  └─ AwaitExpression
      └─ MethodInvocation (write)                ← rule visits via addMethodInvocation, methodName == 'write'
          ├─ realTarget: ParenthesizedExpression
          │    └─ CascadeExpression
          │        └─ MethodInvocation (db.update)
          └─ argumentList
              └─ InstanceCreationExpression (UserPublicPrivateKeysCompanion)
                  └─ NamedExpression (privateKey)   ← keyword "privatekey" appears in the source string
                      └─ InstanceCreationExpression (Value<String?>)
                          └─ SimpleIdentifier (encryptedPrivateKey)  ← already-ciphertext signal ignored
```

---

## Root Cause

`RequireDataEncryptionRule.runWithReporter` (lines 1284–1318):

- The rule allowlists callers whose **target** (e.g., `secureStorage`, `encryptedBox`) source matches `\bsecure\b`, `\bencrypt\b`, `\bencryptedbox\b`.
- For the report check, it only inspects the **argument** source for sensitive keywords.
- It does NOT also check the argument source for `encrypt*` patterns (which would signal the value is already ciphertext).

```dart
final String argsSource = node.argumentList.toSource().toLowerCase();
if (_pinKeywordPattern.hasMatch(argsSource)) {
  reporter.atNode(node);
  return;
}
for (final String keyword in _sensitiveKeywords) {
  if (argsSource.contains(keyword)) {
    reporter.atNode(node);
    return;
  }
}
```

Drift schemas force the field to be named `privateKey` (the column it maps to). That field name is unavoidable and gets lowercased into `privatekey` which matches the keyword set. The user has no way to satisfy the rule without renaming the schema column, which is a bigger change than the rule should compel.

### Hypothesis A — Add an "already-encrypted" signal escape

If the argument source (lowercased) ALSO matches one of the `_secureStorageTargetPatterns` (`\bsecure\b`, `\bencrypt\b`, `\bencryptedbox\b`), treat the call as safe and skip. This is symmetric with the existing target check and catches the common case where the variable name on the right-hand side carries the encryption signal (`encryptedPrivateKey`, `encryptedToken`, `encryptedPassword`).

### Hypothesis B — Walk the argument's static element to the assignment site

Heavier: resolve `SimpleIdentifier.staticElement`, find the local `VariableDeclaration`, look at the initializer expression, and check whether it is a call to a function whose name matches `encrypt`/`cipher`/`hash`. More precise but more expensive.

Hypothesis A is the cheap, targeted fix that follows the same pattern as the existing target check.

---

## Suggested Fix

In `lib/src/rules/security/security_auth_storage_rules.dart`, after the target-allowlist check and before the keyword scan:

```dart
// Symmetric with the target check above: if the argument expression itself
// carries an "encrypt"/"secure" signal (e.g., `Value(encryptedPrivateKey)`,
// `cipherToken`, `aesEncodedSecret`), treat the call as safe. The argument's
// lowercased source string is what the keyword scan operates on, so this
// check uses the same string.
if (_secureStorageTargetPatterns.any((p) => p.hasMatch(argsSource))) {
  return;
}
```

Bump rule version to v6. Update the rule's docstring with a "Not flagged" section listing both target-side and argument-side signals.

Optionally, also document for downstream users that the recommended naming convention for already-ciphertext locals is `encrypted*` / `cipher*` / `aes*`, so that this rule can statically detect them.

---

## Fixture Gap

`example*/lib/security/require_data_encryption_fixture.dart` should include:

1. `db.write(Companion(privateKey: Value(plaintext)))` — expect LINT (regression: plaintext storage of a sensitive field)
2. `db.write(Companion(privateKey: Value(encryptedPrivateKey)))` — expect NO lint (NEW: already-ciphertext signal in arg)
3. `secureStorage.write(key: 'password', value: x)` — expect NO lint (existing target-allowlist case)
4. `db.insert(...privateKey: Value(cipherText)...)` — expect NO lint (NEW)
5. `db.insert(...token: Value(aesEncodedToken)...)` — expect NO lint (NEW)

---

## Changes Made

- `RequireDataEncryptionRule`: after computing the lowercased argument-list source, skip reporting when the same string matches the same heuristics used for "safe" storage targets (e.g. `secure` / `encrypt` / `encryptedbox`) or additional argument-only patterns: `\bencrypted\w*`, `\bcipher\w*`, `\baes\w*`, and `encrypted\(` (method names ending in `…Encrypted(`). This avoids false positives when Drift/ORM `Companion` field names (e.g. `privateKey:`) appear next to `Value(encryptedPrivateKey)` or similar. Rule version bumped to **v6** (diagnostic text and class doc). Fixture and pin-pattern unit tests extended.

---

## Tests Added

- `test/require_data_encryption_pin_pattern_test.dart` — `group('require_data_encryption argument encryption signal', …)` for the new regex set (Drift-style args, `encrypted(`, and `unencrypted` non-match).
- `example/lib/security/require_data_encryption_fixture.dart` — Drift-style BAD (plaintext) and GOOD (encrypted / cipher / aes / `toFirebaseEncrypted`).

---

## Commits

- `84b97a64` — `fix: require_data_encryption v6 skip pre-encrypted arg text`

---

## Environment

- saropa_lints version: 12.8.4
- Dart SDK version: Flutter 3.x channel
- custom_lint version: native analyzer plugin (no custom_lint)
- Triggering project/file: `d:/src/contacts/lib/database/drift_middleware/user_data/user_public_private_keys_drift_io.dart` (UPDATE path lines 65–76; the INSERT path's existing `// ignore:` was already silencing this same FP)
