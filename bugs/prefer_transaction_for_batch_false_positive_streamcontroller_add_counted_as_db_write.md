# BUG: `prefer_transaction_for_batch` — counts `StreamController.add` as a database write (rule is not gated on any database package)

**Status: Open**

Created: 2026-10-29
Rule: `prefer_transaction_for_batch`
File: `lib/src/rules/packages/firebase_rules.dart` (line ~814; counter 839-915)
Severity: False positive
Rule version: v3 | Since: unknown | Updated: 17.0.1-beta.2

---

## Summary

The rule counts method calls named `add`, `delete`, `insert`, `put`, `set`, `update` and reports a method with 3 or more such calls and no transaction/batch call. The receiver is excluded only if its type is in a fixed list of in-memory collections (`List`, `Map`, `Set`, ...). `StreamController.add` (and `Sink.add`, `StringBuffer`-like sinks) is not in the list, so three `controller.add(event)` calls make a stream helper "multiple sequential database writes". The rule also does not check that the file uses a database package.

---

## Attribution Evidence

```bash
grep -rn "'prefer_transaction_for_batch'" lib/src/rules/
# lib/src/rules/packages/firebase_rules.dart:814:    'prefer_transaction_for_batch',
```

**Emitter registration:** `lib/src/rules/packages/firebase_rules.dart:814`
**Rule class:** `PreferTransactionForBatchRule` (firebase_rules.dart:795) — registered in `lib/saropa_lints.dart:1395`
**Diagnostic `source` / `owner`:** `saropa_lints` / `saropaLintsLsp`

---

## Reproducer

Copied from `lib/database/drift_middleware/user_data/user_preference_drift_stream_io.dart` lines 232-278 (`_watchAllRawValues`). Standalone:

```dart
import 'dart:async';

Stream<Map<String, String?>> watchAll(
  Stream<Map<String, String?>> shared,
  Future<Map<String, String?>> Function() baselineQuery,
) {                                                       // LINT at the method — should NOT lint
  late final StreamController<Map<String, String?>> perSubscriber;
  StreamSubscription<Map<String, String?>>? liveSub;

  perSubscriber = StreamController<Map<String, String?>>(
    onListen: () async {
      final List<Map<String, String?>> buffered = <Map<String, String?>>[];
      bool baselineSent = false;
      liveSub = shared.listen((Map<String, String?> event) {
        if (baselineSent) {
          perSubscriber.add(event);                       // counted (1)
        } else {
          buffered.add(event);                            // List: exempt
        }
      });
      final Map<String, String?> baseline = await baselineQuery();
      baselineSent = true;
      perSubscriber.add(baseline);                        // counted (2)
      for (final Map<String, String?> event in buffered) {
        perSubscriber.add(event);                         // counted (3)
      }
    },
    onCancel: () => liveSub?.cancel(),
  );
  return perSubscriber.stream;
}
```

(In the real project this is the static method `DatabaseUserPreferenceDriftStreamIO._watchAllRawValues()`, `user_preference_drift_stream_io.dart:232`.)

**Frequency:** Always for any method with 3+ `StreamController.add` / `EventSink.add` / `Sink.add` calls.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: no database write occurs in the method |
| **Actual** | `[prefer_transaction_for_batch] Multiple sequential database writes. Use transaction for atomicity. ...{v3}` at `user_preference_drift_stream_io.dart` 232:3 (line 221 col 3 before a later edit) |

---

## AST Context

```
ClassDeclaration (DatabaseUserPreferenceDriftStreamIO)
  └─ MethodDeclaration (_watchAllRawValues)       <- reported (atNode(node))
      └─ BlockFunctionBody
          └─ ... FunctionExpression (onListen) -> MethodInvocation (perSubscriber.add) x3
```

---

## Root Cause

`firebase_rules.dart:826-833`: the rule runs `_DatabaseWriteCounter` over every `MethodDeclaration` body and reports when `writeCount >= 3` and `!hasTransaction`. In `_DatabaseWriteCounter.visitMethodInvocation` (line 888) a name in `_writeMethodNames` goes to `_countIfDatabaseTarget` (line 902), which increments `writeCount` for every receiver whose type element name is not in `_safeCollectionTypes`. `StreamController` is not in that set, and no check ensures the receiver is a database/Firestore/Drift type. The three `perSubscriber.add(...)` calls (receiver type `StreamController`) reach `writeCount == 3`.

---

## Why the code is correct

`StreamController.add` pushes an event into an in-memory stream. There is no database, no transaction to open. The rule is registered under the Firebase package rules but is not gated on a Firebase/Drift/Isar import.

---

## Affected project locations

- `lib/database/drift_middleware/user_data/user_preference_drift_stream_io.dart:232` (`_watchAllRawValues`)

---

## Suggested Fix

Invert the test: count a call only when the receiver type is a known database type (or declared in a database package: `cloud_firestore`, `drift`, `isar`, `sqflite`, `hive`), and gate the rule on `fileImportsPackage`. At minimum add `StreamController`, `EventSink`, `Sink`, `StreamSink`, `StringBuffer`, `ValueNotifier`, `ChangeNotifier` to `_safeCollectionTypes`.

---

## Fixture Cases

```dart
// expect NO lint
void pump(StreamController<int> c) {
  c.add(1);
  c.add(2);
  c.add(3);
}

// expect LINT
Future<void> writes(DocumentReference a, DocumentReference b, DocumentReference c) async {
  await a.set({'x': 1});
  await b.set({'x': 2});
  await c.set({'x': 3});
}

// expect NO lint (transaction present)
Future<void> txn(FirebaseFirestore fs, DocumentReference a, DocumentReference b, DocumentReference c) async {
  await fs.runTransaction((t) async { t.set(a, {}); t.set(b, {}); t.set(c, {}); });
}
```

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Triggering project/file: `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/user_data/user_preference_drift_stream_io.dart`
