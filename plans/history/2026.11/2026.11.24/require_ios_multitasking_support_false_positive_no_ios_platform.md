# BUG: `require_ios_multitasking_support` — Fires in a project with no `ios/` folder

**Status: Open**

Created: 2026-11-24
Rule: `require_ios_multitasking_support`
File: `lib/src/rules/platforms/ios_platform_lifecycle_rules.dart` (line ~3697)
Severity: False positive
Rule version: v2 | saropa_lints 17.7.9

---

## Summary

The rule reports a `Row` under a `Scaffold` because "iPads support Split View and Slide Over", but the project targets only Android and Windows (`android/` and `windows/` exist, no `ios/`). The message cannot apply. A sibling rule already gates on project platforms (`prefer_cursor_for_buttons` uses `ProjectContext.hasPointerPlatform`); this one has no gate. Expected: return early when the project has no `ios/` directory.

---

## Attribution Evidence

```bash
grep -rn "'require_ios_multitasking_support'" lib/src/rules/
# lib/src/rules/platforms/ios_platform_lifecycle_rules.dart:3697
```

---

## Reproducer

Project layout: `android/`, `windows/`, `lib/`, `pubspec.yaml`; no `ios/`.

```dart
class Saver extends StatelessWidget {
  const Saver({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Row( // LINT — but should NOT lint: project has no iOS target
      mainAxisSize: MainAxisSize.min,
      children: const [Icon(Icons.cloud), SizedBox(width: 16), Text('Sunny')],
    ),
  );
}
```

**Frequency:** Always

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the project declares no iOS platform |
| **Actual** | `[require_ios_multitasking_support] Fixed layout detected. iPads support Split View and Slide Over. Layouts should adapt to window size changes. {v2}` |

---

## Root Cause

`runWithReporter` has no `ProjectContext` platform check. Its only exemption is a file-text scan for `LayoutBuilder` / `OrientationBuilder` / `constraints.maxWidth` / `breakpoint`.

## Suggested Fix

Add a project-level iOS gate (a `ProjectContext.hasIosPlatform(filePath)` next to `hasPointerPlatform` in `lib/src/project_context_project_file.dart`, true when `ios/` exists, default true when unknown) and return early when false. Audit other `ios_*` rules for the same missing gate.

## Fixture Gap

ProjectContext unit test or fixture project without `ios/`: expect NO lint; with `ios/`: expect LINT.

---

## Environment

- saropa_lints version: 17.7.9
- Triggering project/file: jupiter-tablet `lib/ui/saver_screen.dart` (2 Rows)
