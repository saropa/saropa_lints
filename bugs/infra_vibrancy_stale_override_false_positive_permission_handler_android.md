# Package Vibrancy reports a needed override as stale (permission_handler_android)

## Summary

Package Vibrancy (extension-native check) flags `permission_handler_android: 13.0.1` in `dependency_overrides` as `stale-override` ("No version conflict detected"). The override is needed. The parent package `permission_handler` declares a constraint that `13.0.1` does not satisfy, so the override resolves a real conflict.

## Attribution Evidence

- Diagnostic `source`: `Package Vibrancy`, `owner`: `saropa-vibrancy`, `code`: `stale-override`.
- Emitter: `extension/src/vibrancy/problems/problem-collector.ts:231-234` (`createStaleOverrideProblem`).
- Status decided in `extension/src/vibrancy/scoring/override-analyzer.ts:50-57` (`conflict ? 'active' : 'stale'`).
- This is an extension-native check, not a Dart AST rule. No grep in `lib/src/rules/` applies.

## Reproducer

Project: `d:\src\contacts`, `pubspec.yaml`.

- Line 501: `permission_handler: ^13.0.1`.
- Line 824: `permission_handler_android: 13.0.1` under `dependency_overrides`.
- `pubspec.lock` resolves `permission_handler` to 13.0.2 and `permission_handler_android` to 13.0.1 (`direct overridden`).
- Pub cache (`D:\tools\Pub\Cache\hosted\pub.dev`):
  - `permission_handler-13.0.1/pubspec.yaml:28`: `permission_handler_android: ^14.0.0`
  - `permission_handler-13.0.2/pubspec.yaml:28`: `permission_handler_android: ^14.1.0`

Open `pubspec.yaml` with Package Vibrancy active. The warning appears on line 824.

## Expected vs Actual

- Expected: override status `active`, blocker `permission_handler`. `13.0.1` fails `^14.1.0`, so `findConflict` (`override-analyzer.ts:84-87`) should return `permission_handler`.
- Actual: `findConflict` returns null and the override is marked `stale`.

The override is deliberate. The `pubspec.yaml:819-823` comment explains it: Android 14.x needs compileSdk 37 and changes `Permission.status`.

## Root Cause

Not confirmed. The conflict branch needs `constraints.get('permission_handler')?.get('permission_handler_android')` to be non-null. That index is built by `buildConstraintIndex` (`services/shared-dep-constraints.ts:38-55`) from the parent's pubspec in the pub cache, called at `extension-activation.ts:1559`.

### Hypothesis A: parent pubspec not found

`resolvePackagePaths` (`services/package-code-analyzer.ts`) returns no entry for `permission_handler`, or resolves a path that does not exist. The cache here is at a non-default location (`PUB_CACHE=D:\tools\Pub\Cache`). `buildConstraintIndex` then skips the package silently (`shared-dep-constraints.ts:47-48`).

### Hypothesis B: constraint not parsed

`parsePubspecYaml(...).constraints` omits `permission_handler_android`. The line follows `flutter:` blocks and platform-interface entries in that pubspec.

### Hypothesis C: parent missing from the graph

`deps.get(pkg.name)` at `override-analyzer.ts:81-82` returns undefined for `permission_handler`. The loop `continue`s before the constraint check.

## Suggested Fix

- Add a unit test with a fixture: parent constraint `^14.1.0`, override `13.0.1`, expect status `active`. This isolates the pure analyzer from the I/O layer.
- Log in `buildConstraintIndex` when a candidate has no resolved path or no parsed constraints. A silent skip hides this failure.
- Test `resolvePackagePaths` with a custom `PUB_CACHE`.

## Fixture Gap

No test covers an override whose pinned version fails the parent's declared caret range with the cache at a non-default path.

## Environment

- Windows 11, VS Code, Package Vibrancy from `saropa_lints/extension`.
- `PUB_CACHE=D:\tools\Pub\Cache`.
- Downstream project: `d:\src\contacts` (`pubspec.yaml:824`).
