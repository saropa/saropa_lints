# Bug Report: `require_ios_lifecycle_handling`

**File:** `lib/src/rules/ios_rules.dart` (line ~5181)

---

## 1. Misleading Name

The rule is named `require_ios_lifecycle_handling` but the behavior it enforces (pausing timers/subscriptions when backgrounded) benefits **all platforms** — Android, desktop, and web included. iOS is just more aggressive about punishing violations.

**Suggestion:** Rename to `require_lifecycle_handling` or `require_app_lifecycle_handling`.

Update the lint message accordingly — current message says "save battery" which is platform-agnostic.

---

## 2. File-Level Skip Is Too Coarse

The rule checks if the **entire file source** contains lifecycle keywords:

```dart
if (fileSource.contains('WidgetsBindingObserver') ||
    fileSource.contains('didChangeAppLifecycleState') ||
    fileSource.contains('AppLifecycleListener')) {
  return; // skips ALL checks in the file
}
```

This means if **one** class in a file has lifecycle handling, **all other classes** in the same file get a free pass. Example: `user_account_auth_dot.dart` has two State classes — fixing one silences the lint for the other.

**Suggestion:** Check per-class instead of per-file. Each `State` class with a `.listen()` or `Timer.periodic()` should independently require lifecycle handling.

---

## 3. Missing Detection Patterns

Currently only detects:
- `Timer.periodic(...)` — checks `target == 'Timer'` and `methodName == 'periodic'`
- Any `.listen()` call

**Not detected:**
- `Timer(duration, callback)` — one-shot timers that could still fire in background
- `Stream.periodic()` passed directly to a `StreamBuilder` (arguably OK since Flutter manages it)
- `RestartableTimer` or custom timer wrappers

The `.listen()` catch-all is actually good — it catches all stream subscriptions regardless of source.

---

## 4. StreamBuilder Is Not Flagged (By Design?)

`StreamBuilder` is not detected because it's a constructor call, not a `.listen()`. This is probably correct — Flutter's `StreamBuilder` manages its own subscription lifecycle via `State.dispose()`. But worth documenting this as intentional in the rule's description, since users will wonder why their `StreamBuilder` streams don't trigger the lint while `.listen()` on the same stream does.

---

## Summary of Suggested Changes

| Issue | Priority | Suggestion |
|-------|----------|------------|
| Name says "ios" but applies to all platforms | Medium | Rename to `require_app_lifecycle_handling` |
| File-level skip misses classes in multi-class files | High | Check per State class, not per file |
| `Timer()` (non-periodic) not detected | Low | Add detection for one-shot `Timer` constructor |
| StreamBuilder exclusion not documented | Low | Add note to rule description |
