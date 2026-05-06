# Bug: `avoid_expanded_outside_flex` false positive inside `List.generate()` callback in helper method

## Summary

The `avoid_expanded_outside_flex` rule incorrectly flags `Expanded` widgets returned from `List.generate()` callbacks inside helper methods. The `b180a57` fix (Jan 24, 2026) added trust for both `ReturnStatement` in non-build helper methods and `List.generate()` / `.map()` callbacks. However, the false positive persists in real-world code where `Expanded` is inside a `return` statement within a `List.generate()` callback inside a helper method.

## Severity

**High** -- ERROR-level false positive on a common Flutter pattern. The `Expanded` widgets are used as children of a `Row` at the call site, so this is not a runtime crash.

## Affected Rule

- **Rule**: `avoid_expanded_outside_flex`
- **File**: `lib/src/rules/flutter_widget_rules.dart` (lines 17860-17974)
- **Detection path**: `addInstanceCreationExpression` handler walks up the AST from `Expanded` node looking for a Flex parent or a trusted pattern

## Reproduction

### Triggering code (from `contacts` project)

File: `lib/components/chart/segmented_bar/segmented_bar.dart` (line 108)

```dart
class _SegmentedBarState extends State<SegmentedBar> {
  List<Widget>? _cachedChildren;

  List<Widget> _buildChildren() {
    if (_cachedChildren != null) return _cachedChildren!;

    final List<SegmentedBarItem> processedItems = ...;
    final num totalValue = _calculateTotalValue(processedItems);
    final int lastItemIndex = processedItems.length - 1;

    _cachedChildren = List<Widget>.generate(processedItems.length, (int index) {
      final int flexFactor = ...;

      return Expanded(           // <-- FALSE POSITIVE (line 108)
        flex: flexFactor,
        child: _SegmentedBarSegment(...),
      );
    });

    return _cachedChildren!;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _buildChildren(), // Expanded widgets end up inside Row
    );
  }
}
```

IDE error reported:
```
avoid_expanded_outside_flex [ERROR]
Line 108, columns 14-22 (highlights "Expanded")
"Expanded/Flexible outside Flex widget. This will crash at runtime."
```

### Why the lint is wrong

The `Expanded` widgets are returned from `_buildChildren()` which is called as `Row(children: _buildChildren())` at line 154. Every `Expanded` ends up as a direct child of `Row` (a Flex widget). This is safe and correct.

## Expected Behavior

The rule should trust this pattern because:
1. The `Expanded` is inside a `ReturnStatement` within a non-build helper method (`_buildChildren`)
2. The `Expanded` is inside a `List.generate()` callback
3. Both trust patterns were added in commit `b180a57`

Either trust pattern alone should suppress the diagnostic.

## Root Cause Analysis

The AST parent walk from `Expanded` (line 17907-17958) checks nodes in this order:

```
Expanded(...)  [InstanceCreationExpression]
  -> ReturnStatement           *** Trust check 1: ReturnStatement ***
    -> Block
      -> BlockFunctionBody
        -> FunctionExpression  (the (int index) { ... } callback)
          -> ArgumentList
            -> MethodInvocation  *** Trust check 2: "generate" ***
```

### Hypothesis 1: `ReturnStatement` trust fires but `thisOrAncestorOfType` fails

The `ReturnStatement` check (line 17924-17930) calls:
```dart
final method = current.thisOrAncestorOfType<MethodDeclaration>();
```

This walks up from the `ReturnStatement` through the `FunctionExpression` boundary (the callback). `FunctionExpression` is NOT a `MethodDeclaration`, so the walk continues until it reaches `_buildChildren()` (`MethodDeclaration`). Since `_buildChildren` != `build`, the trust should fire.

However, the `ReturnStatement` is inside an **anonymous function expression** (the callback), not directly inside `_buildChildren`. The `thisOrAncestorOfType<MethodDeclaration>()` call crosses function boundaries, which means it finds the OUTER method `_buildChildren` even though the `return` is actually returning from the INNER callback. This should still trust it (which is correct behavior), but there may be an analyzer version difference in how `thisOrAncestorOfType` traverses `FunctionExpression` nodes.

### Hypothesis 2: Walk doesn't reach `ReturnStatement`

The walk starts at `node.parent` (line 17907). If the immediate parent of the `InstanceCreationExpression` is NOT the `ReturnStatement` but some intermediate node (e.g., the `ArgumentList` of the `Expanded` constructor itself), the walk might check `VariableDeclaration` first (no match), then pass through `ArgumentList` and `NamedExpression` nodes before reaching the `ReturnStatement`.

