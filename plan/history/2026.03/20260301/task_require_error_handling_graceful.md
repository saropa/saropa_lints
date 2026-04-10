# Task: `require_error_handling_graceful`

## Summary
- **Rule Name**: `require_error_handling_graceful`
- **Tier**: Essential
- **Severity**: WARNING
- **Status**: Implemented (ROADMAP shows implemented; task file for reference/triage)
- **Source**: ROADMAP.md — 5.34 Error Handling Best Practices Rules

## Problem Statement

Show friendly errors in UI, not raw exception messages or `toString()`. Raw messages can leak internals and confuse users.

## Description (from ROADMAP)

> Show friendly errors in UI, not raw exception messages or toString().

## Code Examples

### Bad (should trigger)

```dart
catch (e, st) {
  showDialog(context, title: 'Error', child: Text(e.toString())); // LINT
}
```

### Good (should not trigger)

```dart
catch (e, st) {
  showDialog(context, title: 'Something went wrong', child: Text(userFriendlyMessage(e)));
}
```

## Detection: True Positives

- **Goal**: Detect UI code (e.g. Flutter widget build, showDialog, SnackBar) that displays `exception.toString()`, `e.message`, or similar raw exception output. Prefer type/usage checks (e.g. Text with expression that is catch variable).
- **Approach**: In catch blocks or error handlers, find references to exception in user-visible strings (Text, title, message). Report when raw exception is shown.

## False Positives

- **Mitigation**: Allow logging (e.g. `log(e.toString())`); only flag when used in UI-facing widgets. Exclude test files. Use type/element checks, not substring on "toString".

## External References

- [Dart Lint Rules](https://dart.dev/tools/linter-rules)
- [Flutter API](https://api.flutter.dev/)
- [custom_lint](https://pub.dev/packages/custom_lint)

## Quality & Performance

- Use `ProjectContext.isFlutterProject`; target catch blocks and widget constructors. Prefer `addMethodInvocation` / expression analysis.

## Notes & Issues

- Rule is implemented. This task file may be removed by `scripts/check_roadmap_implemented.py` when run.
