# BUG: `require_file_path_sanitization` — parameter named `path` matches the property `directory.path`

**Status: Fixed**

Created: 2026-11-26
Rule: `require_file_path_sanitization`
File: `lib/src/rules/resources/file_handling_rules.dart` (line ~1904)
Severity: False positive
Rule version: v3 (message tag) | Since: v4.2.0 | Updated: v4.13.0

---

## Summary

A parameter named `path` is considered used in a file path whenever the path expression reads any `.path` property.

---

## Attribution Evidence

```bash
grep -rn "'require_file_path_sanitization'" lib/src/rules/
# lib/src/rules/resources/file_handling_rules.dart:1821:    'require_file_path_sanitization',
```

**Emitter registration:** `lib/src/rules/resources/file_handling_rules.dart:1821`
**Rule class:** `RequireFilePathSanitizationRule` — registered in `lib/saropa_lints.dart:2384`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Derived from reading the rule source. Not executed.

```dart
import 'dart:io';

Future<void> probe(String? path) async {
  final Directory appDir = Directory('/data/app');
  final File f = File('${appDir.path}/.write_probe'); // LINT — but should NOT lint
  await f.writeAsString('probe');
}
```

**Frequency:** Always

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic |
| **Actual** | `[require_file_path_sanitization]` reported on the line marked LINT |

---

## AST Context

```
FunctionDeclaration (probe)
  └─ Block
      └─ VariableDeclaration (f)
          └─ InstanceCreationExpression (File)  ← reported
```

---

## Root Cause

Lines ~1904-1925 run `\bparamName\b` over the path argument's source text. `.` is a word boundary, so the property name in `appDir.path` matches the parameter `path`.

Note on the original site: the directory there is built from the parameter, and the only appended segment is a constant file name. The report still comes from the text match.

---

## Suggested Fix

Match resolved elements: visit `SimpleIdentifier`s in the argument and compare each `element` with the parameter element, ignoring property names.

---

## Fixture Gap

1. Parameter `path`, argument reads `other.path` plus a literal — expect NO lint
2. `File('${dir.path}/$path')` — expect LINT

---

## Environment

- saropa_lints version: 17.9.1 (rule source read at this version)
- Dart SDK version: not recorded
- Triggering project/file: a private Flutter app

---

## Finish Report (2026-11-26)

**Fix** (`lib/src/rules/resources/file_handling_rules.dart`, rule version v4): the source-text match on the parameter name was replaced by an AST search for a real reference. Member names (`dir.path`, `this.name`), shadowing locals and literal text no longer count; any use of the parameter itself (bare, receiver, call argument, index) still does.

**Reproducer correction:** the original reproducer also declared `Directory appDir` as a parameter and used it as the path base. That is a genuine parameter reference, so it is still reported by design. The false positive is the case where `appDir` is not a parameter; the reproducer above was rewritten accordingly.

**Related, not fixed:** `avoid_path_traversal` has the same name-match defect, filed as `bugs/avoid_path_traversal_false_positive_parameter_name_matches_property.md`.

Tests: `dart test test/rules/resources/require_file_path_sanitization_fixture_test.dart test/rules/resources/file_handling_rules_test.dart` - passed.
