# `prefer_keep_alive` false positive: naive `contains('Tab')` matches unrelated string references

## Status: RESOLVED

## Summary

The `prefer_keep_alive` rule (v5) fires on `_HomepageSectionsDialogState`, a **dialog** widget shown via `showDialogCommon()` that never lives inside a `TabBarView` or `PageView`. The rule falsely identifies it as "tab content" because `classSource.contains('Tab')` matches `HomeTab.icon` — a static constant reference used for the dialog's header icon, completely unrelated to tab context.

Additionally, the diagnostic persists despite the class already having `AutomaticKeepAliveClientMixin` applied (with `wantKeepAlive => true` and `super.build(context)` call), which the rule's own mixin check (lines 3112–3120) should have caught and returned early.

## Diagnostic Output

```
resource: /D:/src/contacts/lib/components/main_layout/search/tab_context_menu.dart
owner:    _generated_diagnostic_collection_name_#2
code:     prefer_keep_alive
severity: 2 (info)
message:  [prefer_keep_alive] Use AutomaticKeepAliveClientMixin to preserve state.
          Without AutomaticKeepAliveClientMixin, tab content is rebuilt when switching
          tabs, losing scroll position and state. {v5}
          Add "with AutomaticKeepAliveClientMixin" to preserve state in tabs. Test on
          multiple screen sizes to verify the layout adapts correctly.
lines:    465:7–465:35 (_HomepageSectionsDialogState class name)
```

## Affected Source

File: `lib/components/main_layout/search/tab_context_menu.dart` lines 458–590

```dart
class _HomepageSectionsDialog extends StatefulWidget {
  const _HomepageSectionsDialog();

  @override
  State<_HomepageSectionsDialog> createState() => _HomepageSectionsDialogState();
}

class _HomepageSectionsDialogState extends State<_HomepageSectionsDialog>
    with AutomaticKeepAliveClientMixin {  // ← mixin ALREADY applied
  @override
  bool get wantKeepAlive => true;        // ← required override present

  @override
  Widget build(BuildContext context) {
    super.build(context);                // ← required super call present
    // ... builds a Column with CommonHeaderBar and ListView.builder
    // Line 507: iconCommon: HomeTab.icon,  ← triggers "Tab" string match
  }
}
```

The widget is shown as a dialog, not as tab content:

```dart
Future<void> _showHomepageOptionsDialog(BuildContext context) async =>
    await showDialogCommon(
      options: const CommonDialogOptions(dialogSize: DialogSize.Large),
      child: const _HomepageSectionsDialog(),  // ← dialog, not tab child
    );
```

## Root Cause

The rule at `widget_layout_rules.dart` lines 3100–3133 has two bugs:

### Bug 1: Naive string matching for tab context (primary)

```dart
// Line 3123–3131
final String classSource = node.toSource();
if (classSource.contains('ListView') ||
    classSource.contains('GridView') ||
    classSource.contains('CustomScrollView')) {
  // Check if inside a tab-like context (has TabBar reference)
  if (classSource.contains('Tab') || classSource.contains('Page')) {
    reporter.atToken(node.name, code);
  }
}
```

`classSource.contains('Tab')` matches ANY occurrence of the substring "Tab" anywhere in the class source. In this case, it matches `HomeTab.icon` at line 507, which is a static constant reference for the dialog header's icon. This has zero relationship to the widget being inside a `TabBarView`.

Common false-positive triggers for this string check:

| Source text | Why it matches | Relation to tab context |
|---|---|---|
| `HomeTab.icon` | Contains "Tab" | None — static icon reference |
| `AppTabEnum.HomeTab` | Contains "Tab" | None — enum value reference |
| `TabContextMenu` | Contains "Tab" | None — references a sibling widget |
| `'Homepage Sections'` | Would match "Page" | None — UI display text |
| `DataTable(...)` | Contains "Tab" | None — table widget |
| `Navigator.of(context).pushPage(...)` | Contains "Page" | None — navigation call |

### Bug 2: Diagnostic persists despite mixin already applied (secondary)

The mixin check at lines 3112–3120 correctly looks for `AutomaticKeepAliveClientMixin`:

```dart
final WithClause? withClause = node.withClause;
if (withClause != null) {
  for (final NamedType mixin in withClause.mixinTypes) {
    if (mixin.name.lexeme == 'AutomaticKeepAliveClientMixin') {
      return; // Already has the mixin
    }
  }
}
```

This check is correct in isolation. The fact that the diagnostic still shows suggests either:
- The analysis server cached results from before the mixin was added
- There is a race condition between file modification and re-analysis

This secondary bug may be an analysis caching issue rather than a rule logic bug, but the primary bug (naive string matching) is the root cause of the false positive.

## Why This Is a False Positive

1. **Widget is a dialog, not tab content.** `_HomepageSectionsDialog` is shown via `showDialogCommon()`. It never exists as a child of `TabBarView` or `PageView`. `AutomaticKeepAliveClientMixin` has no effect in this context because there is no `AutomaticKeepAlive` ancestor widget.

