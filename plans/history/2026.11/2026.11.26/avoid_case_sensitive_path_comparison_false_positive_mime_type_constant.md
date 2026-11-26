# BUG: `avoid_case_sensitive_path_comparison` — treats a MIME type constant named `...folder...` as a path

**Status: Fixed**

Created: 2026-11-26
Rule: `avoid_case_sensitive_path_comparison`
File: `lib/src/rules/platforms/windows_rules.dart` (line ~431)
Severity: False positive
Rule version: v3 | Since: v4.9.20 | Updated: v4.13.0

---

## Summary

Comparing a MIME type string against a constant such as `_folderMimeType` is reported as a file path comparison.

---

## Attribution Evidence

```bash
grep -rn "'avoid_case_sensitive_path_comparison'" lib/src/rules/
# lib/src/rules/platforms/windows_rules.dart:418:    'avoid_case_sensitive_path_comparison',
```

**Emitter registration:** `lib/src/rules/platforms/windows_rules.dart:418`
**Rule class:** `AvoidCaseSensitivePathComparisonRule` — registered in `lib/saropa_lints.dart:2551`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Derived from reading the rule source. Not executed.

```dart
class Adapter {
  static const String _folderMimeType = 'application/vnd.google-apps.folder';

  bool isFile(String mimeType) => mimeType != _folderMimeType; // LINT — but should NOT lint
}
```

**Frequency:** Always

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic |
| **Actual** | `[avoid_case_sensitive_path_comparison]` reported on the line marked LINT |

---

## AST Context

```
MethodDeclaration (isFile)
  └─ ExpressionFunctionBody
      └─ BinaryExpression (!=)  ← reported
```

---

## Root Cause

`_containsPathPattern` (line ~71) does a plain substring test for every pattern except `path`. `folder` is in `_pathVariablePatterns` (line ~41), so `_folderMimeType` matches. `_isNonPathStringLiteral` does not apply to an identifier.

---

## Suggested Fix

Skip when either operand's name contains `mime`, `type` or `contentType`, and apply the camelCase word test to `folder`/`directory` as is done for `path`.

---

## Fixture Gap

1. `mimeType != _folderMimeType` — expect NO lint
2. `folderPath == otherFolderPath` — expect LINT

---

## Environment

- saropa_lints version: 17.9.1 (rule source read at this version)
- Dart SDK version: not recorded
- Triggering project/file: a private Flutter app

---

## Finish Report (2026-11-26)

**Fix** (`lib/src/rules/platforms/windows_rules.dart`, rule version v4): a comparison is skipped when either operand is a string literal, or a reference to a `const` string, whose value is a whole MIME type (a registered top-level type plus a listed subtype, or a `*`, `vnd.`/`prs.`/`x.`, `x-` or `+json`-style suffix form). The decision uses the value, not the identifier's spelling, so the name-based suggestion above (skip names containing `mime`/`type`) and the camelCase word test for `folder`/`directory` were not adopted.

**Guards:** a relative file path such as `text/readme.txt`, `image/cache`, `video/clips` or `model/user`, a leading slash, more than one slash, and non-const variables are still reported.

**Limits:**
- A named constant needs resolved elements. The unresolved `scan` still reports the reproducer; only a string literal operand is exempt there.
- A MIME type with an unlisted bare subtype is still reported.
- A folder constant spelled like a listed MIME type (`text/html`) is not reported.

Tests: `dart test test/rules/platforms/avoid_case_sensitive_path_comparison_fixture_test.dart test/rules/platforms/windows_rules_test.dart` - passed.
