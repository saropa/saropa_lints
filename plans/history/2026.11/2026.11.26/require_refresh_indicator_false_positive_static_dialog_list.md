# require_refresh_indicator / require_refresh_indicator_on_lists: false positive on a static list in a dialog

Status: Fixed (2026-11-26)
Created: 2026-11-26
Rules: `require_refresh_indicator_on_lists` (lib/src/rules/widget/scroll_rules.dart:869), `require_refresh_indicator` (lib/src/rules/widget/widget_patterns_require_rules.dart:747)

## Summary
Both rules flag a `ListView.builder` whose data is a fixed in-memory list (world time zones filtered by a local search field) shown inside a picker dialog. There is no remote or refreshable data, so pull-to-refresh has no meaning.

## Attribution Evidence
```
OK    require_refresh_indicator_on_lists: defined at lib/src/rules/widget/scroll_rules.dart:869
OK    require_refresh_indicator: defined at lib/src/rules/widget/widget_patterns_require_rules.dart:747
```

## Reproducer
```dart
class Picker extends StatelessWidget {
  const Picker({super.key, required this.zones});
  final List<String> zones; // static, in-memory, filtered locally

  @override
  Widget build(BuildContext context) {
    return ListView.builder( // LINT (both rules) - false positive
      itemCount: zones.length,
      itemBuilder: (BuildContext c, int i) => Text(zones[i]),
    );
  }
}
// OK: same list wrapped in RefreshIndicator that refreshes nothing is a worse UI.
```

## Expected vs Actual
Expected: no report for lists with no async/remote source, or inside dialog/menu/picker surfaces. Actual: reported.

## AST Context
`ListView.builder` as an `Expanded` child inside a `Column`, itself the body of a dialog widget. Source list is a `List<ZoneRef>` field filtered synchronously.

## Root Cause
Rule checks only for the absence of an ancestor `RefreshIndicator`; it does not consider whether the data source is refreshable.

## Suggested Fix
Skip when the list sits under a dialog/popup/bottom-sheet route widget, or when `itemCount` derives from a local field with no Future/Stream/provider in the enclosing class.

## Fixture Gap
No fixture with a static filtered list in a dialog.

## Environment
saropa_lints 17.9.1; consumer: d:\src\contacts, lib/components/contact/detail_panels/timezone/contact_timezone_picker.dart.

## Resolution (2026-11-26)

Report partly correct.

- The stated root cause was incomplete: both rules already skipped dialogs, popups and sheets, but only lexically within one member (`isInsideTransientOverlay`). The consumer's list is in a private widget class shown through the `showDialogCommon` wrapper, so neither the class boundary nor the wrapper name was recognized.
- The second suggested fix (skip when the class has no Future/Stream/provider) was not used: the consumer's own State class has a `Future<void> _selectTimezone` method, so it would not have skipped it, and it would silence lists passed in from a `FutureBuilder` parent.

Fix, in `lib/src/widget_ancestor_utils.dart`, applied to both rules:

- `isHostedOnlyInOverlay`: private widget (or its `State`) constructed in the file only inside overlay widgets, overlay openers or `show...Dialog/BottomSheet/Popup/Menu` wrappers.
- `isConstBackedList`: `itemCount` is the length of a constant list declared in the file.

Verified: the new check returns true on the consumer file `contact_timezone_picker.dart`.

Still reported by design: the Reproducer snippet as written (public widget, list passed through the constructor, no dialog in sight). Nothing in that code distinguishes it from fetched data.

Observed, not changed: in `require_refresh_indicator` the remote-data word `list` also matches `ListView` itself, so that heuristic never filters anything.

Tests: `test/rules/widget/refresh_indicator_static_list_fp_test.dart`.

## Finish Report (2026-11-26)

Status: Fixed.

A follow-up review tightened both skips in `lib/src/widget_ancestor_utils.dart`. Overlay detection stops at navigation calls, page routes and event-handler closures, and the wrapper-name pattern is anchored on the overlay suffix. The constant-list check treats every other binding of the name (loop, catch, pattern, local function, member, possibly inherited member) as not constant.

Verification: `refresh_indicator_static_list_fp_test.dart`, `scroll_rules_test.dart`, `widget_layout_rules_test.dart` and `mobile_tile_and_nonscrolling_list_fp_test.dart` passed. The consumer file named in the report was not re-checked after the tightening.
