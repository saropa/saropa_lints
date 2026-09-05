# BUG: `require_catch_logging` — False positive on catch blocks with intentional fallback/degrade-gracefully patterns

**Status: Fixed**

Created: 2026-09-05
Rule: `require_catch_logging`
File: `lib/src/rules/security/security_network_input_rules.dart` (grep for exact line)
Severity: False positive
Rule version: v2

---

## Summary

The rule fires 25 times on catch blocks that intentionally swallow exceptions as part of a documented "degrade gracefully" or "best-effort" pattern. Every flagged catch block either:
- Returns a safe fallback value (`null`, empty list, default config)
- Continues a loop (skip-one-file-and-continue)
- Has an explanatory comment stating why swallowing is safe

The companion rule `avoid_swallowing_exceptions` fires 4 more times on the same blocks. None of the 29 findings are genuine — the rule cannot distinguish intentional, documented exception suppression from accidental swallowing.

---

## Attribution Evidence

```bash
grep -rn "'require_catch_logging'" lib/src/rules/
# (paste actual match)

grep -rn "'avoid_swallowing_exceptions'" lib/src/rules/
# (paste actual match)
```

---

## Reproducer

```dart
// Pattern 1: Documented fallback return (analyzer_metadata_compat_utils.dart)
/// Returns false on analyzer versions that lack this API.
bool hasFeature() {
  try {
    return _reflectiveCheck();
  } on NoSuchMethodError {
    return false; // LINT — but should NOT lint (documented version-probe)
  }
}

// Pattern 2: Skip-and-continue in file walk (project_vibrancy.dart)
for (final file in files) {
  try {
    processFile(file);
  } on FileSystemException {
    // Permission denied or dir vanished mid-walk — skip it.
    continue; // LINT — but should NOT lint
  }
}

// Pattern 3: Best-effort cleanup (health_history.dart)
try {
  tempDir.deleteSync(recursive: true);
} on FileSystemException {
  // Best-effort temp cleanup; a leftover temp dir is harmless.
  // LINT — but should NOT lint
}
```

**Frequency:** Always — fires on any catch that does not call a logging function.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when catch block returns a fallback, continues a loop, or has an explanatory comment |
| **Actual** | `[require_catch_logging] Catch block swallows the exception without logging or rethrowing` on all 25 catch blocks |

---

## Root Cause

### Hypothesis A: Rule only checks for log/rethrow, not fallback-return or documented suppression

The rule likely looks for `log(...)`, `print(...)`, `stderr.writeln(...)`, or `rethrow` in the catch body. It does not recognize:
- `return <fallback>` as handling (the caller gets a safe value)
- `continue` as handling (the loop proceeds past the bad item)
- Comments explaining why swallowing is intentional

### Hypothesis B: Rule does not account for package type

In a CLI tool / analyzer plugin, best-effort I/O is the correct pattern. The rule's security framing ("hides potential attack activity") does not apply.

---

## Suggested Fix

1. If the catch body contains a `return` statement, treat it as handled (the exception influenced control flow — it produced a fallback).
2. If the catch body contains `continue` or `break`, treat it as handled.
3. Consider a comment-based opt-out: if the catch body has a `//`  comment explaining the swallow, accept it.
4. Exempt CLI/tool packages from this rule entirely.

---

## Affected Files (all 25 require_catch_logging + 4 avoid_swallowing_exceptions)

- `android_manifest_utils.dart:52,72` — retry-next / null-out on read failure
- `baseline_file.dart:52,54` — return null per documented contract
- `analyzer_metadata_compat_utils.dart:54,65,67,73,75` — analyzer version probes
- `audit_baseline.dart:55` — malformed JSON → null
- `cross_file_dead_imports_semantic.dart:58` — skip unresolvable files
- `cross_file_options_config.dart:63` — return default options
- `health_history.dart:106,164,187,237` — temp cleanup / corrupt cache fallback
- `project_context_project_file.dart:113` — directory walk → null
- `project_vibrancy_resolved_usage.dart:130,156` — degrade fully on analyzer error
- `size_scanner.dart:214` — likely stale line mapping (no catch at reported line)
- `rule_packs.dart:324` — semver parse failure → null
- `project_context_incremental_priority.dart:314,382` — cache parse → null
- `project_vibrancy.dart:689,719` — file walk permission/vanish → skip

---

## Environment

- saropa_lints version: current (unreleased)
- Dart SDK version: current
