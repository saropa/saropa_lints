# BUG: `require_dispose_pattern` — flags an `abstract final class` whose StreamController fields are static and closed by the controller's own `onCancel`

**Status: Open**

Created: 2026-10-29
Rule: `require_dispose_pattern`
File: `lib/src/rules/core/performance_rules.dart` (line ~3280; class 3274; visitor ~3300-3352)
Severity: False positive
Rule version: v4 | Since: v1.7.0 | Updated: 17.0.1-beta.2

---

## Summary

The rule reports any class with a field whose type text mentions `StreamController` (and similar) but no method named `dispose` or `close`. It does not consider `static` fields or an `abstract final class` (cannot be instantiated, so there is no instance to dispose). The static controller here is a ref-counted broadcast stream: `onCancel` stops the source and releases state.

---

## Attribution Evidence

```bash
grep -rn "'require_dispose_pattern'" lib/src/rules/
# lib/src/rules/core/performance_rules.dart:3280:    'require_dispose_pattern',
```

**Emitter registration:** `lib/src/rules/core/performance_rules.dart:3280`
**Rule class:** `RequireDisposePatternRule` (performance_rules.dart:3274) — registered in `lib/saropa_lints.dart:1292`
**Diagnostic `source` / `owner`:** `saropa_lints` / `saropaLintsLsp`

---

## Reproducer

Copied from `lib/database/drift_middleware/user_data/user_preference_drift_stream_io.dart` lines 15, 66-67, 78-89, 108-117. Standalone:

```dart
import 'dart:async';

abstract final class SharedSource {              // LINT at 'abstract' (class start) — should NOT lint
  static StreamController<Map<String, String?>>? _sharedController;
  static StreamSubscription<int>? _tableUpdateSub;

  static StreamController<Map<String, String?>> controller() {
    final existing = _sharedController;
    if (existing != null) return existing;
    final created = StreamController<Map<String, String?>>.broadcast(
      onListen: _start,
      onCancel: _stop,        // releases the source when the last listener leaves
    );
    _sharedController = created;
    return created;
  }

  static void _start() {
    _tableUpdateSub = Stream<int>.periodic(const Duration(seconds: 1)).listen((_) {});
  }

  static void _stop() {
    _tableUpdateSub?.cancel();
    _tableUpdateSub = null;
  }
}
```

**Frequency:** Always for static-only holder classes (`abstract final class`, private constructor) with a StreamController field.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: no instance exists; the lifecycle is driven by `onListen`/`onCancel` |
| **Actual** | `[require_dispose_pattern] Class has StreamController, AnimationController, or other disposable fields but no cleanup method. ... {v4}` at `user_preference_drift_stream_io.dart` 15:1 |

---

## AST Context

```
CompilationUnit
  └─ ClassDeclaration (DatabaseUserPreferenceDriftStreamIO)   <- reported (atNode(node))
      ├─ FieldDeclaration (static StreamController<...>? _sharedController)   <- hasDisposable = true
      ├─ FieldDeclaration (static StreamSubscription<...>? _tableUpdateSub)
      └─ MethodDeclaration ... (no `dispose` / `close`)
```

---

## Root Cause

`performance_rules.dart:3300-3352`: the loop over `node.bodyMembers` sets `hasDisposable` for any `FieldDeclaration` whose `fields.type.toSource()` matches the regex `\bStreamController\b` (lines ~3334-3339), regardless of `member.isStatic` and class modifiers. `hasDisposeMethod` is set only by a method named exactly `dispose` or `close` (line ~3342-3345). The two early exits (widget/State superclass, const constructor; lines ~3309-3328) do not cover `abstract final class` or static-only holders. Line 3349 `if (hasDisposable && !hasDisposeMethod) reporter.atNode(node)` then fires.

---

## Why the code is correct

- `abstract final class` cannot be extended, implemented or instantiated; there is no instance whose `dispose()` could be called.
- Cleanup exists: `onCancel: _stopSharedSource` cancels the table-update subscription and clears the cached snapshot when the last listener leaves; the controller is re-created on the next listen. A `dispose()` on a process-lifetime static singleton would race active listeners.

---

## Affected project locations

- `lib/database/drift_middleware/user_data/user_preference_drift_stream_io.dart:15`

---

## Suggested Fix

In `RequireDisposePatternRule`: ignore static fields (`member.isStatic`) when computing `hasDisposable`, and skip classes that have only static members or are `abstract final` / `abstract` with `final` modifier. Optionally accept a controller built with `onCancel:` as managed.

---

## Fixture Cases

```dart
// expect LINT
class Manager {
  final StreamController<int> _c = StreamController<int>();   // instance field, no dispose
}

// expect NO lint
class WithDispose {
  final StreamController<int> _c = StreamController<int>();
  void dispose() => _c.close();
}

// expect NO lint
abstract final class StaticHolder {
  static StreamController<int>? _shared;
  static void use() { _shared ??= StreamController<int>.broadcast(onCancel: () {}); }
}
```

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Triggering project/file: `/Users/craighathaway/Documents/src/contacts/lib/database/drift_middleware/user_data/user_preference_drift_stream_io.dart`
