# BUG: Package Vibrancy scan runs bare `dart pub outdated` / `dart pub deps` from PATH and rewrites pubspec.lock with the wrong SDK

**Status: Fixed**

Created: 2026-11-24
Component: extension-native (`extension/src/vibrancy/`)
Severity: Data corruption (project lockfile rewritten) / Performance
Extension version observed: 17.7.9 (source checked at 17.8.9)

---

## Summary

On window open, the Package Vibrancy scan runs `dart pub outdated --json --transitive` and
`dart pub deps --json` using whatever `dart` is first on the extension host's PATH. In a project
pinned to an older SDK (FVM), that is a different, newer SDK. Both commands re-resolve the project
and rewrite `pubspec.lock` and `.dart_tool/package_config.json` against the wrong SDK. That breaks
the pinned build and makes Dart-Code show "packages are missing or out of sync" on every open.

`saropaLints.enabled: false` does not stop it. The scan runs even with the extension disabled for
the workspace.

This is the same defect class as the closed
`plans/history/2026.11/2026.11.24/infra_lsp_server_runs_global_dart_and_rewrites_pubspec_lock.md`,
but at a different call site. That fix covered only the LSP server launcher (`saropaLspClient.ts`).
The Vibrancy CLI wrapper still spawns bare `dart` / `flutter`.

---

## Attribution Evidence

Extension-native, not a Dart AST rule.

```bash
grep -nE "'outdated'|'deps'" extension/src/vibrancy/services/flutter-cli.ts
# 85:        ['pub', 'outdated', '--json', '--transitive'], cwd, 120_000,
# 91:    return runDartCommand(['pub', 'deps', '--json'], cwd, 60_000);
# runDartCommand -> execFile('dart', args, ...)   (bare name, resolved from PATH)
# runFlutterCommand -> execFile('flutter', args, ...)

grep -n "scanOnOpen" extension/src/vibrancy/extension-activation.ts
# 923:    if (!config.get<boolean>('scanOnOpen', true)) { return; }
# No check of saropaLints.enabled on this path.
```

---

## Observed (jupiter-tablet, 2026-11-24)

- Project pinned to Flutter 3.32.8 / Dart 3.8 (`.fvmrc`) for Android 5.1 devices.
- Workspace settings: `dart.flutterSdkPath` and `dart.sdkPath` both point at the pinned SDK;
  `saropaLints.enabled: false`. Dart-Code's analysis server correctly runs on the pinned SDK.
- Global SDK on PATH: `D:\tools\flutter` (Flutter 3.50.0, Dart 3.14).
- Process trace on window reload (parent chain = the VS Code extension host):
  ```
  21:27:53.893 cmd.exe /d /s /c "dart pub outdated --json --transitive"
  21:27:54.408 cmd.exe /d /s /c "dart pub deps --json"
  21:27:54.760 pubspec.lock WRITTEN
  21:27:55.675 cmd.exe /d /s /c "flutter --version --machine"  -> D:\tools\flutter\...
  ```
- Result: `pubspec.lock` `sdks.dart` goes from `">=3.8.0 <4.0.0"` to `">=3.13.0-0 <4.0.0"` and
  13 packages change version (e.g. `leak_tracker` 10.0.9 -> 11.0.2). `package_config.json`
  `flutterRoot` becomes `file:///D:/tools/flutter`. Analyzer then reports 3.50-only errors
  (`fontFamilyFallback` undefined, `RegExp` deprecated, `material.dart` deprecated), and Dart-Code
  prompts "packages are missing or out of sync" on every open.
- Workaround that stopped it: `saropaLints.packageVibrancy.scanOnOpen: false` and
  `saropaLints.packageVibrancy.watchEnabled: false`.

---

## Update: the settings workaround does not hold. The lock watcher creates a feedback loop.

`scanOnOpen: false` + `watchEnabled: false` did NOT stop it. After a window reload with both set,
the trace caught the same sequence again:

```
21:36:1x  pinned `flutter pub get` restores pubspec.lock (Dart 3.8 resolution)
21:36:50.863 cmd.exe /d /s /c "dart pub outdated --json --transitive"   (ext host of the jupiter window)
21:36:51.634 cmd.exe /d /s /c "dart pub deps --json"
21:36:51.634 pubspec.lock WRITTEN  (back to Dart 3.13 resolution)
```

Cause: `registerFileWatcher` (`extension/src/vibrancy/extension-activation.ts:349`) watches
`**/pubspec.lock` and calls `runScan(targets)` 30 s after any change (line ~378). It is registered
unconditionally in activation (line 342) and checks no setting: not `saropaLints.enabled`, not
`scanOnOpen`, not `watchEnabled` (that one only gates `freshness-watcher.ts`).

