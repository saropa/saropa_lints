# BUG: web/desktop and list-refresh lints fire on mobile marker, non-scrolling and dialog widgets

**Status: Open**

Rules: `require_focus_indicator`, `require_hover_states`, `prefer_cursor_for_buttons`, `avoid_gesture_without_behavior`, `require_refresh_indicator_on_lists`, `require_refresh_indicator`, `require_scroll_controller`, `prefer_intrinsic_dimensions`, `prefer_positioned_directional`
Severity: False positive (reported from the Saropa contacts app)

## Patterns

1. `GestureDetector` as a flutter_map marker tap target (mobile map, parent `Semantics` exposes button role). Hover, focus and cursor lints do not apply: markers have no hover or focus chrome.
2. `GridView` / `ListView` with `shrinkWrap: true` and `NeverScrollableScrollPhysics`, or a list inside a dialog or popup of local toggles. Nothing to refresh; the parent owns refresh.
3. `Column(crossAxisAlignment: stretch)` flagged by `prefer_intrinsic_dimensions`; `IntrinsicWidth` would change layout and add a second layout pass.
4. `Positioned` used for game-board cells in physical coordinates; `PositionedDirectional` would mirror cells in RTL and desync game logic.
5. `avoid_gesture_without_behavior` fires although the child has a sized Stack and default hit testing is intended.

## Also

Several standalone `// ignore:` comments placed directly above the flagged line are not honored (email_recipient_field `addListener` line, snake_board `Positioned` arrow). Two stacked ignore lines apply only the lower one.
