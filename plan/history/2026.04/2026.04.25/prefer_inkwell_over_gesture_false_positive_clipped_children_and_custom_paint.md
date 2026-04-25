# BUG: `prefer_inkwell_over_gesture` — fires when child is clipped (ClipOval / ClipRSuperellipse) or paints its own background that conflicts with ripple

**Status: Fixed**

Created: 2026-04-25
Rule: `prefer_inkwell_over_gesture`
File: `lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart` (lines ~2914–2933)
Severity: False positive
Rule version: v4+ (post-HitTestBehavior fix) | Since: unknown | Updated: unknown

---

## Summary

The rule's classifier is "GestureDetector with simple onTap and no complex
gesture → recommend InkWell." After the HitTestBehavior / onDoubleTap /
onLongPress-only fix in
[prefer_inkwell_over_gesture_false_positive_hittestbehavior_doubletap_longpress.md](prefer_inkwell_over_gesture_false_positive_hittestbehavior_doubletap_longpress.md),
three structural cases remain where `InkWell` is the wrong widget:

1. **Child is shape-clipped** — `ClipOval` (round avatars), `ClipRSuperellipse`
   (modern rounded thumbnails). A bare InkWell renders its ripple as a
   rectangle that's clipped by the shape — visually wrong (ripple bleeds
   outside or shows clipped corners flickering). Avoiding the ripple
   entirely is the right call here.

2. **Child paints its own background that fights the ripple** — a Container
   with a band-color background (timeline / availability cells) where the
   InkWell ripple appears as a layer over the band color and reads as
   visual noise on a dense scrollable wheel.

3. **No `Material` ancestor in scope** — InkWell requires a Material ancestor
   to render the ripple. When the call site sits under a custom-painted
   widget tree without a Material wrapper, an InkWell either renders no
   ripple (silent failure) or forces a synthetic Material wrapper that
   changes layout.

These are genuine cases where the AST can detect the failure mode (the
child type is visible in `node.argumentList.arguments` under `child:`).

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

### Case 1 — `ClipOval` child (round avatars)

```dart
class AvatarTile extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    // LINT — but should NOT lint
    // Replacing this GestureDetector with InkWell paints a rectangular
    // ripple that the ClipOval silently masks at the edges, producing a
    // visible "bite" on the ripple's circular perimeter. Round avatars
    // intentionally render without ripple to keep the silhouette crisp.
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: imageUrl != null
              ? Image.network(imageUrl!)
              : const Icon(Icons.person),
        ),
      ),
    );
  }
}
```

### Case 2 — `ClipRSuperellipse` thumbnail

```dart
class CapitalThumbnail extends StatelessWidget {
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // LINT — but should NOT lint
    // ClipRSuperellipse is a non-rectangular shape; InkWell would paint a
    // rectangular ripple that overflows the superellipse curves. The site
    // also has no Material ancestor at this position in the country detail
    // screen, so an InkWell would either need a synthetic Material wrapper
    // or produce no ripple at all.
    return GestureDetector(
      onTap: onTap,
      child: ClipRSuperellipse(
        clipBehavior: Clip.hardEdge,
        borderRadius: BorderRadius.circular(8),
        child: Image.asset('capital_thumb.png', width: 120),
      ),
    );
  }
}
```

### Case 3 — custom band-colored cells (no useful ripple)

```dart
class AvailabilityHourCell extends StatelessWidget {
  final int hour;
  final Color bandColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // LINT — but should NOT lint
    // The Container paints its own band color as the primary visual
    // affordance. An InkWell ripple over the band color would fight the
    // existing color signal — both are tied to the same hour cell but
    // communicate different things. On a dense scrollable wheel of 24
    // cells, ripple feedback reads as noise rather than confirmation.
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 12,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        color: bandColor,
        child: Center(child: Text('$hour')),
      ),
    );
  }
}
```

**Frequency:** Always — every `GestureDetector(onTap: ...)` whose direct
child is `ClipOval`, `ClipRSuperellipse`, `ClipPath`, or a `Container` with
explicit `color:` / `decoration:` set.

---

## Expected vs Actual

| Case | Expected | Actual |
|---|---|---|
| 1 (ClipOval child) | No diagnostic | LINT — InkWell would paint a ripple the ClipOval can't mask cleanly |
| 2 (ClipRSuperellipse child) | No diagnostic | LINT — same shape-clip issue, plus no Material ancestor at typical use sites |
| 3 (Container with explicit color child) | No diagnostic | LINT — ripple over a colored band reads as visual noise |

---

## AST Context

