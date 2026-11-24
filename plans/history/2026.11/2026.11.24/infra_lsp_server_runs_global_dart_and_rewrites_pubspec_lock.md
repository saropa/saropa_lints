# LSP server spawns bare `dart` and rewrites pubspec.lock / package_config.json with the wrong SDK

## Summary

`extension/src/debug/saropaLspClient.ts` (lines 135-146) starts the language server as
`command: 'dart', args: ['run', 'saropa_lints:lsp_server']`. `dart` is resolved from the extension
host's PATH, not from the SDK the project is pinned to. In a project pinned with FVM, the PATH `dart`
is a different (newer) SDK than the pinned one. `dart run` performs an implicit `pub get` when its
package_config was written by another SDK, so every time the server starts (or restarts) it
re-resolves the project with the wrong SDK.

## Observed (jupiter-tablet, 2026-11-23)

- Project pinned to Flutter 3.32.8 (Dart 3.8) in `.fvmrc` for Android 5.1 support; VS Code setting
  `dart.flutterSdkPath` = `.fvm/flutter_sdk`.
- Global SDK on PATH: `D:\tools\flutter` (Dart 3.13).
- Running process: `D:\tools\flutter\bin\cache\dart-sdk\bin\dart.exe run saropa_lints:lsp_server`
  (cwd = the project), with a second `dartvm.exe --packages=.dart_tool\package_config...` child.
- Result, repeatedly within minutes of a correct pinned `flutter pub get`:
  - `pubspec.lock` `sdks.dart` becomes `">=3.13.0-0 <4.0.0"` and about 13 packages change version.
  - `.dart_tool/package_config.json` points at `file:///D:/tools/flutter` and pub-cache versions that
    need Dart 3.9+.
  - The next pinned build fails with "The language version 3.13 specified for the package 'flutter'
    is too high. The highest supported language version is 3.8" (about 2,200 errors).
- `lspResolution.ts` / `isSaropaLintsResolved` only checks that saropa_lints is in package_config; it
  does not check which SDK wrote it.

## Expected

The server runs with the same SDK the Dart-Code extension uses for the workspace
(`dart.flutterSdkPath` / `dart.sdkPath`, FVM `.fvm/flutter_sdk`), and never changes
`pubspec.lock` or `.dart_tool/package_config.json`.

## Suggested fix

1. Resolve the dart executable from `dart.sdkPath`, then `dart.flutterSdkPath/bin/cache/dart-sdk/bin`,
   then `<root>/.fvm/flutter_sdk`, and only then PATH.
2. Prefer launching the compiled/AOT server directly (`dart <path-to>/bin/lsp_server.dart` using
   `--packages=<project>/.dart_tool/package_config.json`) so no implicit `pub get` can happen; or
   pass `--no-pub` equivalents.
3. If the package_config generator SDK differs from the chosen SDK, show one warning instead of
   letting `dart run` re-resolve.

## Workaround for users

Put the pinned SDK's `bin` first on the PATH that VS Code is started with, or stop the saropa_lints
server for FVM-pinned projects, then restore with the pinned `flutter pub get`.

## Environment

Windows 11, VS Code extension host, saropa_lints extension (workspace setting `saropaLints.enabled`),
FVM 3.32.8 pinned, global Flutter on PATH newer than the pin.
