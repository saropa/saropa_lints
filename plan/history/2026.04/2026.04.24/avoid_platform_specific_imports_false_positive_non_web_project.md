# BUG: `avoid_platform_specific_imports` — Fires in Mobile-Only Projects That Don't Target Web

**Status: Fix Ready**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-04-24
Rule: `avoid_platform_specific_imports`
File: `lib/src/rules/config/config_rules.dart` (line ~623)
Severity: False positive
Rule version: v1 | Since: v5.1.0 | Updated: v5.1.0

---

## Summary

The rule flags every `import 'dart:io';` statement in shared library code
regardless of whether the host project actually targets the web platform.
It should only fire in projects that declare web as a build target (i.e.
projects that have a `web/` directory at the project root, or that declare
`flutter.plugin.platforms.web` / otherwise support browser builds).

In a pure mobile Flutter app (android + ios + macos, no `web/`), importing
`dart:io` can never cause a web compile failure because the project never
compiles for web. The entire justification for the rule's message —
"dart:io is unavailable on web and will cause compile failures when
targeting browser platforms" — does not apply to the project being
analyzed. Every `dart:io` import in such a project is a correct, idiomatic
choice, and every diagnostic raised is noise.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_platform_specific_imports'" lib/src/rules/
# lib/src/rules/config/config_rules.dart:640:    'avoid_platform_specific_imports',

# Negative — rule is NOT in sibling saropa_drift_advisor repo
grep -rn "'avoid_platform_specific_imports'" ../saropa_drift_advisor/
# 0 matches
```

**Emitter registration:** `lib/src/rules/config/config_rules.dart:640`
**Rule class:** `AvoidPlatformSpecificImportsRule` — registered in
`lib/saropa_lints.dart:2896`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart`
(`_generated_diagnostic_collection_name_#2`)

---

## Reproducer

The real-world trigger is a mobile-only Flutter app (the `saropa` contacts
app at `d:\src\contacts`) whose `pubspec.yaml` does not declare web as a
supported platform and whose project root contains **only**
`android/`, `ios/`, and `macos/` directories (no `web/`).

Flagged file: `lib/database/drift/migration/isar_to_drift_migrator.dart`

```dart
// First line of the file — flagged by the rule.
import 'dart:io' as io; // LINT — but should NOT lint: project has no web target.

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
// ...

/// One-time data migration from Isar to Drift, which uses File I/O
/// to locate and delete legacy Isar database files on mobile storage.
/// This code can never run on web because the project does not build
/// for web — no `web/` directory, no web platform declaration.
abstract final class IsarToDriftMigrator {
  const IsarToDriftMigrator._();
  // ...uses io.File(...), io.Directory(...), etc.
}
```

Minimal stand-alone reproducer (drop into any Flutter project that does
**not** have a `web/` directory):

```dart
// lib/example.dart
import 'dart:io'; // LINT (actual) — but should NOT lint (expected) on mobile-only project.

Future<String> readConfig(String path) async {
  return File(path).readAsStringSync();
}
```

Contrast with the correct behavior — in a project that **does** have
`web/` at its root:

```dart
// lib/example.dart  (in a project with web/ directory)
import 'dart:io'; // LINT (actual and expected) — project targets web, this will break.
```

**Frequency:** Always, on any `dart:io` import in any project that does
not currently have a `web/` directory or otherwise declare web support.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic in projects that do not target the web platform. Diagnostic only fires when the host project has a `web/` directory at project root (or otherwise declares web as a supported Flutter platform). |
| **Actual** | `[avoid_platform_specific_imports] dart:io import detected in shared code. dart:io is unavailable on web and will cause compile failures when targeting browser platforms.` fires on every `dart:io` import regardless of the project's declared platforms. |

---

## AST Context

```
CompilationUnit (isar_to_drift_migrator.dart)
  └─ ImportDirective ("dart:io" as io)  ← node reported here
```

The rule is registered on `ImportDirective` and inspects only
`node.uri.stringValue == 'dart:io'`. It does **not** consult the host
project's platform declarations before reporting.

---

## Root Cause

The `runWithReporter` implementation at
`lib/src/rules/config/config_rules.dart:669-689` performs exactly two
gates before reporting:

1. Skip if the file's path contains a platform-specific directory
   segment (e.g. `/native/`, `/android/`, `/ios/`, …) — this filters
   out files that are already platform-scoped by directory.