```
InstanceCreationExpression (GestureDetector)   ← rule reports here
  └─ ArgumentList
      ├─ NamedExpression (onTap)
      └─ NamedExpression (child)
          └─ InstanceCreationExpression (ClipOval | ClipRSuperellipse | ClipPath | Container)
                                          ↑ rule does not inspect the child type
```

The detector walks `node.argumentList.arguments` looking only for gesture
callback names. The `child:` arg's expression type is visible but
unexamined.

---

## Root Cause

The classifier at lines 2914–2933 does not inspect the child widget type.
Three child types are reliable signals that InkWell is structurally wrong:

- Shape-clipping wrappers: `ClipOval`, `ClipRSuperellipse`, `ClipPath`,
  `ClipRRect` (with non-rectangular `borderRadius`).
- Backgrounded containers: `Container` with explicit `color:` or
  `decoration:` BoxDecoration that owns the visual emphasis.
- (Implicit) absence of a Material ancestor — harder to detect statically
  but often co-occurs with the above.

---

## Suggested Fix

Add a child-type check that suppresses the lint when the direct child is
shape-clipping or self-painting:

```dart
// Constant set added near _simpleGestures / _complexGestures.
static const Set<String> _shapeClippingChildren = <String>{
  'ClipOval',
  'ClipPath',
  'ClipRSuperellipse',
  // ClipRRect is conditionally OK — only suppress when borderRadius is
  // not a uniform rectangle. Skipping for simplicity; project teams can
  // add a per-site // ignore: if needed.
};

bool _childIsShapeClippingOrSelfPainting(InstanceCreationExpression node) {
  for (final Expression arg in node.argumentList.arguments) {
    if (arg is! NamedExpression) continue;
    if (arg.name.label.name != 'child') continue;
    final Expression childExpr = arg.expression;
    if (childExpr is InstanceCreationExpression) {
      final String childType = childExpr.constructorName.type.name.lexeme;
      if (_shapeClippingChildren.contains(childType)) return true;
      // Container with explicit color: or decoration: is self-painting.
      if (childType == 'Container') {
        for (final Expression cArg in childExpr.argumentList.arguments) {
          if (cArg is NamedExpression) {
            final String cName = cArg.name.label.name;
            if (cName == 'color' || cName == 'decoration') return true;
          }
        }
      }
    }
  }
  return false;
}

// In the runWithReporter body, after the existing suppression checks:
if (_childIsShapeClippingOrSelfPainting(node)) return;
```

This narrows the lint to "GestureDetector with onTap, no shape-clipped or
self-painting child, and no other complications" — which is the subset
where InkWell is genuinely the better choice.

Optional follow-up: also walk one additional level (`SizedBox > ClipOval`,
`Center > ClipRSuperellipse`) since the project commonly nests a
SizedBox/Center between GestureDetector and the clip wrapper.

---

## Resolution

Implemented in `prefer_inkwell_over_gesture`:

- Added child-shape suppression for `ClipOval`, `ClipPath`, `ClipRRect`, and `ClipRSuperellipse`.
- Added self-painted-child suppression for `Container` when `color:` or `decoration:` is set.
- Added one-level pass-through wrapper traversal for common wrappers (`SizedBox`, `Center`, `Padding`, `Align`) so wrapped clipping children are recognized.
- Kept plain `Container(child: ...)` as a linting case to preserve valid detections.

Fixture updates added both positive and negative regression scenarios for these child patterns.

---

## Fixture Gap

The fixture should add:

1. `GestureDetector(onTap: ..., child: ClipOval(...))` — expect NO lint.
2. `GestureDetector(onTap: ..., child: SizedBox(child: ClipOval(...)))` — expect NO lint (one-level walk).
3. `GestureDetector(onTap: ..., child: ClipRSuperellipse(...))` — expect NO lint.
4. `GestureDetector(onTap: ..., child: Container(color: ..., child: ...))` — expect NO lint.
5. `GestureDetector(onTap: ..., child: Container(decoration: BoxDecoration(...), child: ...))` — expect NO lint.
6. `GestureDetector(onTap: ..., child: Container(child: ...))` (no color, no decoration) — expect LINT.
7. `GestureDetector(onTap: ..., child: Padding(child: Text(...)))` — expect LINT (genuine simple case).

---

## Environment

- saropa_lints version: post-HitTestBehavior fix (~v12.5.x candidate)
- Triggering project: `D:/src/contacts`
- Triggering files:
  - `lib/components/contact/avatar/avatar_sheet_style_section.dart` (~L142 — ClipOval child)
  - `lib/components/country/timezone/availability_hour_wheel.dart` (~L94 — Container with color child)
  - `lib/views/country/country_view_screen.dart` (~L229 — ClipRSuperellipse child)
