# BUG: `avoid_context_after_await_in_static` — flags context use that is behind `context.mounted`

**Status: Open**

Created: 2026-10-28
Rule: `avoid_context_after_await_in_static`
File: `lib/src/rules/core/context_rules.dart` (line ~500)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: 17.0.1-beta.1

---

## Summary

Every use of `context` after an `await` is guarded by `if (!context.mounted ...) return`, or the await is `return await` (nothing runs after it). The rule still reports. Also related: `avoid_context_across_async` (see its own report).

---

## Attribution Evidence

```bash
grep -rn "'avoid_context_after_await_in_static'" lib/src/rules/
# lib/src/rules/core/context_rules.dart:500:    'avoid_context_after_await_in_static',
```

---

## Reproducer

```dart
class Checks {
  static Future<bool> preFlight(BuildContext context) async {
    final bool ok = await _login(context);
    if (!context.mounted || !ok) return false;
    return _next(context); // LINT — but should NOT lint (guarded)
  }

  static Future<bool> run(BuildContext context) async {
    try {
      return await _work(context);
    } on Object catch (e) {
      log(e, context.mounted ? context : null); // LINT — but should NOT lint (mounted ternary)
      return false;
    }
  }
}
```

**Frequency:** Always for these guard shapes in static methods.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic |
| **Actual** | `[avoid_context_after_await_in_static]` at the context use / parameter |

---

## Suggested Fix

Recognize guards: `if (!context.mounted) return`, `|| !context.mounted` early exits, and `context.mounted ? context : null`. Treat `return await f(context)` as having no use after the await.

---

## Environment

- saropa_lints version: 17.0.1-beta.1
- Triggering project/file: saropa contacts app — `lib/utils/share/contact_sharing_workflow_checks.dart:24,47`, `lib/utils/share/contact_sharing_workflow_util.dart:276`, `lib/utils/system/system_commands/run_command_location.dart:150`, `lib/utils/system/system_commands/run_command_user_type.dart:74`
