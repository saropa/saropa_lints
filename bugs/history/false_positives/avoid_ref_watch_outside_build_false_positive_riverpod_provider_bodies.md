# Bug Report: `avoid_ref_watch_outside_build` — False Positive in Riverpod Provider Bodies

## Resolution

**Fixed in v4 of the rule.** Added `_isInReactiveContext()` that recognizes Riverpod provider body callbacks (`Provider`, `StreamProvider`, `FutureProvider`, `StateProvider`, etc.) as valid reactive contexts alongside `build()` methods. Also handles `.family` and `.autoDispose` modifier patterns via target name checking.

---

## Diagnostic Reference

```json
[{
  "resource": "/D:/src/saropa_kykto/lib/providers/thought_providers.dart",
  "owner": "_generated_diagnostic_collection_name_#0",
  "code": "avoid_ref_watch_outside_build",
  "severity": 8,
  "message": "[avoid_ref_watch_outside_build] ref.watch() detected outside build() method, breaking the Riverpod widget lifecycle. Subscriptions created outside build() leak memory, produce stale data, and cause missed UI updates that lead to inconsistent state and hard-to-debug rendering errors across dependent widgets. {v3}\nMove ref.watch() calls into the build() method where Riverpod manages subscription lifecycle and automatic widget rebuilds on provider state changes.",
  "source": "dart",
  "startLineNumber": 7,
  "startColumn": 14,
  "endLineNumber": 7,
  "endColumn": 41,
  "origin": "extHost1"
}]
```

---

## Summary

The `avoid_ref_watch_outside_build` rule (v3) flags `ref.watch()` calls inside Riverpod **provider body callbacks** (`Provider`, `StreamProvider`, `FutureProvider`). These are false positives — `ref.watch()` in provider bodies is the correct and recommended Riverpod pattern for creating reactive dependency chains between providers. The rule only makes sense for widget `build()` methods, but the AST visitor does not distinguish between the two contexts.

---

## Severity

**False positive (ERROR severity)** — The flagged code follows the exact pattern from Riverpod's official documentation. Changing `ref.watch()` to `ref.read()` in provider bodies would **break** reactivity, causing providers to return stale data when their dependencies change.

---

## Reproduction

### Example 1: Provider depending on another Provider

**File:** `lib/providers/thought_providers.dart`, line 7

```dart
final thoughtRepositoryProvider = Provider<ThoughtRepository>((ref) {
  final db = ref.watch(databaseProvider);  // <-- FLAGGED
  return ThoughtRepository(
    thoughtDao: db.thoughtDao,
    archiveDao: db.archiveDao,
  );
});
```

FLAGGED on line 7. But `ref.watch()` here creates a reactive dependency — when `databaseProvider` changes, `thoughtRepositoryProvider` automatically rebuilds. This is the standard Riverpod provider composition pattern.

### Example 2: StreamProvider depending on multiple providers

**File:** `lib/providers/archive_providers.dart`, lines 27-28

```dart
final archiveItemsProvider = StreamProvider<List<ArchiveItem>>((ref) {
  final query = ref.watch(archiveSearchQueryProvider);  // <-- FLAGGED
  final repo = ref.watch(archiveRepositoryProvider);    // <-- FLAGGED
  return repo.searchArchive(query);
});
```

FLAGGED on lines 27 and 28. Both `ref.watch()` calls are essential — when the search query changes OR the repository changes, the stream provider re-evaluates and returns a new stream. Replacing with `ref.read()` would make the stream stale forever after first evaluation.

### Example 3: Provider with ref.watch chained through dependency

**File:** `lib/providers/database_provider.dart`, line 13

```dart
final databaseProvider = Provider<AppDatabase>((ref) {
  final key = ref.watch(encryptionKeyProvider);  // <-- FLAGGED
  final db = AppDatabase(key);
  ref.onDispose(db.close);
  return db;
});
```

FLAGGED on line 13. The `ref.watch()` ensures that if the encryption key ever changes, the database is recreated. The `ref.onDispose()` on the next line properly cleans up the old database — this is the canonical Riverpod lifecycle pattern.

### Example 4: FutureProvider depending on a Provider

**File:** `lib/providers/archive_providers.dart`, line 33

```dart
final archiveStatsProvider = FutureProvider<Map<ArchiveReason, int>>((ref) {
  return ref.watch(archiveRepositoryProvider).getStats();  // <-- FLAGGED
});
```

FLAGGED on line 33. The `ref.watch()` ensures stats are re-fetched when the repository changes.

---

## Full Count

