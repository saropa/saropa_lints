# BUG: `require_hover_states` / `require_focus_indicator` / `prefer_cursor_for_buttons` — Flag InkWell, which already provides hover, focus and cursor

**Status: Open**

Created: 2026-11-23
Rule: `require_hover_states`, `require_focus_indicator`, `prefer_cursor_for_buttons`
File: `lib/src/rules/widget/widget_patterns_require_rules.dart` (line ~495), `lib/src/rules/ui/accessibility_rules.dart` (line ~3203), `lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart` (line ~4094)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

`InkWell` paints hover and focus highlights (`hoverColor`, `focusColor`, theme overlay colors), is focusable by default, and resolves `mouseCursor` to the click cursor when `onTap` is set. The three rules still report it. They should only report `GestureDetector`-style widgets with no built-in pointer or focus handling.

---

## Attribution Evidence

```bash
grep -rn "'require_hover_states'\|'require_focus_indicator'\|'prefer_cursor_for_buttons'" lib/src/rules/
# lib/src/rules/ui/accessibility_rules.dart:3203
# lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart:4094
# lib/src/rules/widget/widget_patterns_require_rules.dart:495
```

---

## Reproducer

```dart
Tooltip(
  message: 'More',
  child: InkWell( // LINT x3 — but should NOT lint (InkWell has hover, focus, click cursor built in)
    customBorder: const CircleBorder(),
    onTap: () {},
    child: const Padding(padding: EdgeInsets.all(3), child: Icon(Icons.more_horiz)),
  ),
)
```

**Frequency:** Always

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic for `InkWell` / `InkResponse` with `onTap` |
| **Actual** | All three rules report on the `InkWell` |

Seen in: Jupiter Tablet `lib/ui/make_it_yours.dart` (avatar "More" tile).