2. Skip if the `dart:io` import carries a configuration clause
   (`if (dart.library.io)`) — this recognizes the conditional-import
   escape hatch.

There is **no third gate** that asks: "does the host project actually
target web?" So the rule reports even when the rule's stated failure
mode — "compile failures when targeting browser platforms" — is
structurally impossible for this project.

### Hypothesis A (primary): No project-level web detection

`ProjectContext` (see `lib/src/project_context_project_file.dart`) has
helpers for `hasDependency`, `getPackageName`, `flutterSdkAtLeast`, and
`isFlutterProject`, but no `hasWebSupport` / `targetsWeb` predicate.
The rule needs such a predicate and needs to call it at the top of
`runWithReporter`, returning early when the project does not target web.

A reasonable signal set for "project targets web":

- `web/` directory exists at the project root (matches standard Flutter
  template layout).
- `pubspec.yaml` declares `flutter.plugin.platforms.web` (plugin
  packages that explicitly support web).
- `pubspec.yaml` has no `flutter:` block at all (pure Dart library
  intended to run anywhere, including web — keep the current behavior
  here so library authors still get the warning).

The simplest, lowest-false-positive heuristic is the first bullet:
check whether `<projectRoot>/web/` exists as a directory. Flutter apps
that support web always have this directory (it's created by
`flutter create` when `--platforms` includes `web` and it's the
required root for `index.html`). Its absence is a strong signal that
the project cannot produce a web build.

### Hypothesis B (secondary): Ignoring test files / tool scripts

Unlike many other rules in the codebase, this rule does not skip test
files or `tool/`, `bin/`, `scripts/` directories where `dart:io` use
is common and correct even in web-targeting projects (tests and build
scripts run on the VM only). This is a separate concern from the main
issue but worth fixing in the same patch.

---

## Suggested Fix

Add a project-level web-support check to `ProjectContext` and consult
it at the top of `AvoidPlatformSpecificImportsRule.runWithReporter`.

### Change 1 — `lib/src/project_context_project_file.dart`

Add a cached `hasWebSupport` flag to `_ProjectInfo` and a public
accessor on `ProjectContext`:

```dart
// In _ProjectInfo:
final bool hasWebSupport;

// In _ProjectInfo._fromProjectRoot:
//
// Web support is signaled by the presence of a `web/` directory at the
// project root — created by `flutter create --platforms=web`. A pure
// Dart library without a `flutter:` block in pubspec.yaml is treated
// as potentially web-targeting (libraries run everywhere by default).
final hasWeb =
    Directory('$projectRoot/web').existsSync() || !isFlutter;

// In ProjectContext:
static bool hasWebSupport(String? filePath) {
  return getProjectInfo(filePath)?.hasWebSupport ?? true; // unknown → assume yes
}
```

### Change 2 — `lib/src/rules/config/config_rules.dart` (~line 669)

```dart
@override
void runWithReporter(
  SaropaDiagnosticReporter reporter,
  SaropaContext context,
) {
  // Skip projects that do not target the web platform — the rule's
  // entire justification is "dart:io breaks web builds". If the
  // project has no `web/` directory and isn't a pure Dart library,
  // the stated failure mode cannot occur and every diagnostic is noise.
  if (!ProjectContext.hasWebSupport(context.filePath)) return;

  // Skip platform-specific directories (existing logic)
  final String path = context.filePath.replaceAll('\\', '/');
  for (final String dir in _platformDirs) {
    if (path.contains(dir)) return;
  }

  context.addImportDirective((ImportDirective node) {
    final String? uri = node.uri.stringValue;
    if (uri != 'dart:io') return;

    if (node.configurations.isNotEmpty) return;

    reporter.atNode(node);
  });
}
```

The default `true` return on unknown projects preserves the current
"assume modern / assume strict" philosophy used by `flutterSdkAtLeast`
(see comment at `lib/src/project_context_project_file.dart:79-82`): when
we can't tell, prefer to warn.

---

## Fixture Gap

The fixture at
`example/lib/config/avoid_platform_specific_imports_fixture.dart`
currently tests only file-level conditions (path-based skips,
conditional imports). It does not test project-level web targeting
because fixtures live in a single project.

To close the gap, add a multi-project test in the test suite (not the
single-file fixture) that:

1. **Project with `web/` directory** — `import 'dart:io';` → LINT
2. **Project without `web/` directory, with `flutter:` block** —
   `import 'dart:io';` → NO LINT