The `Expanded(flex: flexFactor, child: ...)` constructor call has named arguments. The AST structure may be:
```
InstanceCreationExpression (Expanded)
  -> ConstructorName
  -> ArgumentList
    -> NamedExpression (flex: flexFactor)
    -> NamedExpression (child: _SegmentedBarSegment(...))
```

But the PARENT of `InstanceCreationExpression` is the `ReturnStatement`, not the other way around. The `ArgumentList` is a CHILD of `InstanceCreationExpression`, not its parent. So `node.parent` should be `ReturnStatement`.

### Hypothesis 3: Walk terminates at `FunctionDeclaration` boundary before reaching trusts

The walk boundary check (line 17954) stops at:
```dart
if (current is MethodDeclaration || current is FunctionDeclaration) {
  break;
}
```

This does NOT include `FunctionExpression`. But if the callback is somehow represented differently in the AST, the walk might terminate early. This is unlikely but worth verifying with a debugger.

### Hypothesis 4: Stale custom_lint cache

The `b180a57` fix was committed on Jan 24, 2026 (2 days ago). The custom_lint analysis server may be using a cached version of the plugin. Restarting the analysis server or clearing the `.dart_tool/` cache may resolve the issue. If this is the cause, no code fix is needed -- but this should be verified.

## Proposed Fix

### Fix 1: Also check `FunctionExpression` parent for `List.generate` (Defensive)

If the `ReturnStatement` trust isn't firing because of AST boundary issues, add a check that walks from the `FunctionExpression` up to its `MethodInvocation` parent:

```dart
// Trust Expanded returned from callbacks of collection builders
if (current is FunctionExpression) {
  final parent = current.parent;
  if (parent is ArgumentList) {
    final grandparent = parent.parent;
    if (grandparent is MethodInvocation) {
      final methodName = grandparent.methodName.name;
      if (methodName == 'generate' || methodName == 'map') {
        assignedToVariable = true;
        break;
      }
    }
  }
}
```

### Fix 2: Verify with debug logging

Add temporary logging to identify why neither trust pattern fires:

```dart
if (current is ReturnStatement) {
  final method = current.thisOrAncestorOfType<MethodDeclaration>();
  print('avoid_expanded_outside_flex: ReturnStatement found, '
      'method=${method?.name.lexeme}, '
      'parent=${current.parent.runtimeType}');
  if (method != null && method.name.lexeme != 'build') {
    assignedToVariable = true;
    break;
  }
}
```

## Test Cases to Add

Add to `example/lib/widgets/widget_rules_v2310_fixture.dart`:

```dart
// GOOD: Expanded inside List.generate callback in helper method
// This is a common pattern for building Row/Column children dynamically.
// The helper method is called as Row(children: _buildItems()).
class GoodExpandedInListGenerateHelper extends StatelessWidget {
  const GoodExpandedInListGenerateHelper({super.key});

  List<Widget> _buildItems() {
    return List<Widget>.generate(3, (int index) {
      return Expanded(             // Should NOT trigger
        child: Text('Item $index'),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: _buildItems());
  }
}

// GOOD: Expanded inside .map() callback assigned to field in helper
class GoodExpandedInMapHelper extends StatefulWidget {
  const GoodExpandedInMapHelper({super.key});
  @override
  State<GoodExpandedInMapHelper> createState() => _GoodExpandedInMapHelperState();
}

class _GoodExpandedInMapHelperState extends State<GoodExpandedInMapHelper> {
  List<Widget>? _cached;

  List<Widget> _buildChildren() {
    _cached ??= <String>['a', 'b', 'c'].map((String s) {
      return Expanded(             // Should NOT trigger
        child: Text(s),
      );
    }).toList();
    return _cached!;
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: _buildChildren());
  }
}
```

## Impact Assessment

- **False positive rate**: Any `Expanded`/`Flexible` inside a `List.generate()` or `.map()` callback within a helper method may be falsely flagged, despite the `b180a57` fix targeting this exact pattern
- **Workaround**: Add `// ignore: avoid_expanded_outside_flex` to the flagged line
- **Fix complexity**: Low -- likely a cache issue, or a minor defensive check to add
- **Regression risk**: None -- the fix only broadens the trusted pattern set

## Related

- Commit `b180a57` (Jan 24, 2026): "fix: avoid_expanded_outside_flex false positive in helper methods" -- intended to fix this exact pattern
- Test fixture `widget_rules_v2310_fixture.dart` lines 70-125 cover simple helper method and List.generate cases, but may not cover the combined pattern (List.generate inside a helper method with field assignment)
