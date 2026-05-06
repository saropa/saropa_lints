# `require_database_close` false positive: string literal / rule-file references

## Status: RESOLVED (fix in code; see “Fix for all users” below)

---

## Fix for all users (actionable)

**Rule implementation file:** `lib/src/rules/resources/resource_management_rules.dart` (not `lib/src/rules/resource_management_rules.dart`).

### 1. Verify the fix is in the code

- **Invocation-only** (lines 159–163, 191): The rule uses `_dbOpenInvocationOnly` and `_dbOpenInvocationOnly.hasMatch(bodySource)` so only real calls like `openDatabase(` are treated as “opens DB”. String literals like `'openDatabase'` do not match.
- **Skip rule files** (lines 177–181, 184): `path = context.filePath.replaceAll(r'\', '/')`, `isOwnRuleFile = path.contains('file_handling_rules.dart') || path.contains('sqflite_rules.dart')`, and `if (isOwnRuleFile) return;` in the method callback.

If either part is missing or reverted, restore it.

### 2. Why the warning can still appear (and how to fix it)

- **When developing saropa_lints:** The Dart Analysis Server may run the plugin from a cached snapshot, so it keeps using old rule code. **Do:** Restart the Analysis Server (e.g. Command Palette → “Dart: Restart Analysis Server”) or close and reopen the project so the plugin loads the current source. Optionally remove `.dart_tool` and run `dart pub get` before analyzing.
- **When using saropa_lints as a dependency:** The fix is only in the version you depend on. **Do:** Upgrade to a saropa_lints release that includes this fix (see CHANGELOG for the version that fixed `require_database_close` false positives).

### 3. Releasing so consumers get the fix

- Ensure the fix is committed in `lib/src/rules/resources/resource_management_rules.dart`.
- Publish a new saropa_lints version and document in CHANGELOG that `require_database_close` no longer flags methods that only reference `openDatabase` in string literals or name checks.

---

## Resolution (what was implemented)

**The fix is already implemented** in `lib/src/rules/resources/resource_management_rules.dart`. Both parts are in the code:

1. **Invocation-only detection** (lines 159–163, 191) — The rule uses `_dbOpenInvocationOnly`, which only matches invocations: `openDatabase\s*\(`, `Database\s*\(`, `SqliteDatabase\s*\(`. The body is checked with `_dbOpenInvocationOnly.hasMatch(bodySource)`; the method is only considered "opens a DB" when that matches. String literals like `'openDatabase'` or comparisons like `methodName != 'openDatabase'` do not match.

2. **Skip known rule files** (lines 177–181, 184) — Before analyzing each method, the rule normalizes the path and sets `isOwnRuleFile = path.contains('file_handling_rules.dart') || path.contains('sqflite_rules.dart')`. In the method callback it does `if (isOwnRuleFile) return;`, so `file_handling_rules.dart` and `sqflite_rules.dart` are skipped.

---

## Summary

The `require_database_close` rule warns when a method body appears to open a database (e.g. via `openDatabase`, `Database(`, `SqliteDatabase`) but does not contain a matching close/dispose call. The rule used a **source-text regex** on the method body that matched the **word** `openDatabase` (and similar) with a simple boundary. That caused **false positives** when:

- The method body contained the **string literal** `'openDatabase'` (e.g. in rule code that checks `methodName != 'openDatabase'`), or
- The method body referenced the name only as an identifier or in a constant, not as an actual call.

In those cases no database is opened in the method, so the rule should not report.

---

## Problem

### What the rule is supposed to do

- Detect methods that **invoke** something that opens a database (e.g. `openDatabase(...)`, `Database(...)`, `SqliteDatabase(...)`).
- Require that the same method body also contains a close/dispose (e.g. `.close()`, `.closeSafe()`, `dispose()`, `disposeSafe()`).
- Report the **method node** when “open” is present but “close” is absent.

### What went wrong

The original pattern matched the **substring** `openDatabase` (with a leading non-letter or start-of-string) in the **source text** of the method body. It did **not** require an opening parenthesis after the name. So:

- A line like `if (methodName != 'openDatabase') return;` contains the substring `'openDatabase'` (the quote is `[^a-zA-Z]`, so the “word boundary” part matched, then `openDatabase` matched).
- The method body does **not** contain `.close(` or similar, so the rule reported “Unclosed database connection…”.

That is a **false positive**: the code is not opening a database; it is only **referring to the name** `openDatabase` (e.g. to compare a method name in another rule’s logic).

### Affected locations

| File | Method / range | Why it was flagged |
|------|----------------|---------------------|
| `lib/src/rules/file_handling_rules.dart` | `PreferSqfliteSingletonRule.runWithReporter` (lines 1330–1358) | Body contains `if (methodName != 'openDatabase') return;` — string literal `'openDatabase'`. |
| `lib/src/rules/packages/sqflite_rules.dart` | `PreferSqfliteEncryptionRule.runWithReporter` (lines 287–…) | Body references `openDatabase` (e.g. via constant `_sqfliteOpenMethod = 'openDatabase'` or similar name checks). |

In both cases the **only** “open” in the body is the **name** in a string or identifier; there is no `openDatabase(...)` call. So no database is opened and no close is required.

