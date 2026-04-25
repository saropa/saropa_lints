# BUG: `prefer_inkwell_over_gesture` — fires when InkWell is structurally inappropriate (HitTestBehavior, onDoubleTap, onLongPress-only)

**Status: Closed (Implemented)**

Created: 2026-04-25
Rule: `prefer_inkwell_over_gesture`
File: `lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart` (lines ~2914–2933)
Severity: False positive
Rule version: v4 | Since: unknown | Updated: unknown

---

## Summary

The rule recommends replacing `GestureDetector(onTap: …)` with `InkWell(onTap: …)`
for the Material ripple. Three real-world cases trip it where `InkWell` is
not a valid drop-in replacement, forcing `// ignore:` instead of a real fix:

1. **`behavior: HitTestBehavior.opaque` / `HitTestBehavior.translucent`** —
   `InkWell` exposes no equivalent. Bottom-nav buttons need
   `HitTestBehavior.opaque` so taps inside transparent padding still register;
   toast overlays need `HitTestBehavior.translucent` so taps fall through to
   the screen except where the toast catches them.

2. **`onDoubleTap` present** — `InkWell` does not support `onDoubleTap` at
   all (no double-tap parameter exists on the widget). Map clusters use
   `onDoubleTap` for zoom-in. Replacing with `InkWell` silently drops the
   double-tap callback.

3. **`onLongPress`-only (no `onTap`)** — `InkWell`'s primary affordance is
   the tap ripple. With no tap configured, the ripple still fires on
   accidental taps, confusing users when the actual interaction is a
   long-press (e.g. avatar long-press to open chooser sheet). Functionally
   InkWell does support onLongPress, but the UX is worse than GestureDetector
   here because the unwanted ripple appears on every accidental tap.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'prefer_inkwell_over_gesture'" lib/src/rules/
# lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart:2880:    'prefer_inkwell_over_gesture',
```

**Emitter registration:** `lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart:2880`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

### Case 1 — `HitTestBehavior.opaque` is required

```dart
class BottomNavButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // LINT — but should NOT lint
    // HitTestBehavior.opaque ensures taps in the transparent padding around
    // the icon still register. InkWell has no behavior parameter; replacing
    // with InkWell would shrink the hit target to the visible icon.
    return GestureDetector(
      onTap: _handleTap,
      onLongPress: _showOptions,
      behavior: HitTestBehavior.opaque,
      child: const SizedBox(width: 56, height: kBottomNavigationBarHeight),
    );
  }
  void _handleTap() {}
  void _showOptions() {}
}
```

### Case 2 — `onDoubleTap` is required

```dart
class MapClusterAvatar extends StatelessWidget {
  final VoidCallback onPressed;
  final VoidCallback onDoubleTap;   // zoom in
  final VoidCallback onLongPress;   // context menu

  @override
  Widget build(BuildContext context) {
    // LINT — but should NOT lint
    // InkWell has NO onDoubleTap parameter. Replacing this with InkWell
    // silently drops the zoom-in shortcut.
    return GestureDetector(
      onTap: onPressed,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      child: const Icon(Icons.location_on),
    );
  }
}
```

### Case 3 — `onLongPress`-only (no `onTap`)

```dart
class ContactAvatarWithMenu extends StatelessWidget {
  final VoidCallback openChooser;

  @override
  Widget build(BuildContext context) {
    // LINT — but should NOT lint
    // No onTap is wired — the only affordance is long-press. InkWell's tap
    // ripple would fire on every accidental tap and confuse users when the
    // intended interaction is a long-press.
    return GestureDetector(
      onLongPress: openChooser,
      child: const CircleAvatar(),
    );
  }
}
```

**Frequency:** Always — every site that uses any of these three constructs
trips the lint despite InkWell being structurally wrong.

---

## Expected vs Actual

| Case | Expected | Actual |
|---|---|---|
| 1 (HitTestBehavior present) | No diagnostic | LINT — InkWell has no equivalent param |
| 2 (onDoubleTap present) | No diagnostic | LINT — InkWell does not expose onDoubleTap |
| 3 (onLongPress only, no onTap) | No diagnostic | LINT — auto-suggested InkWell would change UX (ripples on accidental taps) |

---

## AST Context

```
InstanceCreationExpression (GestureDetector)   ← rule reports here
  └─ ArgumentList
      ├─ NamedExpression (onTap)            ← only checked: in _simpleGestures
      ├─ NamedExpression (onDoubleTap)      ← in _simpleGestures, but InkWell can't do it
      ├─ NamedExpression (onLongPress)      ← in _simpleGestures
      ├─ NamedExpression (behavior)         ← rule does not inspect this
      └─ NamedExpression (child)
