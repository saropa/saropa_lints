# Duplicate Rules: avoid_redundant_async vs prefer_async_only_when_awaiting

## Status: CONFIRMED

## Problem

Two rules detect the **identical issue** — a function marked `async` that contains no `await` expressions — and produce duplicate diagnostics on the same code. When both rules are enabled, every offending function gets two lint warnings that require the same single fix.

Example output from the contacts project:

```
lib\components\system\search\app_search_filter_panel.dart:108:3
  [avoid_redundant_async] Declaring a function async without using await adds
  unnecessary Future wrapping and microtask scheduling overhead...

lib\components\system\search\app_search_filter_panel.dart:109:50
  [prefer_async_only_when_awaiting] Function is marked async but contains no
  await expressions, adding unnecessary Future wrapping overhead...
```

Both diagnostics point to the same function. Both have the same fix: remove `async` or add `await`.

## Triggering Code

Any async function without await triggers both rules:

```dart
// Both rules fire on this function
static Future<String> _buildShortcutsTooltip() async {
  final StringBuffer sb = StringBuffer();
  for (final provider in AppSearchProviderEnum.values) {
    // ... synchronous work only ...
  }
  return sb.toString();
}
```

## Rule Comparison

| Aspect | `avoid_redundant_async` | `prefer_async_only_when_awaiting` |
|---|---|---|
| **File** | `async_rules.dart:324-412` | `stylistic_control_flow_rules.dart:811-893` |
| **Impact** | `LintImpact.high` | `LintImpact.opinionated` |
| **Tier** | `professionalRules` (line 800) | `stylisticRules` (line 145) |
| **Quick Fix** | None | Yes (`_PreferAsyncOnlyWhenAwaitingFix`) |
| **Registry hook** | `addFunctionDeclaration` + `addMethodDeclaration` | `addFunctionBody` |
| **Body types** | All async bodies (excludes generators) | `BlockFunctionBody` only |
| **Await detection** | `RecursiveAstVisitor` (full AST walk) | Manual statement iteration + recursive expression check |
| **Report target** | Reports at function/method node | Reports at function body node |

### Detection Scope Differences

`avoid_redundant_async` is slightly broader:
- Handles both `FunctionDeclaration` and `MethodDeclaration` explicitly
- Works on any `FunctionBody` type (block and expression bodies)
- Explicitly excludes generator functions (`async*`) via `!body.isGenerator`

`prefer_async_only_when_awaiting` is narrower:
- Only checks `BlockFunctionBody` (misses expression-bodied async functions)
- No explicit generator exclusion (relies on `BlockFunctionBody` filter)
- Manual statement-by-statement traversal may miss await in uncommon statement types (e.g., `SwitchStatement`, `DoStatement`, `YieldStatement`)

### Await Detection Differences

`avoid_redundant_async` uses a `RecursiveAstVisitor` (`_AwaitFinder`) that walks the entire AST subtree. This is thorough and will find `await` in any nested position.

`prefer_async_only_when_awaiting` manually recurses through known statement types (`ExpressionStatement`, `ReturnStatement`, `VariableDeclarationStatement`, `IfStatement`, `Block`, `ForStatement`, `WhileStatement`, `TryStatement`). This could miss `await` inside:
- `SwitchStatement` / `SwitchExpression`
- `DoStatement`
- `ForEachStatement` (separate from `ForStatement`)
- `LabeledStatement`
- `AssertStatement`

This means `prefer_async_only_when_awaiting` could false-positive on functions that DO contain `await` inside a `switch` or `do-while`, while `avoid_redundant_async` would correctly stay silent.

## Impact

- **Developer noise**: Every async-without-await function gets two warnings instead of one
- **Inconsistent severity framing**: One rule says it's a significant issue (`high`), the other says it's an opinionated preference (`opinionated`) — for the same problem
- **False positives**: `prefer_async_only_when_awaiting` has a less thorough await search and may fire incorrectly on functions with `await` inside `switch`/`do-while` blocks

## Suggested Resolution

### Option A: Remove `prefer_async_only_when_awaiting` (recommended)

`avoid_redundant_async` has:
- Broader detection scope (expression bodies, explicit generator exclusion)
- More robust await detection (full AST visitor vs manual statement list)
- Higher impact classification matching the actual significance

The only thing it lacks is a quick fix — port `_PreferAsyncOnlyWhenAwaitingFix` to `AvoidRedundantAsyncRule` and delete the duplicate.

### Option B: Keep both but prevent overlap

If the intent is to have a `high` rule and a separate `opinionated` rule, add mutual exclusion so they never both fire on the same function. But since they detect the same problem, this seems unnecessary.

### Option C: Differentiate them

If both should exist, they need clearly different scopes. For example, one could focus on public API functions and the other on private helpers, or one could be about performance and the other about readability. Currently their problem messages are nearly identical and offer no distinct value.

## Related Files

- `lib/src/rules/async_rules.dart` (lines 324-412) — `AvoidRedundantAsyncRule`
- `lib/src/rules/stylistic_control_flow_rules.dart` (lines 811-893) — `PreferAsyncOnlyWhenAwaitingRule`
- `lib/src/rules/stylistic_control_flow_rules.dart` (lines 25-32) — `_containsAwaitExpression` helper
- `lib/src/rules/stylistic_control_flow_rules.dart` (lines 1085+) — `_PreferAsyncOnlyWhenAwaitingFix`
- `lib/src/tiers.dart` (line 145) — stylistic tier assignment
- `lib/src/tiers.dart` (line 800) — professional tier assignment
- `lib/src/tiers.dart` (line 2118) — comment noting the move to stylistic
