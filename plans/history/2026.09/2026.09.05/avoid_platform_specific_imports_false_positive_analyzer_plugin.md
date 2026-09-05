# BUG: `avoid_platform_specific_imports` — False positive on analyzer plugin package that legitimately uses dart:io

**Status: Fixed**

## Resolution

Added `ProjectContext.isCliOrToolPackage` (pubspec `executables:` section, or a
`custom_lint_builder`/`analyzer_plugin` dependency) and
`ProjectContext.isInShortLivedToolDirectory` (file under `bin/`/`tool/`) guards
to `AvoidPlatformSpecificImportsRule` in
`lib/src/rules/config/config_rules.dart`. saropa_lints' own pubspec declares
`executables:`, so the package now self-exempts. The same
`isCliOrToolPackage` guard was also applied to `avoid_stack_trace_in_production`,
`require_cache_expiration`, `avoid_unbounded_cache_growth`, and
`require_url_validation`. `isInShortLivedToolDirectory` was promoted from a
private duplicate in `memory_management_rules.dart` to a shared
`ProjectContext` method. Unit tests added in
`test/rules/platforms/avoid_platform_specific_imports_web_gate_test.dart`.

Created: 2026-09-05
Rule: `avoid_platform_specific_imports`
File: `lib/src/rules/config/config_rules.dart` (line ~699)
Severity: False positive
Rule version: v1

---

## Summary

The rule fires 46 times across `lib/` on `dart:io` imports. saropa_lints is a Dart analyzer plugin and CLI tool — it reads files from disk, resolves paths, and runs processes. It is never compiled for web. `dart:io` is a legitimate, required dependency. The rule's "shared code" heuristic is wrong for this package type.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_platform_specific_imports'" lib/src/rules/
# lib/src/rules/config/config_rules.dart:699:    'avoid_platform_specific_imports',
```

---

## Reproducer

```dart
// lib/src/project_context.dart — analyzer plugin, never runs on web
import 'dart:io'; // LINT — but should NOT lint

class ProjectContext {
  final Directory projectRoot;
  // ...
}
```

**Frequency:** Always — every `dart:io` import in the package.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — this package is an analyzer plugin/CLI tool, not a web-targeting library |
| **Actual** | `[avoid_platform_specific_imports] dart:io import detected in shared code` reported 46 times |

---

## Root Cause

### Hypothesis A: No package-type awareness

The rule flags all `dart:io` imports in `lib/` without checking the package's platform constraints. Packages that declare `platforms:` excluding web in `pubspec.yaml`, or that are `custom_lint` analyzer plugins (declared via `analyzer: plugin`), should be exempt.

### Hypothesis B: Self-exemption missing

The rule should not fire on `saropa_lints` own source code. An analyzer plugin package is server-side by definition.

---

## Suggested Fix

Options (pick one or both):
1. Check `pubspec.yaml` platform constraints — if the package does not target web, skip.
2. Add a self-exemption: if the analyzed file belongs to the saropa_lints package itself, skip.
3. Check for `custom_lint` plugin declaration in the project's `analysis_options.yaml`.

---

## Fixture Gap

The fixture should include:

1. **dart:io import in a CLI/server package** — expect NO lint
2. **dart:io import in a multi-platform package** — expect LINT
3. **dart:io import in an analyzer plugin** — expect NO lint

---

## Environment

- saropa_lints version: current (unreleased)
- Dart SDK version: current
- Triggering files: 46 files across `lib/src/` (CLI, baseline, config, init, scan, project_context)
