# Bug Report: `avoid_dynamic_sql` — False Positive on SQLite PRAGMA Statements

## Resolution

**Fixed in v4 of the rule.** Added `_isPragmaStatement()` check that exempts SQL strings starting with `PRAGMA` (case-insensitive). Also improved SQL keyword matching in concatenation detection to use word-boundary regex, preventing false positives from identifiers like `selection` or `updateTime`.

---

## Diagnostic Reference

```json
[{
  "resource": "/D:/src/saropa_kykto/lib/data/database/app_database.dart",
  "owner": "_generated_diagnostic_collection_name_#0",
  "code": "avoid_dynamic_sql",
  "severity": 8,
  "message": "[avoid_dynamic_sql] Constructing SQL queries by concatenating or interpolating user input directly into the query string exposes your application to SQL injection attacks. Attackers can craft input that alters the structure of your query, allowing them to read, modify, or delete arbitrary data, escalate privileges, or compromise the entire database. SQL injection is one of the most critical and well-documented security vulnerabilities in software development, and has led to major data breaches across industries. {v3}\nAlways use parameterized queries, prepared statements, or trusted query builders to safely insert user input into SQL queries. Never concatenate or interpolate user data directly into SQL strings. Audit your codebase for dynamic SQL construction and refactor to use safe patterns. Test your application for SQL injection vulnerabilities using automated tools or manual review. Document secure query practices in your team guidelines.",
  "source": "dart",
  "startLineNumber": 55,
  "startColumn": 22,
  "endLineNumber": 55,
  "endColumn": 54,
  "origin": "extHost1"
}]
```

---

## Summary

The `avoid_dynamic_sql` rule (v3) flags string interpolation in the SQLCipher `PRAGMA key` statement. This is a false positive because:

1. **PRAGMA statements do not support parameter binding** — SQLite's PRAGMA syntax requires literal values; prepared statement placeholders (`?`) cannot be used
2. **The interpolated value is not user input** — the encryption key comes from platform secure storage (`flutter_secure_storage`), not from any user-facing input
3. **There is no alternative implementation** — the rule's suggestion to "use parameterized queries" is impossible for PRAGMA statements

---

## Severity

**False positive (ERROR severity)** — The rule flags the only correct way to set a SQLCipher encryption key. There is no parameterized alternative for PRAGMA statements in SQLite.

---

## Reproduction

**File:** `lib/data/database/app_database.dart`, line 55

```dart
return NativeDatabase.createInBackground(
  file,
  setup: (db) {
    // Set the encryption key before any other operations.
    db.execute("PRAGMA key = '$encryptionKey';");  // <-- FLAGGED
  },
);
```

The `encryptionKey` is sourced from `encryptionKeyProvider`, which reads from `flutter_secure_storage` at app startup. It is never derived from user input, text fields, URLs, or any external source.

### Why parameter binding is impossible

SQLite PRAGMA statements are **meta-commands**, not standard SQL queries. They do not go through the prepared statement path:

```dart
// This does NOT work — SQLite rejects ? in PRAGMA:
db.execute("PRAGMA key = ?;", [encryptionKey]);  // ERROR: near "?": syntax error

// This is the ONLY way to set SQLCipher key:
db.execute("PRAGMA key = '$encryptionKey';");
```

This is documented in SQLCipher's official API:
- https://www.zetetic.net/sqlcipher/sqlcipher-api/#PRAGMA_key

Every SQLCipher integration in every language (Python, Java, Swift, Dart) uses string interpolation for `PRAGMA key` because there is no alternative.

---

## Root Cause Analysis

The rule uses a broad pattern: any string interpolation (`$variable` or `${expression}`) inside a string passed to a method that executes SQL (`db.execute`, `db.rawQuery`, `db.rawInsert`, etc.) is flagged. The rule does not distinguish between:

| SQL Type | Parameter Binding Supported? | Should Flag Interpolation? |
|----------|:----------------------------:|:--------------------------:|
| `SELECT`, `INSERT`, `UPDATE`, `DELETE` | Yes | **Yes** |
| `PRAGMA key = '...'` | **No** | **No** |
| `PRAGMA cipher_version` | N/A (no values) | N/A |
| `CREATE TABLE` (DDL) | **No** | Depends on context |

---

## Additional Context

### PRAGMA statements commonly used with interpolation

These are all legitimate and cannot use parameter binding:

```dart
// SQLCipher encryption key (the flagged case)
db.execute("PRAGMA key = '$key';");

// SQLCipher key migration
db.execute("PRAGMA rekey = '$newKey';");

// Setting journal mode (sometimes dynamic)
db.execute("PRAGMA journal_mode = $mode;");

// Setting page size
db.execute("PRAGMA cipher_page_size = $size;");
```

### The value is NOT user input

The data flow for the encryption key:

```
flutter_secure_storage (hardware-backed keychain)
  → encryptionKeyProvider (Riverpod Provider, override at startup)
    → AppDatabase constructor
      → _openConnection(encryptionKey)
        → PRAGMA key = '$encryptionKey'
```

At no point does user input, a text field, a URL parameter, or any external source touch this value. It is a machine-generated cryptographic key stored in the platform's secure enclave.

---

## Suggested Fix

**Option A (recommended): Exempt PRAGMA statements**

If the SQL string starts with `PRAGMA` (case-insensitive), skip the dynamic SQL check. PRAGMA statements never support parameter binding, so flagging interpolation in them always produces a false positive:

```dart
bool _isPragmaStatement(String sql) {
  return sql.trimLeft().toUpperCase().startsWith('PRAGMA');
}
```

**Option B: Exempt specific PRAGMA commands**

More conservative — only exempt known PRAGMA commands that require interpolated values:

```dart
const _exemptPragmas = {
  'PRAGMA key',
  'PRAGMA rekey',
  'PRAGMA cipher_page_size',
  'PRAGMA journal_mode',
};
```

**Option C: Exempt when the interpolated variable is not from a user-input source**

Check whether the interpolated variable traces back to a user-input source (TextEditingController, Uri, request parameter). If it comes from a provider, constant, or secure storage, it is not an injection risk. This is more complex but would reduce false positives across all SQL types.

---

## Workaround

Until fixed, the only workaround is an `// ignore:` comment:

```dart
// PRAGMA statements do not support parameter binding.
// Key sourced from secure storage, not user input.
// ignore: avoid_dynamic_sql
db.execute("PRAGMA key = '$encryptionKey';");
```

An additional defensive measure is to escape single quotes in the key:

```dart
final safeKey = encryptionKey.replaceAll("'", "''");
// ignore: avoid_dynamic_sql
db.execute("PRAGMA key = '$safeKey';");
```

However, the linter will still flag the interpolation even with escaping, since it performs static analysis on the string template, not runtime values.

---

## Priority

**Medium** — This only affects apps using SQLCipher encryption, but for those apps, the PRAGMA key statement is mandatory and unfixable. The ERROR severity (8) forces developers to add ignore comments for correct, security-critical code.

---

## Environment

- saropa_lints version: latest (v3 of this rule)
- Dart SDK: 3.11+
- Framework: Flutter with Drift + SQLCipher
- Project: saropa_kykto
