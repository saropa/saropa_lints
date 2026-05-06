# Design Note: avoid_builder_index_out_of_bounds and parallel list initialization

**Date:** 2026-01-25
**Rule:** `avoid_builder_index_out_of_bounds`
**File:** `lib/src/rules/flutter_widget_rules.dart`
**Type:** Design Limitation (Not a Bug)

## Summary

The rule correctly flags cases where a list is accessed with `[index]` without a visible bounds check for that specific list - even when the developer knows two lists are always the same length.

## Example

```dart
class _MedicalConditionScrollerState extends State<MedicalConditionScroller> {
  late List<ScrollController> _itemScrollControllers;
  late List<MedicalConditionSeverity> severityList;

  @override
  void initState() {
    super.initState();
    severityList = MedicalConditionSeverity.values.toList();
    // BOTH LISTS HAVE SAME LENGTH
    _itemScrollControllers = List<ScrollController>.generate(
      severityList.length,  // <-- Uses severityList.length
      (_) => ScrollController(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CarouselSlider.builder(
      itemCount: severityList.length,
      itemBuilder: (context, index, realIndex) {
        if (index >= severityList.length) return emptyWidget;  // Bounds check
        final severity = severityList[index];  // OK - has bounds check

        return SingleChildScrollView(
          controller: _itemScrollControllers[index],  // FLAGGED - no explicit bounds check
        );
      },
    );
  }
}
```

## Why This Is Expected Behavior

The rule checks if EACH accessed list has a bounds check (lines 18251-18256):

```dart
for (final String listName in accessedLists) {
  if (!_hasBoundsCheckForList(bodySource, listName)) {
    reporter.atNode(node, code);
    return;
  }
}
```

The rule cannot know that `_itemScrollControllers` was initialized with `severityList.length`. This would require:
1. Cross-method data flow analysis (initState -> build)
2. Tracking variable relationships across assignments
3. Understanding that `List.generate(n, ...)` produces a list of length `n`

This is beyond the scope of a static lint rule.

## Recommendation

**Do NOT change the rule** - it's working correctly. The developer should either:

Option A: Add explicit bounds check for both lists:
```dart
if (index >= severityList.length || index >= _itemScrollControllers.length) {
  return emptyWidget;
}
```

Option B: Use ignore comment with justification:
```dart
// ignore: avoid_builder_index_out_of_bounds - _itemScrollControllers initialized with severityList.length
controller: _itemScrollControllers[index],
```

## Documentation Enhancement

Consider adding to the rule's documentation:

> **Note:** When using multiple lists of the same length in itemBuilder, ensure each
> list access has a visible bounds check, or use an ignore comment if you've ensured
> the lists are synchronized. The lint cannot detect cross-method relationships like
> `List.generate(otherList.length, ...)`.
