# Quick Fixes Not Appearing in VS Code (Ctrl+.)

## Status: INVESTIGATING

## Problem

When pressing **Ctrl+.** on a saropa_lints diagnostic in VS Code, **no quick fixes appear**. This affects all rules - both rule-specific fixes and the generic ignore fixes (AddIgnoreCommentFix, AddIgnoreForFileFix).

Diagnostics themselves work correctly:
- Squiggly underlines appear in the editor
- Problems panel shows all lint violations
- `dart run custom_lint` CLI works fine (312 rules loaded, 1000+ issues found)

Only the quick fix suggestions are missing.

## Environment

- **Test project**: `D:\src\contacts` (Flutter app using saropa_lints as path dependency)
- **saropa_lints version**: 4.9.18 (project is at 4.9.21)
- **custom_lint / custom_lint_builder**: 0.8.1
- **analyzer**: 8.1.1 (contacts) / 8.4.0 (saropa_lints)
- **Dart SDK**: 3.10.8
- **Flutter SDK**: 3.38.9
- **IDE**: VS Code with Dart/Flutter extensions

## What Works

1. Plugin loads and runs (diagnostics appear)
2. CLI `dart run custom_lint` finds all issues
3. Rule detection logic is correct

## What Doesn't Work

1. Ctrl+. shows no saropa_lints quick fixes
2. Light bulb icon does not appear for saropa_lints diagnostics
3. "Saropa Lints" output channel in VS Code is empty (no debug output)

## Investigation So Far

### 1. Plugin crash (RESOLVED - not current cause)
`example/custom_lint.log` from Jan 7, 2026 showed duplicate class declarations in `flutter_widget_rules.dart` causing "Failed to start plugins" crash. This has been fixed - CLI works fine now.

### 2. Known upstream issues

- **Dart SDK #61491**: Analyzer plugin fixes only respond at exact first character position of the diagnostic range. Fixed in Sept 2025 for the NEW Dart analyzer plugin system. **Unclear if fix applies to the OLD `analyzer_plugin` protocol** that custom_lint uses.
  - Link: https://github.com/dart-lang/sdk/issues/61491

- **custom_lint #251**: `source.fixAll` doesn't work with custom_lint (architectural limitation of analyzer_plugin protocol).
  - Link: https://github.com/invertase/dart_custom_lint/issues/251

- **flutter-intellij #7600**: custom_lint IDE Quick actions not shown.
  - Link: https://github.com/flutter/flutter-intellij/issues/7600

### 3. Fix implementation patterns

Two patterns exist in the codebase:

**Pattern A - Ignore fixes (no registry):**
```dart
// AddIgnoreCommentFix and AddIgnoreForFileFix
// Create ChangeBuilder directly without using context.registry
changeBuilder.addDartFileEdit((builder) {
  builder.addSimpleInsertion(offset, '// ignore: $ruleName\n');
});
```

**Pattern B - Rule-specific fixes (uses registry):**
```dart
// WrapInTryCatchFix and most rule-specific fixes
// Register via context.registry, then check sourceRange intersection
context.registry.addMethodInvocation((node) {
  if (!analysisError.sourceRange.intersects(node.sourceRange)) return;
  // ... create fix
});
```

Both patterns should work according to custom_lint_builder documentation.

### 4. VS Code output channels

- "Dart Analysis Server" does NOT exist as an output option
- Available: "flutter package saropa", "flutter daemon", "Saropa Lints"
- "Saropa Lints" channel is empty

## Leading Theories

1. **Old analyzer_plugin protocol limitation**: custom_lint 0.8.x uses the old `analyzer_plugin` protocol. The Dart SDK fix for #61491 (cursor position sensitivity) was only applied to the NEW plugin system. The old protocol may have a fundamental issue transmitting fixes to VS Code.

2. **Version mismatch**: The contacts project has analyzer 8.1.1 while saropa_lints builds against 8.4.0. Possible protocol incompatibility.

3. **Fix registration timing**: The way fixes are registered via `context.registry` callbacks may not align with when VS Code requests code actions.

## Next Steps (Waiting On)

### Step 1: Enable verbose logging
Add to contacts project `analysis_options.yaml`:
```yaml
custom_lint:
  verbose: true
```
Then restart analysis server (`Dart: Restart Analysis Server` in command palette) and check "Saropa Lints" output channel for debug information about fix registration and requests.

### Step 2: Test cursor position
Place cursor at the **exact first character** of a diagnostic squiggle and press Ctrl+., then test at other positions within the squiggle. This tests whether Dart SDK #61491 still affects the old plugin protocol.

### Step 3: Check custom_lint version compatibility
Compare custom_lint versions between saropa_lints (0.8.0 constraint) and contacts project (0.8.1 resolved). Check if there are newer versions with fix-related changes.

### Step 4: Test with a minimal rule
Create a minimal test with a single rule and single fix to isolate whether the issue is with specific fix implementations or the entire fix pipeline.

## Related Files

- `lib/src/saropa_lint_rule.dart` (lines 1560-1617) - getFixes() base implementation
- `lib/src/ignore_fixes.dart` - AddIgnoreCommentFix, AddIgnoreForFileFix, WrapInTryCatchFix
- `lib/custom_lint_client.dart` - Plugin entry point
- `example/analysis_options.yaml` - Example project configuration
