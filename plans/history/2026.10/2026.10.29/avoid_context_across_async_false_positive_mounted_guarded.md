# BUG: `avoid_context_across_async` — flags context use that is behind `context.mounted`

**Status: Resolved (duplicate)**

Created: 2026-10-28
Rule: `avoid_context_across_async`
File: `lib/src/rules/core/context_rules.dart` (line ~251)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: 17.0.1-beta.1

---

## Summary

Context is used after an `await` only through `context.mounted ? context : null`, or the await is `return await`. This is a valid guard. Same code as the report for `avoid_context_after_await_in_static`.

---

## Attribution Evidence

```bash
grep -rn "'avoid_context_across_async'" lib/src/rules/
# lib/src/rules/core/context_rules.dart:251:    'avoid_context_across_async',
```

---

## Reproducer

```dart
static Future<bool> run(BuildContext context) async {
  try {
    return await _work(context);
  } on Object catch (error, stack) {
    debugException(error, stack, context: context.mounted ? context : null); // LINT — but should NOT lint
    return false;
  }
}
```

**Frequency:** Always for this shape.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic |
| **Actual** | `[avoid_context_across_async]` on the `context` use in the catch block |

---

## Suggested Fix

Accept `context.mounted ? context : null` (and `context.mounted && ...`) as a guard. Do not treat code in a `catch` after `return await` as a use after a suspended gap unguarded.

---

## Environment

- saropa_lints version: 17.0.1-beta.1
- Triggering project/file: saropa contacts app — `lib/utils/system/system_commands/run_command_location.dart:150`, `lib/utils/system/system_commands/run_command_user_type.dart:74`

## Status 2026-10-28

context_across_async: no code change, ternary report unconfirmed. Regression test added 2026-10-28; not reproducible; keep open until reporter confirms.

## Status 2026-10-29

Duplicate of `avoid_context_across_async_false_positive_await_in_returning_branch.md` (same site, `run_command_user_type.dart:74`). Fixed there: an `if` whose awaits sit only in returning branches no longer counts as an await. Archived.
