# BUG: `require_data_encryption` — flags a Drift update that writes `null` to clear stored credentials

**Status: Fixed**

Created: 2026-10-29
Rule: `require_data_encryption`
File: `lib/src/rules/security/security_auth_storage_rules.dart` (line ~1517-1600)
Severity: False positive
Rule version: v7 | Since: unknown | Updated: 17.0.1-beta.3 (project pins 17.0.1-beta.2)

---

## Summary

The rule reports a `.write(...)` call whose arguments name a credential column (`token`, `refreshToken`, `authorizationCode`) even when every value written is `Value<String?>(null)`. The call removes sensitive data. No sensitive data is stored. It should not report.

---

## Attribution Evidence

```bash
grep -rn "'require_data_encryption'" lib/src/rules/
# lib/src/rules/security/security_auth_storage_rules.dart:1370:    'require_data_encryption',
```

**Emitter registration:** `lib/saropa_lints.dart:1386` (`RequireDataEncryptionRule.new`)
**Rule class:** `RequireDataEncryptionRule` (`security_auth_storage_rules.dart:1338`)
**Diagnostic `source` / `owner` as seen in Problems panel:** `source: saropa_lints`, `owner: saropaLintsLsp`

---

## Reproducer

Copied in shape from `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/system_data/provider_auth_drift_io_ops.dart:88-106` (`_dbClearLegacyCredentials`). Standalone plain Dart:

```dart
class Value<T> {
  const Value(this.value);
  final T value;
}

class AuthCompanion {
  const AuthCompanion({this.token, this.refreshToken});
  final Value<String?>? token;
  final Value<String?>? refreshToken;
}

class Updater {
  Future<int> write(AuthCompanion companion) async => 1;
}

Future<void> main() async {
  final Updater update = Updater();
  // LINT — but should NOT lint: every value is null, credentials are being cleared.
  await update.write(const AuthCompanion(token: Value<String?>(null)));
  await update.write(
    const AuthCompanion(refreshToken: Value<String?>(null)),
  );
}
```

**Frequency:** Always when a credential-named field is assigned `Value(null)` / `null` through `write`, `put`, `insert`, `setString`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the call stores no credential |
| **Actual** | `[require_data_encryption] Unencrypted sensitive data exposes credentials to attackers via device access or backup extraction. {v7}` at `provider_auth_drift_io_ops.dart` 90:15-94:78 and 97:15-106:14 |

---

## AST Context

```
FunctionDeclaration (_dbClearLegacyCredentials)
  └─ BlockFunctionBody
      └─ TryStatement
          └─ VariableDeclarationStatement (tokensCleared)
              └─ AwaitExpression
                  └─ MethodInvocation (.write)        <- node reported here
                      ├─ target: ParenthesizedExpression (db.update(...)..where(...))
                      └─ ArgumentList
                          └─ InstanceCreationExpression (const ProviderAuthsCompanion(token: Value<String?>(null)))
```

---

## Root Cause

`security_auth_storage_rules.dart`:

- Line 1528: method name `write` is in the watched set.
- Line 1545: `argsSource` is the lowercased argument text `(const providerauthscompanion(token: value<string?>(null)))`.
- Line 1579: `_tokenKeywordPattern.hasMatch(scannedArgsSource)` matches the column name `token` (and `refreshtoken`). The rule reports at once.
- Second call: argument text contains `refreshtoken` and `authorizationcode`; matched by the token pattern (line 1579) and the `auth` pattern (line 1583).

The rule scans argument text for keywords. It never checks whether the value written is a literal `null`. A write of `null` clears the field.

---

## Why the code is correct

`_dbClearLegacyCredentials` nulls every stored access token without the `v2:` encryption prefix and every refresh token and authorization code. The values written are `Value<String?>(null)`. Nothing sensitive is persisted.

---

## All affected project locations

- `lib/database/drift_middleware/system_data/provider_auth_drift_io_ops.dart:90-94` (`token`)
- `lib/database/drift_middleware/system_data/provider_auth_drift_io_ops.dart:97-106` (`refreshToken`, `authorizationCode`)

---

## Suggested Fix

Before the keyword scan (after line 1545), walk the argument list. If the only credential-named values are null (`NullLiteral`, or a `Value`/`Value.absent` wrapper whose single argument is a `NullLiteral`), return without reporting. A conservative form: when the argument text, with `value<string?>(null)` and `null` removed, no longer matches a keyword, skip.

---

## Fixture Gap

The fixture `example/lib/security/require_data_encryption_fixture.dart` should include:

1. `companion.write(const C(token: Value<String?>(null)))` — expect NO lint
2. `box.put('password', null)` — expect NO lint
3. `companion.write(C(token: Value(rawToken)))` — expect LINT
4. `companion.write(C(token: Value(null), refreshToken: Value(rawRefresh)))` — expect LINT

---

## Environment

- saropa_lints: 17.0.1-beta.2 (project pubspec.lock); rule source read at 17.0.1-beta.3
- Dart SDK: Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Project: contacts (Flutter), Drift 2.35.3

## Status 2026-10-29

Fixed in 17.0.1-beta.4 (see CHANGELOG).
