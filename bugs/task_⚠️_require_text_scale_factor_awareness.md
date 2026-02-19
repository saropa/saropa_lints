# Task: `require_text_scale_factor_awareness`

## Summary
- **Rule Name**: `require_text_scale_factor_awareness`
- **Tier**: Essential
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.43 Accessibility Advanced Rules

## Problem Statement

Users can increase the system font scale for accessibility (e.g., to 1.5x or 2x). Flutter respects this via `MediaQuery.textScaleFactor` (or `MediaQuery.textScaler` in newer Flutter). If UI containers have **fixed pixel heights** that don't account for text scaling, they will clip or overflow text at larger scale factors:

```dart
// BUG: Fixed height container
Container(
  height: 50, // ← fixed 50px — with 2x text scale, text is 48px and overflows
  child: const Text('Hello', style: TextStyle(fontSize: 24)),
)
```

This is an accessibility failure:
- **WCAG 2.1 Success Criterion 1.4.4** (Resize Text): Text must be resizable to 200% without loss of content
- App Store / Play Store accessibility guidelines require text scaling support
- Many users rely on large text for readability

The correct approach: use flexible layouts (`Flexible`, `Expanded`, `FittedBox`) or clamp the scale factor:
```dart
// Option 1: Flexible layout
Flexible(
  child: Text('Hello', style: TextStyle(fontSize: 24)),
)

// Option 2: Bounded text scale
MediaQuery(
  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(
    MediaQuery.of(context).textScaler.scale(1.0).clamp(1.0, 1.5), // max 1.5x
  )),
  child: child,
)
```

## Description (from ROADMAP)

> UI should handle text scaling. Detect fixed-size text containers.

## Trigger Conditions

1. `Container(height: <number>, child: Text(...))` where height is a literal number (not a variable)
2. `SizedBox(height: <number>, child: Text(...))` with fixed height
3. `Text` inside a widget with both `height` (fixed) and `fontSize` (fixed) where height ≤ fontSize × 1.5 (insufficient room for scaling)

**Phase 1 (Conservative)**: Flag `Container` or `SizedBox` with hardcoded `height` containing a `Text` widget.

## Implementation Approach

```dart
context.registry.addInstanceCreationExpression((node) {
  if (!_isFixedHeightContainer(node)) return; // Container/SizedBox with literal height
  if (!_hasTextChild(node)) return; // child or children contains Text widget
  reporter.atNode(node, code);
});
```

`_isFixedHeightContainer`: check if constructor is `Container` or `SizedBox` with `height:` being a numeric literal.
`_hasTextChild`: check if `child:` argument is `Text(...)` or contains a Text in `children:`.

## Code Examples

### Bad (Should trigger)
```dart
// Fixed height with text — will overflow at large text scale
Container(
  height: 48,           // ← trigger: fixed height
  child: const Text(    // ← text child
    'Button Label',
    style: TextStyle(fontSize: 24),
  ),
)

SizedBox(
  height: 36,  // ← trigger: fixed height
  child: Text('Item title'),
)
```

### Good (Should NOT trigger)
```dart
// Flexible (expands to fit content)
Container(
  child: const Text('Button Label'),  // ← no fixed height
)

// With padding instead of fixed height
Padding(
  padding: const EdgeInsets.symmetric(vertical: 12),
  child: const Text('Button Label'),
)

// With explicit text scale clamping
MediaQuery(
  data: MediaQuery.of(context).copyWith(
    textScaler: TextScaler.linear(
      MediaQuery.textScalerOf(context).scale(1.0).clamp(0.8, 1.5),
    ),
  ),
  child: SizedBox(height: 48, child: Text('Label')),
)
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| Icon buttons with fixed size | **Suppress** — icons don't scale with text | Check for icon vs text child |
| Fixed height for non-text content | **Suppress** — if no Text child | |
| `minHeight` constraint (not `height`) | **Suppress** — already flexible | |
| `textScaleFactor` clamped elsewhere in widget tree | **Suppress** — parent clamps scale | Cross-widget analysis needed |
| `FittedBox` wrapping Text | **Suppress** — text will scale to fit | |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `Container(height: 50, child: Text('...'))` → 1 lint
2. `SizedBox(height: 36, child: Text('...'))` → 1 lint

### Non-Violations
1. `Container(child: Text('...'))` (no fixed height) → no lint
2. `Container(height: 50, child: Icon(Icons.star))` (icon, not text) → no lint
3. `Container(constraints: BoxConstraints(minHeight: 50), child: Text('...'))` → no lint

## Quick Fix

Offer "Replace fixed height with minimum height":
```dart
// Before
Container(height: 50, child: Text('...'))

// After
Container(constraints: const BoxConstraints(minHeight: 50), child: Text('...'))
```

Or "Remove fixed height and use padding":
```dart
// After
Padding(
  padding: const EdgeInsets.symmetric(vertical: 13),
  child: Text('...'),
)
```

## Notes & Issues

1. **Accessibility tier**: Essential tier is appropriate — text scaling is a core accessibility requirement.
2. **HIGH FALSE POSITIVE RISK**: Fixed-height containers are extremely common in Flutter code. Many have Text children that won't actually overflow (because the text is short, the height is large enough). Phase 1 will have many false positives.
3. **`textScaleFactor` is deprecated**: In Flutter 3.x, `textScaleFactor` was replaced by `TextScaler`. Ensure the lint detects clamping via both old and new APIs.
4. **Practical threshold**: Maybe only flag when `fontSize` is defined in the same widget tree and the height-to-fontSize ratio is < 1.5. This reduces false positives significantly.
5. **Row height**: A `Row` with a `Text` child and a fixed height on the `Row` has the same issue. Consider extending detection to `Row(height:...)` — though `Row` doesn't have a direct `height` parameter, `SizedBox(height:, child: Row(...))` wrapping a `Text` should also trigger.
6. **Material/Cupertino guidelines**: Material Design's minimum touch target is 48dp. With 2x text scaling, 48dp containers become too small. This is the real-world impact.
