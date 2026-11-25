# BUG: Package Vibrancy scan runs bare `dart pub outdated` / `dart pub deps` from PATH and rewrites pubspec.lock with the wrong SDK

**Status: Open**

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
