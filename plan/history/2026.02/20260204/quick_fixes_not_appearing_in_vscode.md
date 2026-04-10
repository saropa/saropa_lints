# Quick Fixes Not Appearing in VS Code (Ctrl+.)

## Status: ROOT CAUSE IDENTIFIED

## Problem

When pressing **Ctrl+.** on a saropa_lints diagnostic in VS Code, **no quick fixes appear**. This affects all rules - both rule-specific fixes and the generic ignore fixes (AddIgnoreCommentFix, AddIgnoreForFileFix).

Diagnostics themselves work correctly:
- Squiggly underlines appear in the editor
- Problems panel shows all lint violations
- `dart run custom_lint` CLI works fine (328 rules loaded, 1000+ issues found)

Only the quick fix suggestions are missing.

## Environment

- **Test project**: `D:\src\contacts` (Flutter app using saropa_lints as path dependency)
- **saropa_lints version**: 4.14.5
- **custom_lint / custom_lint_builder**: 0.8.1
- **analyzer**: 8.1.1 (contacts) / 8.4.0 (saropa_lints)
- **Dart SDK**: 3.10.8
- **Flutter SDK**: 3.38.9
- **IDE**: VS Code with Dart/Flutter extensions

## What Works

1. Plugin loads and runs (diagnostics appear)
2. CLI `dart run custom_lint` finds all issues
3. CLI `dart run custom_lint --fix` can apply fixes
4. Rule detection logic is correct
5. Fix registration code is correct (verified by source audit)

## What Doesn't Work

1. Ctrl+. shows no saropa_lints quick fixes
2. Light bulb icon does not appear for saropa_lints diagnostics
3. "Saropa Lints" output channel in VS Code is empty (no debug output)

## Root Cause Analysis (Feb 2026)

### Source Code Audit Results

The **entire fix pipeline inside custom_lint was audited** and found to be correct:

1. **Fix registration** (`custom_lint_builder` client.dart lines 331-342):
   ```dart
   static Map<LintCode, List<Fix>> _fixesForRules(List<LintRule> rules, ...) {
     return {
       for (final rule in rules)
         rule.code: [...rule.getFixes(), if (includeBuiltInLints) IgnoreCode()],
     };
   }
   ```
   Correctly maps each rule's `LintCode` to its fixes plus built-in ignore fixes.

2. **Fix request handling** (`custom_lint_builder` client.dart lines 601-626):
   ```dart
   Future<EditGetFixesResult> handleEditGetFixes(params) async {
     final errors = _analysisErrorsForAnalysisContexts[context.key] ?? [];
     final fixes = await _computeFixes(
       errors.where((e) => e.sourceRange.contains(params.offset)).toList(),
       context, errors,
     );
     return EditGetFixesResult(fixes...);
   }
   ```
   Uses proper range check (`contains`), not exact offset match. This code **never gets called** because the DAS never forwards the request.

3. **SaropaLintRule.getFixes()** (saropa_lint_rule.dart lines 1837-1846):
   ```dart
   List<Fix> getFixes() {
     final fixes = <Fix>[...customFixes];
     if (includeIgnoreFixes) {
       fixes.addAll([AddIgnoreCommentFix(code.name), AddIgnoreForFileFix(code.name)]);
     }
     return fixes;
   }
   ```
   Correctly combines custom fixes with ignore fixes.

### The Actual Problem: DAS Does Not Forward Fix Requests

The bottleneck is in the **Dart Analysis Server (DAS)**, not in custom_lint or saropa_lints.

**The request flow:**
1. User presses Ctrl+. in VS Code
2. VS Code sends `textDocument/codeAction` to DAS
3. **DAS decides whether to send `edit.getFixes` to the plugin** ← BREAKS HERE
4. custom_lint's `handleEditGetFixes` would process the request (but never receives it)
5. Results would flow back to VS Code

**Why the DAS doesn't forward:** Dart SDK #61491 documented a bug where the DAS only forwarded `edit.getFixes` requests to plugins when the cursor was at the **exact first byte** of a diagnostic (`error.diagnostic.offset == offset`). The fix (commit `a9feb25`, "DAS plugins: Make the fix offset a range over the diagnostic") was applied to the **new** DAS plugin system (`analysis_server_plugin`), NOT the old `analyzer_plugin` protocol that custom_lint 0.8.x uses.

