# PROPOSAL: Avoid Repeated Widget Creation

**Status: Open**

Created: 2026-09-02

## Summary

Flags an identical widget subtree (same constructor, same arguments) constructed more than once within a single `build` method, instead of being hoisted into a local variable or `const` field.

## Existing Coverage

No existing rule detects duplicate widget construction within one build. `PreferSplitWidgetConstRule` and `AvoidUnnecessaryContainersRule` (`lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart`) address different concerns (const-ability and needless wrapper widgets, not repeated identical subtrees). No duplicate.

## Motivation

Constructing the same widget expression twice in one `build()` (e.g. the same `Icon`/`Text`/`Divider` repeated in a ternary's both branches, or duplicated in a list literal) wastes allocation and, more importantly, indicates missed reuse: hoisting the expression to a local variable (or `static const` when all arguments are compile-time constants) improves readability, avoids rebuilding on every frame if the widget can be `const`, and gives Flutter's widget diffing a stable element to compare.

## Detection / Behavior

Triggers when two or more `InstanceCreationExpression` nodes inside the same `build`/method body construct the same widget type with textually/structurally identical argument lists.

```dart
// BAD
@override
Widget build(BuildContext context) {
  return isLoading
      ? const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())
      : Column(
          children: [
            const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
            const Text('Loaded'),
          ],
        );
}

// GOOD
@override
Widget build(BuildContext context) {
  const spinner = Padding(
    padding: EdgeInsets.all(16),
    child: CircularProgressIndicator(),
  );
  return isLoading ? spinner : Column(children: [spinner, const Text('Loaded')]);
}
```

## Quick Fix

None — manual refactor required. Hoisting to a variable/const field requires choosing a name and a scope (local vs. class-level `static const`), which is a judgment call the tool shouldn't make automatically.

## Alternatives Considered

Restricting detection to only fully `const`-eligible duplicates (to guarantee the fix is a pure win) was considered, but non-const identical subtrees still represent duplicated code worth flagging even if the fix is a plain local-variable hoist rather than a `const` hoist.
