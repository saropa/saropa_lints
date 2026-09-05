# BUG: `avoid_stack_trace_in_production` — False positive on CLI/developer tool error handling

**Status: Fixed**

Created: 2026-09-05
Rule: `avoid_stack_trace_in_production`
File: `lib/src/rules/security/security_network_input_rules.dart` (line ~4736)
Severity: False positive
Rule version: v1

---

## Summary

The rule fires 49 times on stack trace usage in CLI tools, init runners, log writers, and error handlers. saropa_lints is a developer tool — its CLI output is consumed by developers, not end users. Stack traces in a `dart run saropa_lints scan` CLI are expected diagnostic output, not a security leak. The OWASP M10 framing ("aids in crafting targeted exploits") does not apply to a local developer tool.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_stack_trace_in_production'" lib/src/rules/
# lib/src/rules/security/security_network_input_rules.dart:4736:    'avoid_stack_trace_in_production',
```

---

## Reproducer

```dart
// lib/src/init/log_writer.dart — CLI diagnostic logging
void logError(Object error, StackTrace stack) {
  stderr.writeln('Error: $error');
  stderr.writeln(stack); // LINT — but should NOT lint (developer tool CLI)
}
```

**Frequency:** Always — every `StackTrace` reference in catch/error handling code.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — stack traces in CLI/developer tool output are standard practice |
| **Actual** | `[avoid_stack_trace_in_production] Stack trace exposed to user-visible output` reported 49 times |

---

## Root Cause

### Hypothesis A: No package-type / output-channel awareness

The rule treats all stack trace exposure equally regardless of whether the output goes to:
- A mobile app UI (genuine security concern)
- A CLI stderr stream (standard developer diagnostics)
- A log file (expected practice)

Developer tools, CLI commands, and analyzer plugins should be exempt.

---

## Suggested Fix

1. Exempt packages that are CLI tools or analyzer plugins (check `pubspec.yaml` for `executables:` or `custom_lint` plugin declarations).
2. Distinguish between `stderr.writeln(stack)` (developer diagnostic) and `Text('$stack')` (user-facing UI).
3. At minimum, exempt files under paths like `cli/`, `init/`, `scan/` that are clearly tool infrastructure.

---

## Fixture Gap

The fixture should include:

1. **Stack trace logged to stderr in CLI tool** — expect NO lint
2. **Stack trace displayed in Flutter widget** — expect LINT
3. **Stack trace in developer.log()** — expect NO lint
4. **Stack trace sent to HTTP response body** — expect LINT

---

## Environment

- saropa_lints version: current (unreleased)
- Dart SDK version: current
- Triggering files: 49 hits across init_runner, log_writer, baseline_*, project_context_*, info_plist_utils, etc.