### Why This Affects ALL Fixes

This is a transport-layer problem, not a fix implementation problem:
- The DAS never sends `edit.getFixes` to custom_lint for cursor positions that don't match exact diagnostic start offsets
- Even at exact start offsets, the old `analyzer_plugin` protocol path in the DAS may not forward fix requests at all
- No amount of fixing the `DartFix` implementations will help because they never execute

### The Legacy Protocol Deprecation

The old `analyzer_plugin` protocol is being deprecated (Dart SDK #62164):
- **Phase 1** (Dart 3.12+): Report legacy plugin usage as deprecated
- **Phase 2** (subsequent release): Disable legacy plugins entirely
- custom_lint acknowledged as "the primary client" of the old system

The new `analysis_server_plugin` system (SDK #53402, closed Nov 2025) properly supports quick fixes.

## Known Upstream Issues

| Issue | Status | Impact |
|-------|--------|--------|
| [Dart SDK #61491](https://github.com/dart-lang/sdk/issues/61491) | CLOSED (fixed for new plugins only) | DAS only forwards fixes at exact first byte of diagnostic |
| [Dart SDK #62164](https://github.com/dart-lang/sdk/issues/62164) | OPEN | Old analyzer_plugin protocol being deprecated |
| [Dart SDK #53402](https://github.com/dart-lang/sdk/issues/53402) | CLOSED | New plugin system shipped with proper fix support |
| [custom_lint #251](https://github.com/invertase/dart_custom_lint/issues/251) | OPEN | `source.fixAll` doesn't work (analyzer_plugin limitation) |
| [flutter-intellij #7600](https://github.com/flutter/flutter-intellij/issues/7600) | OPEN | custom_lint IDE quick actions not shown |

## Workarounds

### 1. CLI `--fix` (available now)
```bash
cd D:\src\contacts && dart run custom_lint --fix
```
Applies all available batch fixes from the command line. Verified working.

### 2. Manual ignore comments
Add `// ignore: rule_name` or `// ignore_for_file: rule_name` manually since the ignore quick fixes can't be delivered through the IDE.

## Resolution Path

### Option A: Wait for custom_lint migration (recommended)
custom_lint needs to migrate from the old `analyzer_plugin` protocol to the new `analysis_server_plugin` API. This would:
- Fix the quick fix delivery issue
- Fix the `source.fixAll` issue (#251)
- Avoid the upcoming deprecation of the old protocol

**Action**: File or find an issue on [invertase/dart_custom_lint](https://github.com/invertase/dart_custom_lint) tracking migration to `analysis_server_plugin`.

### Option B: Test cursor position (diagnostic only)
Place cursor at the **exact first character** of a diagnostic squiggle and press Ctrl+. If fixes appear there but nowhere else, it confirms the DAS offset bug affects the old protocol.

### Option C: Enable verbose logging (diagnostic only)
Add to test project `analysis_options.yaml`:
```yaml
custom_lint:
  verbose: true
```
Restart analysis server and check `custom_lint.log` for `edit.getFixes` request entries.

## Investigation History

1. **Plugin crash** (Jan 2026, RESOLVED): Duplicate class declarations in `flutter_widget_rules.dart` caused plugin startup failure. Fixed.
2. **Fix implementation audit** (Feb 2026): Full source audit of custom_lint_builder 0.8.1 `client.dart` confirmed fix registration, error matching, and fix execution code is correct.
3. **DAS analysis** (Feb 2026): Traced the request pipeline from VS Code through the DAS to the plugin. Identified the DAS as the bottleneck - it never forwards `edit.getFixes` to old-protocol plugins.

## Related Files

- `custom_lint_builder` 0.8.1 `lib/src/client.dart` - handleEditGetFixes (line 601), _fixesForRules (line 331)
- `custom_lint` 0.8.1 `lib/src/v2/custom_lint_analyzer_plugin.dart` - request forwarding (line 186)
- `custom_lint` 0.8.1 `lib/src/analyzer_plugin_starter.dart` - plugin start (fix: false for IDE)
- `lib/src/saropa_lint_rule.dart` (lines 1837-1846) - getFixes() base implementation
- `lib/src/ignore_fixes.dart` - AddIgnoreCommentFix, AddIgnoreForFileFix, WrapInTryCatchFix
