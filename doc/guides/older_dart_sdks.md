# Older Dart and Flutter SDKs

The current release (`saropa_lints` 17.x) requires Dart `>=3.11.0`. Projects pinned to an older SDK
(for example via FVM) must use an older `saropa_lints` release. Older releases are **frozen**: no
back-ports, no new rules.

## Which version for which Dart SDK

The SDK column is the floor each release declares in its own `pubspec.yaml`. We have not re-tested
old releases against every SDK; if `dart pub get` rejects a version, pick the next older row.

| Your Dart SDK | Flutter (approx.) | Newest `saropa_lints` | Notes |
| --- | --- | --- | --- |
| 3.11 or newer | 3.41+ | `^17.0.0` | Current. Full feature set. |
| 3.9 – 3.10 | 3.35 – 3.38 | `^16.7.0` | Analyzer 12. Frozen. |
| 3.6 – 3.8 | 3.27 – 3.32 | `8.2.2` | Native analyzer plugin on analyzer 9. No LSP server. |
| 3.1 – 3.5 | 3.13 – 3.24 | `4.15.1` | Pre-native: uses `custom_lint`. No LSP server. |

Check your SDK with `dart --version`, or read `.dart_tool/version` in the project.

## What you lose on an older SDK

- **LSP server and the VS Code extension's live features.** `bin/lsp_server.dart` first shipped in
  15.2.10, and every release that has it needs Dart 3.9+. On older SDKs the extension skips the LSP
  server and shows a warning instead of crash-looping.
- **Newer rules, quick fixes, and false-positive fixes.** None are back-ported.
- **`4.15.1` only:** runs through `custom_lint` (`dart run custom_lint`), not `dart analyze`. Its
  config format differs from the current docs.

## Recommended path

1. Raise the SDK. Change the `.fvmrc` pin (or your Flutter channel) to one that ships Dart 3.11+,
   then use `saropa_lints: ^17.0.0`.
2. If the SDK must stay pinned, pin `saropa_lints` to the row above, run `dart pub get`, and
   `dart run saropa_lints:init`.
3. To silence the extension's LSP warning on a pinned project, turn off `saropaLints.lspServer.enabled`.

## Example: Flutter 3.32.8 (Dart 3.8.1)

```yaml
# pubspec.yaml
dev_dependencies:
  saropa_lints: 8.2.2   # newest release that declares support for Dart 3.8
```

`^17.x` will fail at `dart pub get` with a "requires SDK version >=3.11.0" error. That is the SDK
floor, not a package bug.

See also: [Troubleshooting](../troubleshooting.md), [FAQ](../faq.md).