3. **Pure Dart library (no `flutter:` block)** — `import 'dart:io';`
   → LINT (libraries may be consumed by web clients)
4. **Project without `web/` + conditional import** → NO LINT
   (existing behavior preserved)
5. **Project with `web/` + file under `lib/native/`** → NO LINT
   (existing platform-dir skip preserved)

The fixture file itself should gain comments clarifying that its
host project has no `web/` directory, so the entire fixture documents
the "no web → no lint" branch.

---

## Changes Made

### `lib/src/project_context_project_file.dart`

- Added `hasWebSupport` boolean field to `_ProjectInfo`, computed once
  per-project at `_fromProjectRoot` time. The computation collapses two
  signals into one yes/no:
  1. `Directory('$projectRoot/web').existsSync()` — the canonical signal
     that a Flutter app can produce a web build (`flutter create
     --platforms=web` creates this directory and `index.html` lives in
     it).
  2. `!isFlutter` — pure Dart libraries may be consumed by browser
     clients, so web-compat warnings still apply regardless of `web/`.
  All three error branches in the factory (no pubspec, `FormatException`,
  `IOException`) default the field to `true` to preserve the
  "unknown → assume strict" philosophy already used by `flutterSdkAtLeast`.
- Added public accessor `ProjectContext.hasWebSupport(String? filePath)`
  that returns the cached flag, or `true` when the project can't be
  resolved. Doc-comment explains the signal set, default behavior, and
  points back to this bug report for rationale.

### `lib/src/rules/config/config_rules.dart`

- Added a new first gate in `AvoidPlatformSpecificImportsRule.runWithReporter`:
  ```dart
  if (!ProjectContext.hasWebSupport(context.filePath)) return;
  ```
  Both existing gates (platform-directory skip, conditional-import
  escape hatch) are preserved unchanged and run after the new gate, so
  the behavior for projects that do target web is unchanged. The
  comment above the gate cites this bug report and explains why the
  gate is safe (unknown → `true` → rule still fires).

### `CHANGELOG.md`

- Added a `### Fixed` entry in `[Unreleased]` that links to this bug
  report and to the new test file.

---

## Tests Added

`test/avoid_platform_specific_imports_web_gate_test.dart` — six cases,
each materializing a fresh synthetic project root in
`Directory.systemTemp` so the per-root `_projectCache` entries never
leak between tests:

1. **Flutter project with `web/` directory** → `hasWebSupport` is `true`
   (rule should fire on `dart:io`).
2. **Flutter project without `web/` directory** → `hasWebSupport` is
   `false` (rule should NOT fire — the real-world bug case).
3. **Pure Dart library (no `flutter:` block) without `web/`** →
   `hasWebSupport` is `true` (library authors can't know callers'
   platforms, so warn).
4. **`null` filePath** → `hasWebSupport` is `true` (unknown → strict).
5. **Empty filePath** → `hasWebSupport` is `true` (unknown → strict).
6. **Path with no pubspec at any ancestor** → `hasWebSupport` is `true`
   (unknown → strict).

All six pass; the pre-existing `flutter_sdk_version_test.dart` and
`config_rules_test.dart` suites continue to pass, confirming no
regression on adjacent `ProjectContext` paths.

The fixture at `example/lib/config/avoid_platform_specific_imports_fixture.dart`
is untouched — the example project is a pure Dart library (no `flutter:`
block in `example/pubspec.yaml`), so it hits the `!isFlutter` branch and
the rule continues to fire on the bare `dart:io` import exactly as before.

### Fixture Gap Note

The wider multi-project fixture matrix suggested in the original bug
report (projects with/without `web/`, conditional imports, `lib/native/`
scoping) is still open as a follow-up. The unit tests in
`avoid_platform_specific_imports_web_gate_test.dart` exercise the
project-level predicate directly — which is the actual load-bearing
change — but do not round-trip through the full analyzer plugin. A
future fixture harness that can stand up multiple fake project roots
would be the right place to exercise the end-to-end path.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: (current, rule v1 since v5.1.0)
- Dart SDK version: (Flutter 3.x stable)
- custom_lint version: N/A — `saropa_lints` is a native analyzer plugin,
  not `custom_lint`-based (per project memory).
- Triggering project/file:
  `d:\src\contacts\lib\database\drift\migration\isar_to_drift_migrator.dart`
  line 1. Contacts project targets android/ios/macos only — no `web/`
  directory at project root.