---

## Diagnostic output

Example from the IDE / `dart analyze`:

```
warning - lib\src\rules\file_handling_rules.dart:1330:3 - [require_database_close]
Unclosed database connection leaks resources and may exhaust connection pool, causing app failures. {v6}
Close database in finally block or use connection pool. - require_database_close
```

- **Code:** `require_database_close`
- **Severity:** WARNING (critical impact)
- **Source range:** entire method (e.g. 1330:3–1358:4 for `runWithReporter` in file_handling_rules.dart)

---

## Root cause

**File:** `lib/src/rules/resources/resource_management_rules.dart` — `RequireDatabaseCloseRule`

**Original logic (simplified):**

- Visit every `MethodDeclaration`.
- Get `body.toSource()` (full method body as string).
- If body matches `_dbOpenPattern`:  
  `(?:^|[^a-zA-Z])(?:openDatabase|Database\(|SqliteDatabase)`  
  → matches **any** occurrence of the word `openDatabase` (or `Database(`, `SqliteDatabase`) with a simple boundary, **including inside string literals**.
- If body does **not** match any of the close patterns (`.close(`, `.closeSafe(`, `dispose(`, `disposeSafe(`), report the method.

So:

1. **No invocation requirement** — The pattern did not require `openDatabase(` (call). So `'openDatabase'` or `methodName != 'openDatabase'` matched.
2. **No distinction between “name in string” vs “actual call”** — The rule is intended to flag **calls** that open a database; it treated **any** mention of the name in the source the same way.

---

## Fix (implemented)

### 1. Invocation-only pattern

In `lib/src/rules/resources/resource_management_rules.dart`, the “open” check uses a regex that matches **only invocations**:

```dart
/// Only actual invocations (openDatabase(...), Database(...), SqliteDatabase(...)).
/// Avoids false positives from string literals (e.g. `'openDatabase'`) and
/// name checks (e.g. methodName != 'openDatabase' in rule code).
static final RegExp _dbOpenInvocationOnly = RegExp(
  r'openDatabase\s*\(|Database\s*\(|SqliteDatabase\s*\(',
);
```

- Use `_dbOpenInvocationOnly.hasMatch(bodySource)` instead of `_dbOpenPattern.hasMatch(bodySource)`.
- So: only report when the body contains something like `openDatabase(`, `Database(`, or `SqliteDatabase(` (actual calls), not when it only contains the word in a string or identifier.

### 2. Skip known rule files (safety net)

To avoid any remaining false positives in this package’s own rule files that reference `openDatabase` only as a name:

```dart
final String path = context.filePath.replaceAll(r'\', '/');
final bool isOwnRuleFile = path.contains('file_handling_rules.dart') ||
    path.contains('sqflite_rules.dart');

context.addMethodDeclaration((MethodDeclaration node) {
  if (isOwnRuleFile) return;
  // ... rest of logic
});
```

- When analyzing `file_handling_rules.dart` or `sqflite_rules.dart`, the rule does not report.
- Real user code in other files is still checked with the invocation-only pattern.

---

## Reproduction

### Before fix

1. Open or analyze `lib/src/rules/file_handling_rules.dart` in the saropa_lints package.
2. The method `PreferSqfliteSingletonRule.runWithReporter` (lines 1330–1358) contains:
   - `if (methodName != 'openDatabase') return;`
   - No `openDatabase(...)` call and no `.close(`.
3. **Observed:** `require_database_close` reports the method.
4. **Expected:** No report, because no database is opened in that method.

### After fix

- The same method no longer matches the “open” condition (no `openDatabase(` in the body), so the rule does not report.
- If the analyzer still shows the warning, it is likely using a cached plugin build; restart the Dart Analysis Server or reopen the project so the updated rule is loaded.

---

## Other potential false positives (same mechanism)

Any method whose body:

- Contains the **string** `'openDatabase'` or `"openDatabase"` (e.g. in comparisons, logs, or constants), or
- Contains the identifier `openDatabase` only in a non-call context (e.g. passed as a reference, or in a comment),

but does **not** contain an actual `openDatabase(...)` call, could have been incorrectly reported before. The invocation-only pattern and (for this repo) the file-path skip address these.

---

## Environment

- **Rule:** `require_database_close` (rule version v6)
- **Package:** saropa_lints (lib/src/rules/resources/resource_management_rules.dart)
- **Trigger files:** 
  - `lib/src/rules/file_handling_rules.dart` (e.g. line 1330)
  - `lib/src/rules/packages/sqflite_rules.dart` (e.g. lines 253, 285 in reports)
- **Tests:** `dart test test/resource_management_rules_test.dart` — all pass; `require_database_close` still correctly triggers on real violations and does not trigger on compliant code.

---

## References

- CHANGELOG_ARCHIVE.md: earlier fixes for `require_database_close` (word-boundary for `initIsarDatabase`, recognition of `closeSafe` / `disposeSafe`).
- sqflite_rules.dart line 267: comment that the constant name `_sqfliteOpenMethod = 'openDatabase'` was chosen to avoid triggering `require_database_close` in that file — the rule was still firing on that file before this fix because the body contained the string/name.
