# PROPOSAL: Avoid Suspicious Global Reference

**Status: Open**

Created: 2026-09-02

## Summary

Flags a reference, from inside widget code (`build`, `State` methods, widget constructors), to a mutable top-level or `static` variable.

## Existing Coverage

`AvoidGlobalStateRule` (`avoid_global_state`, `lib/src/rules/architecture/structure_rules.dart:451`) already flags the *declaration* of any mutable top-level variable, anywhere in the codebase, regardless of who reads it. This proposal is narrower and complementary: it flags the *use site* specifically within widget code, which is a stronger signal of an actual UI bug (state read outside Flutter's rebuild mechanism) rather than a general architecture smell. It is a genuine, differently-scoped extension, not a duplicate — but there is significant conceptual overlap and the two rules should be documented together so users understand which one fired and why.

## Motivation

Widgets are supposed to derive their visible state from `build`'s inputs (`widget` fields, `State` fields, `InheritedWidget`/`Provider` lookups) so that Flutter's rebuild mechanism can keep the UI in sync. Reading a mutable global or static field directly from `build()` bypasses that mechanism entirely: when the global changes, nothing tells the widget to rebuild, so the UI silently goes stale until some unrelated rebuild happens to re-read it. This is a common source of "works on hot reload, breaks in release" and "UI doesn't update after login" bugs.

## Detection / Behavior

Triggers when a `build` method, other `State`/`Widget` instance method, or a widget's constructor body reads (not just declares) a non-final top-level variable or non-final `static` field.

```dart
// BAD
bool isDarkMode = false; // mutable global

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(color: isDarkMode ? Colors.black : Colors.white);
  }
}

// GOOD
class HomePage extends StatelessWidget {
  const HomePage({required this.isDarkMode, super.key});
  final bool isDarkMode; // passed in / from a listenable provider

  @override
  Widget build(BuildContext context) {
    return Container(color: isDarkMode ? Colors.black : Colors.white);
  }
}
```

## Quick Fix

None — manual refactor required. The correct fix (constructor parameter, `InheritedWidget`, state-management package) depends on the app's architecture.

## Alternatives Considered

Folding this into `avoid_global_state` as a higher-severity variant when the read site is inside widget code was considered, but keeping it a separate rule lets users opt into the widget-specific signal (which is actionable and high-confidence) independently of the broader, noisier "any mutable global exists" rule.