| File | Flags | Context |
|------|------:|---------|
| `lib/providers/archive_providers.dart` | 4 | Provider, StreamProvider, FutureProvider bodies |
| `lib/providers/thought_providers.dart` | 2 | Provider, StreamProvider bodies |
| `lib/providers/database_provider.dart` | 1 | Provider body |

**Total: 7 false positives across 3 files**, all following identical pattern.

---

## Root Cause Analysis

The rule detects `ref.watch()` calls and checks whether they occur inside a `build()` method. If not, it flags them. However, it fails to recognize that Riverpod provider body callbacks are **semantically equivalent** to `build()` — they are reactive builders that Riverpod re-invokes when watched dependencies change.

### Riverpod's Two Reactive Contexts

| Context | `ref.watch()` Correct? | Rule's Behavior |
|---------|:----------------------:|:---------------:|
| Widget `build(BuildContext, WidgetRef)` | Yes | Allows (correct) |
| Provider body callback `(Ref ref) { ... }` | **Yes** | **Flags (incorrect)** |
| Event handler / `onPressed` / `initState` | No | Flags (correct) |

The rule treats all non-`build()` contexts identically, which is wrong for provider bodies.

### AST Structure

For a `Provider` definition:

```
TopLevelVariableDeclaration
  └─ VariableDeclaration (thoughtRepositoryProvider)
      └─ MethodInvocation (Provider<T>())
          └─ ArgumentList
              └─ FunctionExpression ((ref) { ... })  ← provider body
                  └─ Block
                      └─ MethodInvocation (ref.watch(...))  ← flagged
```

The `FunctionExpression` is the provider's reactive builder callback. The rule needs to check whether the `ref.watch()` call's enclosing `FunctionExpression` is an argument to a Riverpod provider constructor.

---

## Correct vs Incorrect Flagging

| Code Pattern | Currently Flagged | Should Be Flagged |
|---|---|---|
| `ref.watch()` in widget `build()` | No | **No** — correct reactive usage |
| `ref.watch()` in `Provider((ref) { ... })` | **Yes** | **No** — correct provider composition |
| `ref.watch()` in `StreamProvider((ref) { ... })` | **Yes** | **No** — correct provider composition |
| `ref.watch()` in `FutureProvider((ref) { ... })` | **Yes** | **No** — correct provider composition |
| `ref.watch()` in `NotifierProvider` `build()` | Unknown | **No** — correct notifier build |
| `ref.watch()` in `onPressed` callback | Yes | **Yes** — should use `ref.read()` |
| `ref.watch()` in `initState` | Yes | **Yes** — wrong lifecycle |

---

## Suggested Fix

**Option A (recommended): Recognize Riverpod provider constructors as reactive contexts**

Before flagging `ref.watch()`, check whether the enclosing `FunctionExpression` is an argument to a known Riverpod provider constructor:

```dart
const _riverpodProviderConstructors = {
  'Provider',
  'StreamProvider',
  'FutureProvider',
  'StateProvider',
  'StateNotifierProvider',
  'ChangeNotifierProvider',
  'NotifierProvider',
  'AsyncNotifierProvider',
};

bool _isInsideProviderBody(AstNode node) {
  AstNode? current = node;
  while (current != null) {
    if (current is FunctionExpression) {
      final parent = current.parent;
      if (parent is ArgumentList) {
        final grandparent = parent.parent;
        if (grandparent is InstanceCreationExpression ||
            grandparent is MethodInvocation) {
          final name = grandparent is InstanceCreationExpression
              ? grandparent.constructorName.type.name2.lexeme
              : (grandparent as MethodInvocation).methodName.name;
          if (_riverpodProviderConstructors.contains(name)) {
            return true;
          }
        }
      }
      // Stop at the first enclosing FunctionExpression
      return false;
    }
    current = current.parent;
  }
  return false;
}
```

**Option B: Check parameter type**

If the `ref` identifier's static type is `Ref` (from `package:riverpod`) rather than `WidgetRef`, the call is in a provider body and should be allowed.

**Option C: Exempt top-level variable declarations**

Provider definitions are typically top-level `final` variables. If `ref.watch()` appears inside a `FunctionExpression` that is an argument in a `TopLevelVariableDeclaration`, it's almost certainly a provider body.

---

## Priority

**Critical** — Severity 8 (ERROR) on correct, idiomatic Riverpod code. Every Riverpod app that composes providers (which is nearly all of them) will trigger this false positive. The `ref.watch()` pattern in provider bodies is on the first page of Riverpod's official documentation and is the foundation of provider-to-provider reactivity.

---

## Environment

- saropa_lints version: latest (v3 of this rule)
- Dart SDK: 3.11+
- Framework: Flutter with Riverpod
- Project: saropa_kykto
