# BUG: `avoid_return_await_db` — read method `dbContactLoadDBListByStatus` classified as a write because "load" contains "add"

**Status: Fixed**

Created: 2026-10-29
Rule: `avoid_return_await_db`
File: `lib/src/rules/resources/db_yield_rules.dart` (`_classifyByHeuristic` line 112, `_writeKeywords` line 123, rule class line 516)
Severity: False positive
Rule version: v3 | Since: v4.9.16 | Updated: v4.13.0

---

## Summary

The rule is documented as "writes only". `_classifyByHeuristic` lowercases the method name and tests the write keywords as plain substrings before the read keywords. The write keyword `add` matches inside `load` when `load` is followed by `db` (`loaddb` contains `add`). A read named `dbContactLoadDBListByStatus` is therefore reported as a write.

---

## Attribution Evidence

```bash
grep -rn "'avoid_return_await_db'" lib/src/rules/
# lib/src/rules/resources/db_yield_rules.dart:532:    'avoid_return_await_db',
```

Diagnostic `source` / `owner` in the Problems panel: `saropa_lints` / `saropaLintsLsp`. Observed on `saropa_lints` 17.0.1-beta.4 (analysis server restarted after the install; the list had dropped from 701 to 17 findings).

---

## Diagnostic

```
lib/database/drift_middleware/user_data/contact_load_list_io.dart 336
[avoid_return_await_db] Returning directly from a database/IO write skips yieldToUI(). {v3}
```

Flagged code (line 336 is the `return await` statement):

```dart
static Future<List<ContactDBModel>?> dbContactLoadDBListByStatus(
  ContactStatus contactStatus, {
  int limit = 0,
}) async {
  try {
    return await DatabaseContactDriftQueryIO.dbContactLoadDBListByStatus(
      contactStatus,
      limit: limit,
    );
  } on Object catch (error, stack) {
    debugException(error, stack);
    return null;
  }
}
```

---

## Reproducer

```dart
class Io {
  static Future<List<int>?> dbContactLoadDBListByStatus(int status) async => <int>[];
}

Future<List<int>?> wrapper(int status) async {
  try {
    return await Io.dbContactLoadDBListByStatus(status); // LINT — but should NOT lint (read)
  } on Object {
    return null;
  }
}
```

Names that trip it, from the substring test on the lowercased name:

| Method | Lowercased contains | Result |
|---|---|---|
| `dbContactLoadDBListByStatus` | `loaddb` -> `add` | write (wrong) |
| `dbContactLoadDBCount` | `loaddb` -> `add` | write (wrong) |
| `dbContactFetchList` | no write keyword; `fetch` | read (correct) |

**Frequency:** Always, for any `db*` method whose name has `Load` directly followed by `DB`. Also for any read whose name contains `put`, `add`, `save`, `remove`, `update`, `write`, `insert` or `delete` as a substring, for example `compute`, `upDATE`, `address`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the method name starts with `Load`, a read |
| **Actual** | `[avoid_return_await_db]` at the `return await` statement |

---

## AST Context

```
ClassDeclaration
  └─ MethodDeclaration (dbContactLoadDBListByStatus)
      └─ BlockFunctionBody
          └─ TryStatement
              └─ Block
                  └─ ReturnStatement            ← reported (reporter.atNode(s))
                      └─ AwaitExpression
                          └─ MethodInvocation (.dbContactLoadDBListByStatus)
```

---

## Root Cause

`db_yield_rules.dart`:

```dart
50  _DbOperationType? _classifyDbAwait(AwaitExpression awaitExpr) {
...
59    // 2. Check db* prefix pattern (e.g. dbContactSave, dbFetchAll).
60    if (_isDbPrefix(name)) return _classifyByHeuristic(name);

112 _DbOperationType _classifyByHeuristic(String name) {
113   final lower = name.toLowerCase();
114   for (final kw in _writeKeywords) {
115     if (lower.contains(kw)) return _DbOperationType.write;   // 'add' matches "loaDDb"
116   }
```

1. The name starts with `db` followed by an uppercase letter, so `_isDbPrefix` is true.
2. `_classifyByHeuristic('dbContactLoadDBListByStatus')` lowercases to `dbcontactloaddblistbystatus`.
3. `'add'` is in `_writeKeywords` and `loaddb` contains `add` (`lo`**`add`**`b`). The loop returns `write` before the read keywords (`load`) are tested.
4. `AvoidReturnAwaitDbRule.runWithReporter` reports every `return await` whose type is `write`.

The same defect is already worked around once in this project's suppression baseline (`lint_baseline.yaml`, `avoid_return_await_db`, rationale "read-only aggregate; the rule's name match misreads it as a write").

---

## Suggested Fix

Split the name into camel-case words and test whole words, not substrings. Test the leading verb first:

```dart
final words = RegExp(r'[A-Z]?[a-z]+|[A-Z]+(?![a-z])').allMatches(name.replaceFirst(RegExp(r'^db'), ''))
    .map((m) => m.group(0)!.toLowerCase()).toList();
// the first word decides: load/get/find/read/fetch/query/count/list/stream -> read; save/add/put/... -> write
```

If whole-word matching is too large a change, test `_readKeywords` against the first word after `db` before the write substring loop.

---

## Fixture Gap

`example/lib/resources/avoid_return_await_db_fixture.dart` should include:

1. `return await Io.dbContactLoadDBListByStatus(s);` — expect NO lint
2. `return await Io.dbContactLoadDBCount();` — expect NO lint
3. `return await Io.dbContactComputeTotals();` (contains `put`) — expect NO lint
4. `return await Io.dbContactSave(c);` — expect LINT
5. `return await Io.dbContactAddToGroup(c);` — expect LINT

---

## Environment

- saropa_lints version: `17.0.1-beta.4` (`pubspec.lock`)
- analyzer: `14.7.0`
- Dart SDK: 3.13.7
- Triggering project/file: `lib/database/drift_middleware/user_data/contact_load_list_io.dart:336`

---

## Resolution 2026-10-29

`_classifyByHeuristic` now splits the name into camel-case words; the first word starting with a write or read keyword decides. Fixture and resolved scan confirm: LoadDB reads do not lint, Save/AddToGroup/UpdateRow still lint. `compute`, `calculate` and `check` were added as read verbs, so `dbContactComputeTotals` no longer lints either. Unknown names still default to write.
