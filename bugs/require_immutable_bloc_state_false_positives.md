# Bug: `require_immutable_bloc_state` false positives on non-BLoC classes

## Summary

The `require_immutable_bloc_state` lint rule produces false positives on regular Flutter `State` subclasses and `StatefulWidget` classes whose names happen to end with "State". The rule's heuristic only excludes `extends State<T>` by checking for the exact string `'State'`, missing all indirect `State` subclasses from the Flutter framework.

## Severity

**High** - ERROR-level false positives force developers to add ignore comments for correct code, eroding trust in the lint rule.

## Affected Rule

- **Rule**: `require_immutable_bloc_state`
- **File**: `lib/src/rules/state_management_rules.dart` (lines 1928-2056)
- **Trigger condition**: Any non-abstract class whose name ends with `'State'` that doesn't extend `State<T>` directly and lacks `@immutable` or `Equatable`

## Reproduction

### Case 1: `PopupMenuItemState` subclasses (4 files affected)

```dart
// FALSE POSITIVE: This is a Flutter PopupMenuItemState, not a BLoC state
class _CommonPopupMenuItemState
    extends PopupMenuItemState<dynamic, CommonPopupMenuItem> {
  @override
  void handleTap() { /* ... */ }
}
```

Affected files:
- `lib/components/primitive/menu/common_popup_menu_item.dart:157` (`_CommonPopupMenuItemState`)
- `lib/components/primitive/menu/common_popup_menu_item_async.dart:79` (`_CommonPopupMenuItemAsyncState`)
- `lib/components/user/user_settings/menus/menu_toggle_facebook_integration.dart:43` (`_MenuToggleFacebookIntegrationState`)
- `lib/components/user/user_settings/menus/menu_toggle_user_preference.dart:57` (`_MenuToggleUserPreferenceState`)

### Case 2: `StatefulWidget` with domain term "State" in name (1 file affected)

```dart
// FALSE POSITIVE: "State" here means country state/province, not Flutter State
class ButtonDeleteStaticCountryState extends StatefulWidget {
  const ButtonDeleteStaticCountryState({super.key});

  @override
  State<ButtonDeleteStaticCountryState> createState() =>
      _ButtonDeleteStaticCountryStateState();
}
```

Affected file:
- `lib/components/utilities/database_tools/delete_static_buttons/button_delete_static_country_state.dart:17` (`ButtonDeleteStaticCountryState`)

## Root Cause

The Flutter State exclusion at line 1998-2003 only matches the exact superclass name `'State'`:

```dart
// Current code (line 2001-2002)
final String superName = extendsClause.superclass.name.lexeme;
if (superName == 'State') return; // Flutter State class
```

This misses:

1. **Indirect `State` subclasses** from the Flutter framework:
   - `PopupMenuItemState<T, W>`
   - `FormFieldState<T>`
   - `AnimatedWidgetBaseState<T>`
   - `ScrollableState`
   - `RefreshIndicatorState<T>`
   - Any custom `State` subclass

2. **`StatefulWidget` subclasses** whose class name ends with "State" as a domain term (e.g., country states, application states, order states)

## Proposed Fix

Replace the simple string equality check with a set of known Flutter framework `State` subclasses, and also exclude `StatefulWidget` subclasses:

```dart
/// Known Flutter framework State subclasses that are not BLoC states.
static const Set<String> _flutterStateClasses = <String>{
  'State',
  'PopupMenuItemState',
  'FormFieldState',
  'AnimatedWidgetBaseState',
  'ScrollableState',
  'RefreshIndicatorState',
};

/// Known Flutter widget base classes — a widget named "FooState" extending
/// StatefulWidget is using "State" as a domain term, not a BLoC state.
static const Set<String> _flutterWidgetClasses = <String>{
  'StatefulWidget',
  'StatelessWidget',
};
```

Then update the check:

```dart
// Skip if it's a Flutter State subclass or a widget using "State" as a domain term
final ExtendsClause? extendsClause = node.extendsClause;
if (extendsClause != null) {
  final String superName = extendsClause.superclass.name.lexeme;
  if (_flutterStateClasses.contains(superName)) return;
  if (_flutterWidgetClasses.contains(superName)) return;

  // Also skip if superclass name ends with 'State' and is likely
  // a Flutter State subclass (e.g., custom PopupMenuItemState variants)
  if (superName.endsWith('State') && !superName.endsWith('BlocState')) return;
}
```

### Alternative: Check for `endsWith('State')` on superclass

A broader (but simpler) approach would be to skip any class whose **superclass** also ends with `State`, since BLoC states typically extend `Equatable`, `BlocState`, or a base class that does not end with `State`:

```dart
if (extendsClause != null) {
  final String superName = extendsClause.superclass.name.lexeme;
  // Skip Flutter State hierarchy and StatefulWidget/StatelessWidget
  if (superName == 'State' ||
      superName.endsWith('State') ||
      superName == 'StatefulWidget' ||
      superName == 'StatelessWidget') {
    return;
  }
}
```

This is simpler but may be too broad. A middle ground: maintain the explicit set plus the `StatefulWidget` check.

## Additional Observation

The rule has `applicableFileTypes => {FileType.bloc}`, meaning it should only run on files classified as BLoC files. The fact that it's firing on widget files in `lib/components/` suggests the `FileType.bloc` classification heuristic may also need review - none of the 5 affected files are BLoC files.

## Expected Behavior

The rule should only flag classes that are actual BLoC/Cubit state classes, not:
- Flutter framework `State` subclasses (`PopupMenuItemState`, `FormFieldState`, etc.)
- `StatefulWidget` subclasses that use "State" as a domain term
- Any class extending a known Flutter framework State hierarchy class

## Test Cases to Add

```dart
// Should NOT trigger (Flutter PopupMenuItemState):
class _MyMenuState extends PopupMenuItemState<dynamic, MyMenu> {}

// Should NOT trigger (StatefulWidget with domain "State"):
class ButtonDeleteCountryState extends StatefulWidget {}

// Should NOT trigger (FormFieldState):
class _MyFieldState extends FormFieldState<String> {}

// SHOULD trigger (actual BLoC state without immutability):
class CounterState {
  int count;
  CounterState({this.count = 0});
}

// Should NOT trigger (BLoC state with Equatable):
class CounterState extends Equatable {
  final int count;
  const CounterState({this.count = 0});
  @override
  List<Object?> get props => [count];
}
```
