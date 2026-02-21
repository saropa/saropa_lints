# Dart SDK 3.6.1

## 3.6.1

**Released on:** 2025-01-08

- When inside a pub workspace, `pub get` will now delete stray
  `.dart_tool/package_config.json` files in directories between the
  workspace root and workspace directories. Preventing confusing behavior
  when migrating a repository to pub workspaces (issue [pub#4445][]).
- Fixes crash during AOT and dart2wasm compilation which was caused by
  the incorrect generic covariant field in a constant object (issue
  [#57084][]).
- Fixes analysis options discovery in the presence of workspaces
  (issue [#56552][]).

[pub#4445]: https://github.com/dart-lang/pub/issues/4445
[#57084]: https://github.com/dart-lang/sdk/issues/57084
[#56552]: https://github.com/dart-lang/sdk/issues/56552
