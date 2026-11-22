# BUG: `avoid_gesture_only_interactions` — fires on hit-only GestureDetector whose Semantics ancestor already exposes the action

**Status: Fixed**

Rule: `avoid_gesture_only_interactions`
File: `lib/src/rules/ui/accessibility_rules.dart`
Severity: False positive
Sites in downstream app: 8 sites in 7 files (sibling rules at the same sites: require_focus_indicator 12, prefer_cursor_for_buttons 4, require_hover_states 4)

---

## Summary

The detector (and the focus/cursor/hover sibling rules) is reported regardless of the Semantics ancestor. The code is correct; each site carries an `// ignore:` workaround.

---

## Attribution Evidence

```bash
grep -rn "'avoid_gesture_only_interactions'" lib/src/rules/
# Expected: lib/src/rules/ui/accessibility_rules.dart:NN
```

---

## Reproducer

```dart
Semantics(
  button: true,
  label: 'Select slot',
  onTap: onSelect, // assistive-tech tap action
  child: ExcludeSemantics(
    child: GestureDetector( // LINT, but should NOT lint
      behavior: HitTestBehavior.opaque, // invisible hit box over a painted shape
      onTap: onSelect,
      child: const SizedBox.square(dimension: 48),
    ),
  ),
)
```

**Frequency:** Only with the pattern above.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when an ancestor `Semantics` supplies `onTap`/`onLongPress` for the same action, or when the detector is an invisible hit region (no visible child to focus, ripple or hover). |
| **Actual** | The detector (and the focus/cursor/hover sibling rules) is reported regardless of the Semantics ancestor. |

---

## Suggested Fix

Walk ancestors for a `Semantics` with a matching `onTap`/`onLongPress`; skip when the detector child is a `SizedBox`/`ColoredBox` hit area with `HitTestBehavior.opaque`. Apply the same guard to the sibling rules. Add a fixture for the pattern above to the rule's example fixtures.


Status: Fixed (2026-11-21)
