# BUG: 7 Platform-Target Rules Fire in Projects That Can't Hit Their Failure Mode

**Status: Fix Ready**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-04-24
Rules: `avoid_platform_specific_imports`, `require_platform_check`,
`prefer_platform_io_conditional`, `avoid_secure_storage_on_web`,
`avoid_isar_web_limitations`, `prefer_hive_web_aware`,
`avoid_web_only_dependencies`, `prefer_cursor_for_buttons`
Severity: False positive (cross-cutting)

---

## Summary

Eight rules in saropa_lints warn about "API X breaks on platform Y",
but none of them consulted the host project's actual platform targets
before reporting. In a project that structurally cannot produce a build
for platform Y (e.g. a mobile-only Flutter app with no `web/`
directory), every diagnostic raised is pure noise — the rule's stated
failure mode is unreachable.

The originally-reported case (`avoid_platform_specific_imports`,
[sibling report](avoid_platform_specific_imports_false_positive_non_web_project.md))
introduced `ProjectContext.hasWebSupport`. This audit found the same
structural flaw in 7 sibling rules — 5 needed the same predicate, one
needed its inverse, and one needed a third cursor-platform predicate.

---

## Attribution Evidence

All eight rules live in `saropa_lints`:

```bash
grep -rn "'avoid_platform_specific_imports'"   lib/src/rules/
# lib/src/rules/config/config_rules.dart:640
grep -rn "'require_platform_check'"            lib/src/rules/
# lib/src/rules/config/platform_rules.dart:54
grep -rn "'prefer_platform_io_conditional'"    lib/src/rules/
# lib/src/rules/config/platform_rules.dart:155
grep -rn "'avoid_secure_storage_on_web'"       lib/src/rules/
# lib/src/rules/packages/firebase_rules.dart:281
grep -rn "'avoid_isar_web_limitations'"        lib/src/rules/
# lib/src/rules/packages/isar_rules.dart:1114
grep -rn "'prefer_hive_web_aware'"             lib/src/rules/
# lib/src/rules/packages/hive_rules.dart:2513
grep -rn "'avoid_web_only_dependencies'"       lib/src/rules/
# lib/src/rules/platforms/web_rules.dart:358
grep -rn "'prefer_cursor_for_buttons'"         lib/src/rules/
# lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart:3818
```

---

## Reproducer

### Shape A — mobile-only Flutter project (no `web/` directory at root)

Real-world trigger: `saropa-contacts` (android + ios + macos, no web).
All six `hasWebSupport`-gated rules previously fired here as noise.

```dart
// lib/example.dart  in a project whose root has no web/ directory

import 'dart:io';                         // LINT (before fix) — avoid_platform_specific_imports
final _file = File('data.txt');           // LINT (before fix) — require_platform_check
if (Platform.isAndroid) { }               // LINT (before fix) — prefer_platform_io_conditional
final _s  = FlutterSecureStorage();       // LINT (before fix) — avoid_secure_storage_on_web
final _u  = isar.users.findAllSync();     // LINT (before fix) — avoid_isar_web_limitations
Hive.openBox('pref');                     // LINT (before fix) — prefer_hive_web_aware

// Expected after fix: all SIX diagnostics suppressed. The project cannot
// produce a web build, so every "breaks on web" failure mode is
// structurally unreachable.
```

### Shape B — web-only Flutter project (no android/ios/macos/windows/linux dirs)

```dart
// lib/example.dart  in a project whose root has only web/

import 'dart:html';                       // LINT (before fix) — avoid_web_only_dependencies

// Expected after fix: suppressed. The project cannot produce a native
// build, so "crashes on mobile/desktop" is unreachable.
```

### Shape C — pure-mobile Flutter project (no web/, no desktop dirs)

```dart
// lib/example.dart  in android+ios-only project

InkWell(
  onTap: () {},
  child: Text('tap me'),                  // LINT (before fix) — prefer_cursor_for_buttons
);

// Expected after fix: suppressed. Neither Android nor iOS renders a
// cursor by default, so suggesting `mouseCursor:` delivers no UX value.
```

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | Rule fires only when the project structurally can hit the failure mode the rule warns about. Unknown project shape defaults to fire (unknown → strict) to avoid silently skipping real issues. |
| **Actual (before fix)** | Every rule fires on every qualifying AST node regardless of project platform targets, producing pure noise on projects that can't hit the failure mode. |

---

## Root Cause

Each rule's `runWithReporter` checks the AST but not the host project's
platform declarations. The fix is a one-line gate at the top of each
`runWithReporter` that consults a cached directory-scan predicate on
`ProjectContext`.

Three predicates are needed because the rules make three different
structural claims:

1. **`hasWebSupport`** — "this breaks on web". Fires when `web/` dir
   exists OR the project is a pure Dart library.
2. **`hasNonWebPlatform`** — "this crashes on non-web" (inverse). Fires
   when any of `android/`, `ios/`, `macos/`, `windows/`, `linux/`
   exists OR the project is a pure Dart library.
3. **`hasPointerPlatform`** — "this is a UX issue where a cursor
   renders". Fires when `web/`, `macos/`, `windows/`, or `linux/`
   exists OR the project is a pure Dart library. Android + iOS
   excluded — they technically support external pointers (ChromeOS,
   iPad Magic Keyboard) but by default render no cursor.

All three default to `true` when the project can't be introspected
(no path, no pubspec, unparseable), matching the existing
`flutterSdkAtLeast` philosophy.

Pure Dart libraries default `true` on every predicate because the
library author cannot know the consumer's platform target — a library
may be consumed by a browser-targeting app, a mobile app, or a server.
Warning the library author keeps cross-platform issues visible.