Result: every correct pinned `pub get` changes the lock, which triggers a scan 30 s later, and the
scan's bare `dart pub outdated` / `pub deps` rewrites the lock with the global SDK. The user can't
recover except by disabling the extension for the workspace. The "byte-identical lock" skip
(`pubspecLockUnchangedSinceLastScan`) doesn't help, because the pinned and global resolutions differ.

Additional fix required: gate `registerFileWatcher` (and the scan it triggers) on
`saropaLints.enabled` and on a Vibrancy watch setting. A scan triggered by the lock watcher must
never itself write the lock (see "Suggested fix" 2).

## Expected

1. Vibrancy never mutates `pubspec.lock` or `.dart_tool/`. It is a read-only health scan.
2. It uses the workspace's SDK, not PATH.
3. `saropaLints.enabled: false` disables every background process the extension starts for that
   workspace, Vibrancy included.

## Suggested fix

1. `flutter-cli.ts`: resolve the executables with the same resolver the LSP fix introduced
   (`dart.sdkPath` -> `dart.flutterSdkPath/bin/cache/dart-sdk/bin` -> `<root>/.fvm/flutter_sdk` ->
   PATH), for both `runDartCommand` and `runFlutterCommand`. One shared resolver, not a second copy.
2. Make the scan non-mutating: `dart pub outdated` / `pub deps` must not run when
   `package_config.json` was generated by a different SDK than the resolved one. Skip with one
   status-bar note instead of letting pub re-resolve.
3. Gate Vibrancy's startup scan and freshness watcher (`freshness-watcher.ts:131`) on
   `saropaLints.enabled`.

## Environment

Windows 11, VS Code, saropa.saropa-lints 17.7.9, Dart-Code 3.146.0, FVM 3.32.8 pinned, global
Flutter 3.50.0 on PATH.

## Reporter

jupiter-tablet

## Finish Report (2026-11-24)

### Root cause

`extension/src/vibrancy/services/flutter-cli.ts` spawned bare `dart` and `flutter` from PATH. In an FVM-pinned project the newer global SDK re-resolved the project and rewrote `pubspec.lock` and `.dart_tool/package_config.json`. The `pubspec.lock` watcher then re-triggered scans, forming a loop, and the startup scan ignored `saropaLints.enabled`.

Correction to the report: `freshness-watcher.ts` only polls pub.dev and never runs `dart pub`. It is gated on `enabled` anyway, as the master switch.

### Fix

- New `extension/src/vibrancy/services/sdk-toolchain.ts`. SDK resolution reuses `resolveDartExecutable` and the new `resolveFlutterExecutable` in `extension/src/debug/lspResolution.ts`. Order: `dart.sdkPath`, `dart.flutterSdkPath`, `.fvm/flutter_sdk` (walking up to the workspace folder), then PATH. Configuration is folder-scoped.
- Guard before `pub outdated` / `pub deps`. The query is skipped when:
  - `.dart_tool/version` differs from the tool SDK version;
  - `.dart_tool/version` is missing and the tool version fails the `pubspec.lock` `sdks: dart:` constraint;
  - the tool version is unknown (bare PATH);
  - `pubspec.yaml` is newer than `pubspec.lock`, or the lock is missing;
  - `package_config.json` is missing or older than the lock.
- The `dart --version` probe has in-flight dedupe and a 5-minute TTL; failures are not cached.
- A skip shows one de-duplicated 15-second status-bar note via `l10n`. New `en.json` keys under `pubGuard`: `skipped`, `sdkMismatch`, `lockSdkConstraint`, `unknownPathSdk`, `staleLock`, `staleConfig`.
- `extension/src/vibrancy/extension-activation.ts`: `isExtensionEnabled()` gates `autoScanIfPubspec` and the `pubspec.lock` watcher callback (re-read per event and again when the debounce fires).
- `extension/src/vibrancy/services/freshness-watcher.ts` gated on `enabled`.

### Verification

Both `tsc` runs exit 0. Scoped mocha: 75 passing, 0 failing (24 in sdk-toolchain, including an end-to-end `runDartPubOutdated` skip with a fake FVM SDK). Not run in an Extension Development Host: unverified.

### Open items

- F5 checklist:
  - FVM-pinned project: `pubspec.lock` unchanged after scan.
  - Monorepo root `.fvm`.
  - Multi-root workspace with per-folder `dart.sdkPath`.
  - `saropaLints.enabled: false`, including a runtime toggle and touching `pubspec.lock`.
  - Stale `pubspec.yaml` or deleted `package_config.json`: one note only.
  - Edited `.dart_tool/version`: note names both versions.
  - Healthy unpinned project still scans.
  - Upgrade command uses the FVM `flutter`.
  - Read the note wording.
