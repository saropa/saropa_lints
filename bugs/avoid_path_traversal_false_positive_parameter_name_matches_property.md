# BUG: `avoid_path_traversal` - parameter named `path` matches the property `directory.path`

**Status: Open**

Created: 2026-11-26
Rule: `avoid_path_traversal`
File: `lib/src/rules/security/security_network_input_rules.dart` (line ~2548)
Severity: False positive
Rule version: v8 (message tag)

---

## Summary

A parameter is treated as used in a file path whenever its name appears as a word in the path expression, including as the property name in `appDir.path`. The diagnostic is ERROR severity.

---

## Attribution Evidence

```bash
grep -rn "'avoid_path_traversal'" lib/src/rules/
# lib/src/rules/security/security_network_input_rules.dart:2496:    'avoid_path_traversal',
```

**Rule class:** `AvoidPathTraversalRule`, registered in `lib/saropa_lints.dart:1391`

---

## Reproducer

Executed with the resolved rule harness: reports line 5.

```dart
import 'dart:io';

void probe(String path) {
  final Directory appDir = Directory('/data/app');
  File('${appDir.path}/.write_probe'); // LINT - but should NOT lint
}
```

---

## Expected vs Actual

- Expected: no diagnostic. The parameter `path` is never referenced.
- Actual: `[avoid_path_traversal]`.

---

## Root Cause

`runWithReporter` runs `\bparamName\b` over the argument's source text. `.` is a word boundary.

---

## Suggested Fix

Search the argument's AST for a real reference to the parameter, as `require_file_path_sanitization` does with `_ParameterReferenceFinder` in `lib/src/rules/resources/file_handling_rules.dart`. Share one implementation.

---

## Environment

- saropa_lints version: 17.9.1 plus unreleased 17.10.0 changes
