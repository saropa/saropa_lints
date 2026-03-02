# Quick Fixes Not Appearing in VS Code (Ctrl+.)

## Status: FIXED (native-plugin-migration branch)

## Resolution

Migrated from `custom_lint_builder` (old `analyzer_plugin` protocol) to the native `analysis_server_plugin` system. The native plugin framework:
- Properly delivers quick fixes to the IDE via `PluginRegistry.registerFixForRule()`
- Provides ignore-comment fixes automatically (`IgnoreDiagnosticOnLine`, `IgnoreDiagnosticInFile`, `IgnoreDiagnosticInAnalysisOptionsFile`)

Phase 2 of migration added:
- `SaropaFixProducer` base class for native quick fixes
- `fixGenerators` getter on `SaropaLintRule` for automatic fix registration
- PoC fixes: `CommentOutDebugPrintFix`, `RemoveEmptySetStateFix`

## Original Problem

When pressing **Ctrl+.** on a saropa_lints diagnostic in VS Code, **no quick fixes appeared**. This affected all rules - both rule-specific fixes and the generic ignore fixes.

## Root Cause

The **Dart Analysis Server (DAS)** never forwarded `edit.getFixes` requests to plugins using the old `analyzer_plugin` protocol. The fix (Dart SDK commit `a9feb25`) was applied only to the new `analysis_server_plugin` system. See Dart SDK #61491, #62164, #53402.

## Related Files

- `lib/main.dart` — plugin entry point, registers rules and fixes
- `lib/src/native/saropa_fix.dart` — SaropaFixProducer base class
- `lib/src/fixes/` — quick fix implementations
- `lib/src/saropa_lint_rule.dart` — fixGenerators getter