2. **"Tab" match is from an unrelated constant reference.** `HomeTab.icon` is a static icon constant used in `CommonHeaderBar`. The class name `HomeTab` happens to contain the substring "Tab" but has nothing to do with tab navigation context.

3. **The mixin is already applied.** Even if the rule's context detection were correct, the class already satisfies the rule's requirements — the diagnostic should not appear.

## Scope of Impact

Any `State` class that:
- Contains a `ListView`, `GridView`, or `CustomScrollView`
- AND references any identifier containing "Tab" or "Page" (extremely common in Flutter)

will trigger this rule, regardless of whether the widget actually lives in a tabbed/paged interface.

Examples of classes that would falsely trigger:
- A dialog widget that references `TabBarTheme` for styling
- A settings screen with a `ListView` that references `PageStorageKey`
- Any widget referencing `DataTable`, `TableRow`, `PageController` (for other purposes), `Tabulator`, etc.

## Recommended Fix: Use AST analysis instead of string matching

### Approach A: Walk the widget tree to find actual TabBarView/PageView ancestor (most accurate)

Instead of checking for "Tab"/"Page" substrings, analyze whether the StatefulWidget is actually used as a child of `TabBarView` or `PageView`. This requires cross-file analysis and may be impractical for a lint rule.

### Approach B: Check class name and constructor usage patterns (pragmatic)

Check if the State's corresponding StatefulWidget is referenced in a `TabBarView(children: [...])` or `PageView(children: [...])` within the same file:

```dart
// Instead of classSource.contains('Tab') || classSource.contains('Page')
// Look for the StatefulWidget being used inside TabBarView/PageView children
final String fileSource = context.unitSource;
final String widgetName = _getStatefulWidgetName(node); // e.g. '_HomepageSectionsDialog'
final bool isInTabView = fileSource.contains(RegExp(
  r'TabBarView\s*\([^)]*children\s*:\s*\[[^]]*' + RegExp.escape(widgetName),
));
final bool isInPageView = fileSource.contains(RegExp(
  r'PageView\s*\([^)]*children\s*:\s*\[[^]]*' + RegExp.escape(widgetName),
));
if (!isInTabView && !isInPageView) return;
```

### Approach C: Check State class name for tab/page naming conventions (simplest)

Only fire when the State class name itself suggests tab/page content:

```dart
final String className = node.name.lexeme;
// Only match classes named like _MyTabState, _MyPageState, _TabContentState
final bool isTabPageState = RegExp(r'(?:Tab|Page)(?:Content|View|Body|Screen)?State$')
    .hasMatch(className);
if (!isTabPageState) return;
```

**Recommendation:** Approach B is the best balance of accuracy and complexity. Approach C is simpler but may miss legitimate cases. Approach A is ideal but likely too expensive for a lint rule.

## Test Fixture Updates

### New GOOD cases (should NOT trigger)

```dart
// GOOD: Dialog widget referencing HomeTab.icon — not tab content.
class _good_HomepageSectionsDialogState extends State<_good_HomepageSectionsDialog> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(HomeTab.icon),  // Contains "Tab" but widget is a dialog
        Flexible(child: ListView.builder(itemBuilder: (_, __) => Text('x'), itemCount: 1)),
      ],
    );
  }
}

// GOOD: Settings screen with ListView referencing PageStorageKey.
class _good_SettingsPageState extends State<_good_SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const PageStorageKey('settings'),  // Contains "Page" but not tab content
      children: [Text('Setting 1')],
    );
  }
}

// GOOD: Widget using DataTable inside a ListView (not tab content).
class _good_DataViewState extends State<_good_DataView> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [DataTable(columns: [], rows: [])],  // "Tab" in DataTable
    );
  }
}
```

### Existing BAD case (should still trigger)

```dart
// BAD: Actual tab content with ListView but no keep-alive mixin.
// expect_lint: prefer_keep_alive
class _bad_TabContentState extends State<_bad_TabContent> {
  @override
  Widget build(BuildContext context) {
    return TabBarView(
      children: [
        ListView.builder(itemBuilder: (_, __) => Text('x'), itemCount: 100),
      ],
    );
  }
}
```

## Environment

- **saropa_lints version:** 5.0.0-dev.1 (rule version v5)
- **Dart SDK:** 3.x
- **Trigger project:** `D:\src\contacts`
- **Trigger file:** `lib/components/main_layout/search/tab_context_menu.dart:465`
- **Trigger class:** `_HomepageSectionsDialogState`
- **String match:** `HomeTab.icon` at line 507 matching `classSource.contains('Tab')`
- **Rule source:** `widget_layout_rules.dart` lines 3047–3134

## Severity

Low — info-level diagnostic. The false positive recommends adding a mixin that is (a) already present, and (b) has no effect in a dialog context. However, the underlying detection logic (naive substring matching) will produce false positives across any codebase where identifier names contain "Tab" or "Page" — which is extremely common in Flutter projects.
