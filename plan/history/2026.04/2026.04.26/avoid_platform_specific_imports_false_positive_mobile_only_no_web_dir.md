> **Archive notice:** Moved from `bugs/` to `plan/history/` on 2026-04-26 when the fix landed (FINISH_GUIDE).

# `avoid_platform_specific_imports` — false positive for mobile-only Flutter project (no `web/` dir)

**Status:** Fixed (2026-04-26)
Filed: 2026-04-25
Rule: `avoid_platform_specific_imports`
Source: `lib/src/rules/config/config_rules.dart` (`AvoidPlatformSpecificImportsRule`)

---

## Attribution

```
$ grep -rn "'avoid_platform_specific_imports'" lib/src/rules/
lib/src/rules/config/config_rules.dart:640:    'avoid_platform_specific_imports',
```

Rule lives here. Confirmed.

---

## Repro

Consumer project: `d:/src/contacts` (Flutter app, Saropa contacts).

- `contacts/web/` does **not** exist.
- `contacts/android/`, `contacts/ios/` exist.
- `pubspec.yaml` declares `saropa_lints: ^12.5.1`.
- File `lib/utils/_dev/debug.dart` line 4: `import 'dart:io' as io;`

VS Code Problems panel reports:
```
[avoid_platform_specific_imports] dart:io import detected in shared code.
dart:io is unavailable on web and will cause compile failures when targeting
browser platforms. ... {v1}
```

---

## Resolution (2026-04-26)

`ProjectContext.hasWebSupport` and pubspec-based gates were evaluated in
`runWithReporter` while `SaropaContext.filePath` was still empty (`currentUnit`
not bound during `registerNodeProcessors`). That made `getProjectInfo('')`
return null and `hasWebSupport` fall through to the conservative `?? true`
default — so the mobile-only suppression never ran. The gate (and the same
pattern for sibling `hasWebSupport` rules) was moved **into** AST callbacks
where `context.filePath` is the analyzed library path. Documented on
`ProjectContext.hasWebSupport`.

---

## Why this is a false positive

`AvoidPlatformSpecificImportsRule.runWithReporter` opens with:

```dart
// The rule's entire justification is "dart:io breaks web builds". In
// a mobile-only Flutter project (no `web/` directory) that failure
// mode is structurally impossible, so every diagnostic we'd raise is
// noise.
if (!ProjectContext.hasWebSupport(context.filePath)) return;
```

`ProjectContext.hasWebSupport` is implemented in
`lib/src/project_context_project_file.dart:99` and ultimately resolves to
`hasWebDir || !isFlutter` (line 365), where `hasWebDir` is
`Directory('$projectRoot/web').existsSync()` (line 350).

For the contacts project:
- `isFlutter` should be `true` (pubspec depends on `flutter`)
- `hasWebDir` should be `false` (no `web/` directory)
- `hasWebSupport` should therefore be `false`
- The rule should `return` early and emit nothing

But the diagnostic fires. That means one of:

1. The `Directory('$projectRoot/web').existsSync()` check is returning `true`
   incorrectly (case-folding on Windows? something else under `contacts/` named
   `web` triggering the match?), OR
2. The pubspec parse falls into the `FormatException` / `IOException`
   branches (lines 389–408) — both of which default `hasWebSupport: true`.
   That's an unsafe default for the "no web dir" case, OR
3. `getProjectInfo` returns `null` and `hasWebSupport` falls through to the
   `?? true` default at line 100. Same unsafe default.

**What actually happened:** (3), because `context.filePath` was empty during
`registerNodeProcessors`, so the gate never saw the real project path until
the fix moved it into the import visitor (see **Resolution** above).

---

## Expected fix

Either:

- (A) Make the `?? true` default at `project_context_project_file.dart:100`
  context-sensitive: when the analyzed file lives under a project root that
  **has** a `pubspec.yaml` (i.e. we *can* answer the question), default to
  `false` instead of `true`. Only fall back to `true` for ambient files
  outside any project root, OR
- (B) Add diagnostic logging to the parse-failure branches so consumers can
  tell which path was hit, AND tighten path resolution on Windows so
  `Directory(...)` checks under `D:\src\contacts` correctly resolve.

Both would close the gap. (A) is the safer, smaller change.

---

## Acceptance criteria

- [x] `flutter analyze` on a Flutter project with no `web/` directory does NOT
      emit `avoid_platform_specific_imports` for `dart:io` imports.
      (Root cause: `hasWebSupport` was evaluated at `registerNodeProcessors`
      when `context.filePath` was empty → unknown default `true`; gate moved
      into the import visitor so the real path is used.)
- [x] Pure Dart libraries continue to emit (they default `hasWebSupport: true`
      because consumers may target browsers).

---

## Downstream

Tracked in `contacts/bugs/BUG_LINT_DEV_DEBUG_DART_IO_AND_STACK_TRACES.md`
and `contacts/bugs/BUG_LINT_WEB_PORTABILITY_DART_IO_SHARED_LIB.md`.
Consumers may remove temporary `// ignore_for_file:` once they depend on a
release that includes this fix.
