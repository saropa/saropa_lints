# Enable was unusable because it shelled out to the Flutter tool

Turning Lint integration on ran `flutter pub get` unconditionally on any project declaring a Flutter dependency, which took 116 seconds on a large project — indistinguishable from a hang, so it was canceled every time and the flow returned before `write_config` ever ran. The package was already resolved on disk for every one of those attempts, and the same resolve under `dart` takes 1.9 seconds.

## Measurement

Timed back to back on the same unchanged Flutter project (~60 plugins, `D:\src\contacts`), both exiting 0:

| command | elapsed |
|---|---|
| `dart pub get` | 1.9 s |
| `flutter pub get` | 116.1 s |

The 114-second difference is flutter_tool startup — SDK version check, artifact validation, and flutter_tool's own package resolution — none of which pub requires. `flutter pub get` is not a thin wrapper around `dart pub get`.

## Defect analysis

Two independent faults compounded:

1. **Wrong executable.** `hasFlutterDep(pubspec) ? 'flutter' : 'dart'` was applied at five call sites — the Enable `pub get`, three `analyze` invocations, and the upgrade checker's `pub get`. Every one paid the flutter_tool boot on Flutter projects.
2. **Unconditional work.** `ensureSaropaLintsInPubspec` returned a bare success boolean, discarding the fact that the manifest was already correct and nothing was written. The caller therefore had no basis on which to skip the resolve, and re-resolved an unchanged dependency graph on every Enable.

The progress notification did tick an elapsed counter (added in an earlier change), so the freeze was visibly "working" — but two minutes of visible work for an operation the user considers trivial still reads as broken, and cancellation was the rational response.

## Changes

- `extension/src/setup.ts`
  - `ensureSaropaLintsInPubspec` returns `{ ok, changed }` instead of a boolean, so the caller learns whether the manifest was actually written.
  - `isSaropaLintsAlreadyResolved(root)` — true when `.dart_tool/package_config.json` lists saropa_lints AND its mtime is at least that of `pubspec.yaml`. The mtime comparison is the correctness guard: an edit from any other source (upgrade checker, merge, hand-bumped constraint) leaves the manifest newer, and that case still resolves.
  - `resolvesSaropaLints(root)` — content-only sibling with deliberately no mtime component, used to verify a resolve that has just run. Pub does not rewrite `package_config.json` when the resolution is unchanged, so an mtime test there would report a good resolve as a failure.
  - `resolveDependencies(root, token, progress?)` (exported) — runs `dart pub get`, falling back to `flutter pub get` only when `shouldRetryWithFlutter` agrees. The progress parameter is optional so callers owning their own progress notification can reuse it.
  - `shouldRetryWithFlutter(root, stderr)` — requires both a declared Flutter dependency and stderr matching Flutter-SDK-resolution wording. Retrying on any non-zero exit would make an offline machine or malformed pubspec fail in 116 s instead of 2 s, which is worse than the original defect.
  - `ensureDependencyResolved` — skips the resolve when the manifest was untouched and the existing resolution covers it; owns the failure toast and the "exited 0 without resolving" check.
  - Three `analyze` call sites hardcoded to `dart`. Both executables drive the same analyzer, and no Flutter-only analyze mode exists to fall back to.
- `extension/src/upgrade-checker.ts` — `performUpgrade` now calls `resolveDependencies` rather than selecting the executable itself, closing the second instance of the same defect.
- `extension/src/test/enablePubGetSkip.test.ts` (new, 10 tests) — pins the skip decision (fresh resolve, stale resolve, absent package, missing `.dart_tool`, lookalike package name) and the retry gate (SDK failure retries, unrelated failure does not, non-Flutter project never retries, empty stderr, case-insensitivity).
- `extension/tsconfig.test.json` — registers the new test file, which is required for it to run at all.

## Verification

- `npx tsc --noEmit -p tsconfig.json` — clean.
- `tsc -p tsconfig.test.json` — clean.
- 52 passing across the affected slice (ownership, divergence prompt, tier guard, enable re-entrancy, async cancellation, analysis gate, scaffold gate, disable integration, and the new suite).
- The 1.9 s / 116.1 s figures were measured directly, not inferred.

## Not verified

No Extension Development Host run was performed. The dart-to-flutter fallback path has unit coverage of its decision function only; the fallback has never been executed end to end against a machine whose PATH resolves a standalone Dart SDK ahead of the Flutter-bundled one, which is the condition that makes it necessary.
