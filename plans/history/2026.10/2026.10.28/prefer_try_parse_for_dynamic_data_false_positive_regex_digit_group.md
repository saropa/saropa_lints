# BUG: `prefer_try_parse_for_dynamic_data` — flags `int.parse` on a regex-captured `\d{n}` group

**Status: Open**

Created: 2026-10-28
Rule: `prefer_try_parse_for_dynamic_data`
File: `lib/src/rules/data/json_datetime_rules.dart` (line ~233)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: 17.0.1-beta.1

---

## Summary

`int.parse(match.group(n)!)` is flagged although the group was matched by `\d{n}`, so parsing cannot throw (the digits are already validated; length is small). The enclosing caller also catches exceptions.

---

## Attribution Evidence

```bash
grep -rn "'prefer_try_parse_for_dynamic_data'" lib/src/rules/
# lib/src/rules/data/json_datetime_rules.dart:233:    'prefer_try_parse_for_dynamic_data',
```

---

## Reproducer

```dart
int? parseMonthDay(String trimmed) {
  final RegExpMatch? m = RegExp(r'^--(\d{2})-?(\d{2})$').firstMatch(trimmed);
  if (m == null) return null;
  final int month = int.parse(m.group(1)!); // LINT — but should NOT lint
  final int day = int.parse(m.group(2)!); // LINT — but should NOT lint
  return month * 100 + day;
}
```

**Frequency:** Always for `int.parse` on `RegExpMatch.group` results.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic. The group is guaranteed digits by the pattern |
| **Actual** | `[prefer_try_parse_for_dynamic_data]` on each `int.parse` |

---

## Suggested Fix

Skip when the argument is `RegExpMatch.group(n)` / `match[n]` and the regex literal's group n is a bounded `\d{n}` (or `\d{n,m}` with small m). Also skip when inside a `try` block that catches the exception.

---

## Environment

- saropa_lints version: 17.0.1-beta.1
- Triggering project/file: saropa contacts app — `lib/database/file_backup/import/vcard_import_event_parser.dart:51,52,62,63,83,84,85,99`
