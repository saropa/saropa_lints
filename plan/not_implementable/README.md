# Truly not implementable

Candidates that **cannot** be implemented as saropa_lints rules. The underlying change is not about analyzing the user’s Dart/Flutter source code.

## Why they are here

- **Dart-Code (IDE)**: Settings, LSP client, widget preview, command execution, telemetry, DTD sidebar, etc. These are IDE/extension behavior; a lint package does not analyze or migrate VS Code settings or extension internals.
- **Flutter/Dart repo and tooling**: Changes to the Flutter/Dart repo itself (CI, build scripts, engine, docs, triage labels, gradle/ninja/Skia, `flutter_tools`). Not user-facing API.
- **Runtime/SDK environment**: Observatory, pub cache location, SDK version file parsing. Behavior of the runtime or tooling, not patterns in user code.

## Count

**51** numbered plan files. These are either Dart-Code (IDE/settings/LSP/preview/telemetry), Flutter/Dart repo tooling (CI, build, engine, docs), or Dart VM/runtime (Observatory, pub cache).