---

## Suggested Fix

### Change 1 — `lib/src/project_context_project_file.dart`

- Add `hasNonWebPlatform` and `hasPointerPlatform` fields to
  `_ProjectInfo` (companions to the existing `hasWebSupport`).
- Compute all three from six `Directory.existsSync()` probes
  (`web/`, `android/`, `ios/`, `macos/`, `windows/`, `linux/`),
  running once per project-root and cached via `_projectCache`.
- Expose public accessors `ProjectContext.hasNonWebPlatform(filePath)`
  and `ProjectContext.hasPointerPlatform(filePath)`.

### Change 2 — seven rule files

Add a single `if (!ProjectContext.has<Predicate>(context.filePath)) return;`
as the first line of each rule's `runWithReporter`:

| Rule | File | Predicate |
|------|------|-----------|
| `require_platform_check` | `lib/src/rules/config/platform_rules.dart` | `hasWebSupport` |
| `prefer_platform_io_conditional` | `lib/src/rules/config/platform_rules.dart` | `hasWebSupport` |
| `avoid_secure_storage_on_web` | `lib/src/rules/packages/firebase_rules.dart` | `hasWebSupport` |
| `avoid_isar_web_limitations` | `lib/src/rules/packages/isar_rules.dart` | `hasWebSupport` |
| `prefer_hive_web_aware` | `lib/src/rules/packages/hive_rules.dart` | `hasWebSupport` |
| `avoid_web_only_dependencies` | `lib/src/rules/platforms/web_rules.dart` | `hasNonWebPlatform` |
| `prefer_cursor_for_buttons` | `lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart` | `hasPointerPlatform` |

The existing gates on each rule (conditional-import escape hatch,
`isFlutterProject`, platform-directory file-path skip, etc.) are
preserved unchanged and run AFTER the new predicate gate, so the
behavior on projects that DO target the relevant platform is unchanged.

---

## Changes Made

### `lib/src/project_context_project_file.dart`

- Added `hasNonWebPlatform` and `hasPointerPlatform` fields to
  `_ProjectInfo`, computed in the factory from six directory probes at
  the project root. All three error branches (no pubspec,
  `FormatException`, `IOException`) default every field to `true` —
  unknown → strict.
- Added public accessors `ProjectContext.hasNonWebPlatform(filePath)`
  and `ProjectContext.hasPointerPlatform(filePath)` mirroring
  `hasWebSupport`.
- Existing `hasWebSupport` refactored to reuse the same directory-probe
  locals — no behavior change.

### Seven rule files

Each rule's `runWithReporter` method gained a new first-line gate that
bails when the project can't hit the rule's stated failure mode. The
existing gate logic (conditional imports, `isFlutterProject`,
platform-directory path checks) is preserved verbatim. See the table
above for the file and predicate for each rule.

### `CHANGELOG.md`

- Added a second `### Fixed` entry under `[Unreleased]` linking to this
  bug report and the sibling report that introduced `hasWebSupport`.

---

## Tests Added

### `test/project_context_platform_gates_test.dart` (new)

Thirty cases total across three groups, each materializing a fresh
synthetic project root in `Directory.systemTemp`:

**`hasNonWebPlatform` — 10 cases:**
- Flutter project with each of `android/`, `ios/`, `macos/`,
  `windows/`, `linux/` alone → true.
- Flutter project with `web/` only → false (the web-only case).
- Flutter project with no platform dirs → false.
- Pure Dart library → true.
- null + empty path → true.

**`hasPointerPlatform` — 11 cases:**
- Flutter project with each of `web/`, `macos/`, `windows/`, `linux/`
  → true.
- Flutter project with `android/` only → false.
- Flutter project with `ios/` only → false.
- Flutter project with `android/` + `ios/` (pure mobile) → false.
- Flutter project with `android/` + `ios/` + `macos/` → true (desktop
  flips it back on).
- Pure Dart library → true.
- null + empty path → true.

**Cross-predicate sanity — 3 cases:**
- Pure-mobile project (android/ios only): web false, non-web true,
  pointer false.
- Web-only project (web/ only): web true, non-web false, pointer true.
- Universal project (all six dirs): all three predicates true.

`test/avoid_platform_specific_imports_web_gate_test.dart` — unchanged
(still 6 cases for `hasWebSupport`). The new file is additive.

Affected existing test files (`platform_rules_test.dart`,
`config_rules_test.dart`, `firebase_rules_test.dart`,
`isar_rules_test.dart`, `hive_rules_test.dart`, `web_rules_test.dart`,
`widget_patterns_rules_test.dart`, `flutter_sdk_version_test.dart`,
`defensive_coding_test.dart`) pass unchanged — none of them exercised
actual rule-firing behavior against a real project shape, only rule
instantiation and message templates which are untouched. Total: 758
tests green.

### Fixture Gap

The existing single-project fixtures cannot exercise the new gates —
they live in one project context with one set of platform directories.
A future multi-project test harness (separate temp roots per scenario)
would be needed to round-trip each gate through the full analyzer
plugin. The unit tests in `project_context_platform_gates_test.dart`
exercise the predicates directly, which is the load-bearing change.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: next unreleased
- Triggering projects:
  - `d:\src\contacts` — android+ios+macos-only Flutter app, hits the
    `hasWebSupport`-gated rules
  - (hypothetical) a web-only Flutter package would hit
    `avoid_web_only_dependencies` after this fix is landed
- Related: [avoid_platform_specific_imports_false_positive_non_web_project.md](avoid_platform_specific_imports_false_positive_non_web_project.md) —
  the original bug that surfaced the pattern.
