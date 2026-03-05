# Upgrading to saropa_lints v7

v7 upgrades to the **analyzer 10** API. It is a breaking release for dependency constraints and config key format.

## Requirements

- **Dart SDK:** 3.9 or later.
- **Analyzer:** 10.x only. If your project must stay on analyzer 9.x, use **saropa_lints 6.2.2** (the last release compatible with analyzer &lt; v10).

## Breaking changes

### 1. Dependencies

Update `pubspec.yaml`:

```yaml
dev_dependencies:
  saropa_lints: ^7.0.0
```

The package brings in `analyzer: ^10.0.0`, `analysis_server_plugin: ^0.3.10`, and `analyzer_plugin: ^0.14.0`. Resolve any version conflicts with other dev_dependencies that pin analyzer to 9.x.

### 2. Config keyed by lowerCaseName

Rule names in config and in ignore comments now use the analyzer’s **lowerCaseName** (all-lowercase identifier), not the previous mixed-case `name`.

- In **analysis_options.yaml**: severity overrides, exclude lists, and disabled rules must use the lowercased name.  
  Example: `prefer_debugprint` instead of `prefer_debugPrint`, `avoid_empty_else` (unchanged).
- In **ignore comments**: `// ignore: prefer_debugprint` (not `prefer_debugPrint`).

Search your config and code for rule names that contained uppercase letters and replace them with the lowerCaseName (e.g. run analyze and use any reported “unknown rule” or fix the name to match the new identifier).

### 3. Analyzer 10

This release is built and tested against analyzer 10.x. We do not support analyzer 9.x in v7. For analyzer &lt; v10, remain on **saropa_lints 6.2.2**.

## After upgrading

1. Run `dart pub get`.
2. Run `dart analyze` and fix any new issues (e.g. rule renames in config).
3. Update `// ignore:` comments that reference rule names to use lowerCaseName.
