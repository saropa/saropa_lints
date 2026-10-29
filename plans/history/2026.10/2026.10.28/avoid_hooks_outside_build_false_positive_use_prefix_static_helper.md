# BUG: `avoid_hooks_outside_build` — flags plain static helpers whose name starts with `use`

**Status: Open**

Created: 2026-10-28
Rule: `avoid_hooks_outside_build`
File: `lib/src/rules/packages/flutter_hooks_rules.dart` (line ~62)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: 17.0.1-beta.1

---

## Summary

`NativeImportClaimWrite.useCleanedRows(...)` and `useCleanedStranded(...)` are ordinary static data helpers ("use the cleaned copy of a row"). The rule matches the `use` name prefix alone. The project does not import `flutter_hooks` at all.

---

## Attribution Evidence

```bash
grep -rn "'avoid_hooks_outside_build'" lib/src/rules/
# lib/src/rules/packages/flutter_hooks_rules.dart:62:    'avoid_hooks_outside_build',
```

---

## Reproducer

```dart
class ClaimWrite {
  static List<String> useCleanedRows(List<String> rows, Map<String, String> cleaned) =>
      rows.map((String r) => cleaned[r] ?? r).toList();
}

Future<void> process(List<String> rows) async {
  final List<String> out = ClaimWrite.useCleanedRows(rows, <String, String>{}); // LINT — but should NOT lint
}
```

**Frequency:** Any method named `useXxx` outside `build`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic. Not a hook |
| **Actual** | `[avoid_hooks_outside_build]` on the call |

---

## Suggested Fix

Only run when the file imports `package:flutter_hooks`, and only flag calls that resolve to a function declared in that package (or a function marked as a hook), not name-prefix matches. A prefixed call target (`Class.useX`) should never be a hook.

---

## Environment

- saropa_lints version: 17.0.1-beta.1
- Triggering project/file: saropa contacts app — `lib/utils/native_phone_import/native_import_db_process.dart:151,158`
