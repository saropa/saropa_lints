# BUG: `avoid_string_substring` — False positive when index is guarded by regex match or indexOf

**Status: Fixed**

Created: 2026-09-05
Rule: `avoid_string_substring`
File: `lib/src/rules/data/collection_rules.dart` (grep for exact line)
Severity: False positive
Rule version: v3

---

## Summary

All 4 findings are false positives. Each `substring()` call uses an index that is provably in bounds, but the rule's guard-detection does not recognize these patterns:

1. **Regex match guarantees length** (`info_plist_utils.dart:191`): `normalized.substring(1)` is guarded by `RegExp(r'^/[A-Za-z]:/').hasMatch(normalized)` which guarantees length ≥ 4. The rule only recognizes `startsWith`/`length` guards, not `hasMatch`.

2. **indexOf-derived index** (`stale_ignore_detector.dart:368,410`): `line.substring(0, idx)` where `idx` comes from `indexOf`/regex match position — always within bounds when the match succeeded.

3. **RegExp.firstMatch end offset** (`custom_overrides_core.dart:416`): `content.substring(pos)` where `pos = headerMatch.end` from a `RegExp.firstMatch` — always within the matched string's bounds.

---

## Attribution Evidence

```bash
grep -rn "'avoid_string_substring'" lib/src/rules/
# (match in collection_rules.dart or data rules file)
```

---

## Reproducer

```dart
// FP: Regex-guarded substring — length guaranteed by match pattern
final re = RegExp(r'^/[A-Za-z]:/');
if (re.hasMatch(normalized)) {
  final fixed = normalized.substring(1); // LINT — but should NOT lint
}

// FP: indexOf-derived index — in bounds by construction
final idx = line.indexOf('//');
if (idx >= 0) {
  final before = line.substring(0, idx); // LINT — but should NOT lint
}
```

---

## Suggested Fix

1. Recognize `RegExp.hasMatch()` as a length guard when the pattern has a minimum match length.
2. Recognize `indexOf`/`firstMatch` results as in-bounds indices for the same string.
3. Recognize `RegExpMatch.end` / `.start` as valid bounds for the matched string.

---

## Affected Files

- `info_plist_utils.dart:191`
- `stale_ignore_detector.dart:368,410`
- `custom_overrides_core.dart:416`

---

## Environment

- saropa_lints version: current (unreleased)
