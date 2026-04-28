# saropa_lints_api

Thin wrapper around [`saropa_lints`](https://pub.dev/packages/saropa_lints) for **composite analyzer plugins**: depend on this package to get a small, documented export list (`registerSaropaLintRules`, config loaders, `SaropaLintRule`) while pinning a compatible `saropa_lints` version via normal pub constraints.

In this monorepo the dependency is a `path:` to the parent package. On pub.dev, published versions of `saropa_lints_api` would use a hosted `saropa_lints` constraint instead.

See the main repo guide: `doc/guides/composite_analyzer_plugin.md`.

Use `dart run saropa_lints:init --emit-composite-plugin-scaffold` to generate a starter plugin that calls Saropa’s registrars directly, or switch the generated `pubspec.yaml` to depend on `saropa_lints_api` and import `package:saropa_lints_api/saropa_lints_api.dart` if you prefer the facade.