```

The current detector at lines 2914–2933 reads only the named-arg names:

```dart
for (final Expression arg in node.argumentList.arguments) {
  if (arg is NamedExpression) {
    final String name = arg.name.label.name;
    if (_simpleGestures.contains(name)) hasSimple = true;
    if (_complexGestures.contains(name)) hasComplex = true;
  }
}
if (hasSimple && !hasComplex) {
  reporter.atNode(node.constructorName, code);
}
```

`HitTestBehavior` value, `onDoubleTap` presence, and `onTap`-vs-`onLongPress`-
only state are never considered.

---

## Root Cause

Three overlapping gaps in the simple/complex gesture classifier:

1. **`_complexGestures` does not include the `behavior` parameter as a
   suppressor.** A non-default `HitTestBehavior` is a strong signal that
   the GestureDetector is doing something InkWell can't replicate. Treating
   it as part of the "complex" category would suppress the lint.

2. **`onDoubleTap` is incorrectly classified as simple.** InkWell has no
   double-tap callback (`flutter/material/ink_well.dart` exposes onTap,
   onLongPress, onSecondaryTap, but no onDoubleTap). Recommending InkWell
   when onDoubleTap is wired is a wrong-fix.

3. **`onLongPress`-only is treated the same as `onTap`-only.** When `onTap`
   is absent, the InkWell ripple loses its primary purpose. The lint should
   require `onTap` to be present before recommending InkWell.

---

## Suggested Fix

```dart
@override
void runWithReporter(
  SaropaDiagnosticReporter reporter,
  SaropaContext context,
) {
  context.addInstanceCreationExpression((InstanceCreationExpression node) {
    final String typeName = node.constructorName.type.name.lexeme;
    if (typeName != 'GestureDetector') return;

    bool hasOnTap = false;
    bool hasOnDoubleTap = false;
    bool hasNonDefaultBehavior = false;
    bool hasComplex = false;

    for (final Expression arg in node.argumentList.arguments) {
      if (arg is! NamedExpression) continue;
      final String name = arg.name.label.name;
      if (name == 'onTap') hasOnTap = true;
      if (name == 'onDoubleTap') hasOnDoubleTap = true;
      // Any explicit behavior arg is a structural reason to keep GestureDetector.
      if (name == 'behavior') hasNonDefaultBehavior = true;
      if (_complexGestures.contains(name)) hasComplex = true;
    }

    // Suppress when InkWell cannot replace this GestureDetector:
    if (hasComplex) return;            // existing
    if (hasOnDoubleTap) return;        // InkWell has no onDoubleTap
    if (hasNonDefaultBehavior) return; // InkWell has no behavior
    if (!hasOnTap) return;             // No onTap → ripple recommendation is wrong UX

    reporter.atNode(node.constructorName, code);
  });
}
```

This narrows the rule to "GestureDetector with onTap (and possibly
onLongPress) and no other complications" — which is the case where InkWell
genuinely is the better choice.

---

## Fixture Gap

The fixture should add cases:

1. `GestureDetector(onTap: ..., behavior: HitTestBehavior.opaque, child: ...)` — expect NO lint.
2. `GestureDetector(onTap: ..., behavior: HitTestBehavior.translucent, child: ...)` — expect NO lint.
3. `GestureDetector(onTap: ..., onDoubleTap: ..., onLongPress: ..., child: ...)` — expect NO lint.
4. `GestureDetector(onLongPress: ..., child: ...)` (no `onTap`) — expect NO lint.
5. `GestureDetector(onTap: ..., child: ...)` (the genuine simple case) — expect LINT.
6. `GestureDetector(onTap: ..., onLongPress: ..., child: ...)` (no onDoubleTap, no behavior) — expect LINT (still simple — InkWell handles both).

---

## Out of Scope (separate concerns)

These also produce valid `// ignore:` cases but are harder for the rule to
detect from AST alone — surfaced for design discussion, not part of this fix:

- `child:` is a `ClipOval` / `ClipRSuperellipse` / custom shape that would
  visually clip or fight the ripple.
- No `Material` ancestor exists at the call site.
- The visual context (custom-painted band, dense scrollable cells) makes a
  ripple more distracting than helpful.

These could be addressed via a separate `analysis_options.yaml`-level opt-out
or per-site `// ignore:` (the project convention), since the rule cannot
reliably resolve them statically.

---

## Environment

- saropa_lints version: see `pubspec.yaml`
- Triggering project: `D:/src/contacts`
- Triggering files (HitTestBehavior / onDoubleTap / onLongPress-only):
  - `lib/components/main_layout/app_tabs/app_bottom_navigation_bar.dart` (~L743 — HitTestBehavior.opaque)
  - `lib/components/map/map_cluster_avatar.dart` (~L375 — onDoubleTap)
  - `lib/utils/system/toasts/popup_toast_message.dart` (~L370 — HitTestBehavior.translucent)
  - `lib/views/utilities/cartoon_avatar_screen.dart` (~L528 — onLongPress only)

---

## Resolution (2026-04-25)

Implemented in:

- `lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart`
- `example/lib/widget_patterns/prefer_inkwell_over_gesture_fixture.dart`
- `test/false_positive_fixes_test.dart`

Behavior after fix:

1. The lint now requires `onTap` before recommending `InkWell`.
2. The lint is suppressed when `onDoubleTap` is present.
3. The lint is suppressed when `behavior` is explicitly configured.
4. Existing suppression for complex pan/scale/drag gestures remains.
5. Pure `onTap` and `onTap + onLongPress` simple cases still lint.
