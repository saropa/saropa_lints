# Task: `prefer_sqflite_encryption`

## Summary
- **Rule Name**: `prefer_sqflite_encryption`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.9 sqflite Database Rules

## Problem Statement

sqflite stores data in an **unencrypted SQLite file** on the device. On Android, this is in the app's private data directory (protected by OS sandboxing from other apps), but on rooted devices or when backups are enabled, the database file can be read directly by anyone.

For apps storing:
- User credentials or tokens
- Medical/health data
- Financial data
- Personally Identifiable Information (PII)
- Private messages

...the database should use encryption. The standard solution is `sqlcipher_flutter_libs` + `sqflite_sqlcipher` which provides transparent AES-256 encryption.

This is also an OWASP Mobile Top 10 concern:
- **M9: Insecure Data Storage** — storing sensitive data in unencrypted local databases

## Description (from ROADMAP)

> Sensitive databases need encryption. Use sqlcipher_flutter_libs.

## Trigger Conditions

1. `sqflite` is used (`openDatabase(...)` or `databaseFactory.openDatabase(...)` calls)
2. No `sqlcipher_flutter_libs` or `sqflite_sqlcipher` package detected in project
3. The database path contains words like `user`, `auth`, `account`, `payment`, `health`, `medical`, or `private` (heuristic for sensitive data)

**Phase 1 (Conservative)**: Only fire when database path name suggests sensitive data.
**Phase 2 (Stricter)**: Fire for ALL sqflite databases that don't use encryption.

## Implementation Approach

```dart
context.registry.addMethodInvocation((node) {
  if (!_isSqfliteOpenDatabase(node)) return;
  if (_projectUsesSqlcipher(context)) return; // suppress if encrypted db used

  // Phase 1: check if path argument suggests sensitive data
  final pathArg = _getDatabasePathArg(node);
  if (pathArg != null && _isSensitiveDbName(pathArg)) {
    reporter.atNode(node, code);
  }
});
```

`_isSqfliteOpenDatabase`: check if method name is `openDatabase` and receiver is from `sqflite`.
`_projectUsesSqlcipher`: check `ProjectContext.usesPackage('sqflite_sqlcipher')` or `ProjectContext.usesPackage('sqlcipher_flutter_libs')`.
`_isSensitiveDbName`: check if path string contains `user`, `auth`, `payment`, `health`, `medical`, `account`, `credential`, `private`, `secret`.

## Code Examples

### Bad (Should trigger)
```dart
// Opening unencrypted database with sensitive name
final db = await openDatabase(
  join(await getDatabasesPath(), 'user_accounts.db'),  // ← trigger: sensitive name + no encryption
  version: 1,
  onCreate: (db, version) => db.execute(createTable),
);

final db = await openDatabase('medical_records.db');  // ← trigger
```

### Good (Should NOT trigger)
```dart
// Using sqflite_sqlcipher for encryption
import 'package:sqflite_sqlcipher/sqflite.dart';

final db = await openDatabase(
  join(await getDatabasesPath(), 'user_accounts.db'),
  password: await _getDbPassword(),  // ← encrypted
  version: 1,
);

// Non-sensitive database name (no trigger in Phase 1)
final db = await openDatabase('app_settings.db');
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| Test files | **Suppress** | Test DBs don't need encryption |
| In-memory database `openDatabase(':memory:')` | **Suppress** — no persistence | |
| `sqflite_sqlcipher` already in pubspec | **Suppress** — project has the package | |
| Encrypted DB class wrapping sqflite | **Suppress** — may be custom encryption | HIGH false positive risk |
| Non-sensitive database name | **Suppress** in Phase 1 | |
| `flutter_secure_storage` for the key only | **Suppress** — key management is present | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `openDatabase('user_data.db')` without sqlcipher package → 1 lint
2. `openDatabase('medical_history.db')` without encryption → 1 lint

### Non-Violations
1. Project with `sqflite_sqlcipher` → no lint
2. `openDatabase(':memory:')` → no lint
3. `openDatabase('settings.db')` (non-sensitive name in Phase 1) → no lint

## Quick Fix

No automated fix — switching to encrypted SQLite requires:
1. Adding `sqflite_sqlcipher` dependency
2. Changing import from `sqflite` to `sqflite_sqlcipher`
3. Providing a password argument to `openDatabase`
4. Managing the encryption key securely (via `flutter_secure_storage`)

Suggest as a manual step with documentation link.

## Notes & Issues

1. **Package detection priority**: If `ProjectContext.usesPackage('sqflite_sqlcipher')` returns true, suppress entirely — the project has already opted into encryption.
2. **sqflite-only**: Only fire if `ProjectContext.usesPackage('sqflite')`.
3. **OWASP**: Map to **M9: Insecure Data Storage**.
4. **Phase 1 sensitivity**: The word-list approach will miss cases like `openDatabase('app.db')` used to store health data. Phase 2 would fire on all sqflite opens, which has very high false positive rate for legitimate non-sensitive data. Document this clearly.
5. **Alternative**: `drift` (formerly Moor) also supports encryption via `drift_sqflite` — consider detecting this as well.
6. **Key management**: The encryption is only as secure as key management. A companion rule `require_sqflite_key_secure_storage` would check that the password comes from `FlutterSecureStorage` not from a hardcoded string.