- No test covers the lock-watcher `enabled` gate: `registerFileWatcher` is not exported and the mock watcher does not fire.
- Translated locale catalogs not regenerated for the six new `pubGuard` keys. The publish coverage gate fails until they are regenerated.
- `sdk-pins.ts:72` and `sdk-detector.ts:29,40` still call bare `flutter` / `dart`. They report the wrong SDK but do not mutate the lock. Out of scope.

### Hardening and explain command (2026-11-24)

- Freshness check aligned to pub's `Entrypoint.isResolutionUpToDate` (dart-lang/pub, `lib/src/entrypoint.dart`) instead of a raw mtime rule:
  - missing `pubspec.lock` or `.dart_tool/package_config.json` → skip (pub resolves unconditionally);
  - lock strictly newer than `pubspec.yaml` / `pubspec_overrides.yaml` and config not older than lock → allowed (pub's fast path);
  - otherwise content is checked and, if consistent, the query is allowed (git-checkout skew: pub only touches mtimes). yaml newer → every declared dependency must be in the lock; config older → every locked package must be in `package_config.json`.
  - Known gap: version-range edits are not re-solved, so a changed constraint with unchanged names is not detected.
- `sdks: dart:` parser is table-tested (`>=3.8.0 <4.0.0`, `>=2.17.0-0 <4.0.0`, `^3.5.0`, `>=3.0.0`, `any`, malformed). Malformed or missing constraint = unknown; a bare PATH SDK is skipped, a configured/FVM SDK is allowed.
- `dart --version` probe cache is cleared when `dart.sdkPath` / `dart.flutterSdkPath` change and when `.fvmrc`, `.fvm/fvm_config.json` or `.fvm/flutter_sdk` change (watchers registered in `extension-activation.ts`, disposed with the extension context).
- Lock-watcher gate extracted to `decideLockWatcherAction` (`services/scan-gate.ts`) and unit-tested for all branches.
- New command `saropaLints.packageVibrancy.explainLastSkip` ("Explain Last Vibrancy Skip"). Every guard outcome is recorded (`services/pub-guard-record.ts`): selected SDK path and source, project version and its source, tool version, rule key, time, folder. A skip shows a persistent status-bar item that runs the command; the command opens a modal with the details and a "Run pub get with project SDK" action (`runPubGet` through the resolved Flutter), or an "nothing skipped" message. The item clears on the next allowed outcome or when clicked.
- Replaced the transient 15-second status-bar message and its `pubGuard.skipped` key with the persistent item. New keys under `pubGuard`: `depsNotLocked`, `source.*`, `projectSource.*`, `statusItem.*`, `explain.*`; `package.nls.json`: `command.packageVibrancy.explainLastSkip.title`. Other locale catalogs are not regenerated.
- Still unverified: not run in an Extension Development Host.

#### Re-review fixes (2026-11-24)

- Freshness check now also covers what pub's `isLockFileUpToDate` does: when `pubspec.yaml` is newer than the lock, every declared dependency (`dependencies`, `dev_dependencies`, `dependency_overrides`, `pubspec_overrides.yaml`) must be locked AND its locked version must satisfy the declared constraint (`^1.0.0` → `^2.0.0` is now caught). Git, inline-map and unparseable forms are treated as unverifiable and skip. A path dependency whose `pubspec.yaml` is newer than the lock skips. New parser: `services/pub-dep-specs.ts`; constraints use `semver` with `includePrerelease`, plus a rewrite so `<X.Y.Z` excludes `X.Y.Z-dev` like pub.
- `resolution: workspace` members: `findLockRoot` walks up (bounded by the VS Code workspace folder) to the first `pubspec.lock`; lock, `package_config.json` and `.dart_tool/version` are read there, and both the member's and the root's pubspecs are checked.
- "Run pub get with project SDK" picks `dart pub get` for projects without an `sdk: flutter` dependency and the resolved Flutter otherwise (`planPubGet`). A PATH-resolved SDK needs a second modal confirmation.
- Skips are kept per folder; an allowed pass clears only its own folder; the status-bar item hides only when no folder has a skip; the command shows a QuickPick when several folders were skipped.
- Caret on 0.x and prerelease ordering follow pub (`^0.0.3` → `<0.0.4`, `^0.2.1` → `<0.3.0`, `3.8.0-dev` does not satisfy `>=3.8.0`).
- Accepted limitation: an FVM symlink retargeted without a watched file changing is picked up when the 5-minute probe TTL expires. `.fvm/flutter_sdk/version` is now also watched.
- Explain modal "Rule:" line shows a localized rule name instead of the raw key. `guardPubCommand` takes an options object. `decideLockWatcherAction` has its own test file. The double `decideLockWatcherAction` call in the watcher is intentional: the first call exits before the lockfile hash is read when the extension is disabled; the second applies the unchanged-lock skip.
- Still unverified: not run in an Extension Development Host. New en.json keys are not translated.
