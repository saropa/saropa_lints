# Bug Report: `avoid_expanded_outside_flex` — Insufficient Documentation

## Summary

The `avoid_expanded_outside_flex` rule (widget_layout_rules.dart:6251) correctly
detects a critical runtime crash but its `problemMessage` and `correctionMessage`
are too terse to help developers understand *why* it crashes or how to fix the
indirect case. Developers seeing the lint for the first time often don't know
what `ParentData` is or why an intervening widget breaks things.

---

## Current Messages

```dart
// widget_layout_rules.dart:6264–6271
static const LintCode _code = LintCode(
  name: 'avoid_expanded_outside_flex',
  problemMessage:
      '[avoid_expanded_outside_flex] Expanded without Row/Column parent '
      'throws FlutterError, crashing the app at runtime.',
  correctionMessage: 'Use Expanded only inside Row, Column, or Flex.',
  errorSeverity: DiagnosticSeverity.ERROR,
);
```

### What's missing

1. **No explanation of the mechanism.** The message says it "throws FlutterError"
   but doesn't explain *why*. Expanded writes `FlexParentData` onto its child's
   render object; only `RenderFlex` (Row/Column/Flex) knows how to interpret that
   data during layout. Every other parent render object rejects or ignores it,
   causing the framework to throw an unrecoverable `ParentDataWidget` error.

2. **No mention of the indirect case.** The most common trigger isn't placing
   Expanded directly inside a Stack — it's returning Expanded from a widget's
   `build()` method. The widget works when used directly in a Row, but crashes
   the moment it gets wrapped with Padding, LimitedBox, GestureDetector, or
   any other non-Flex container. This breaks the required Flex→Expanded parent
   chain without the developer realising it.

3. **Correction message is too vague.** "Use Expanded only inside Row, Column,
   or Flex" doesn't tell the developer *how* to fix the indirect case. The fix
   is to remove Expanded from `build()` and let the caller add it at the call
   site where the Flex parent is visible.

---

## Real-World Example (contacts project)

```
lib/components/system/network_detect/network_speed_gauge_widget.dart
```

```dart
class NetworkSpeedGaugeWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Expanded(         // <- flagged
    child: StreamBuilder<(double speed, double progress)>(
      stream: speedStream,
      builder: (context, snapshot) {
        return Column(
          children: <Widget>[
            Expanded(                                     // <- fine (Column is Flex)
              child: AnimatedRadialGauge(/* ... */),
            ),
            if (showStatus) CommonText(/* ... */),
          ],
        );
      },
    ),
  );
}
```

The parent in `network_speed_panel.dart` wrapped this widget in `LimitedBox`
inside a `Row`:

```dart
Row(
  children: <Widget>[
    LimitedBox(                          // <- NOT a Flex widget
      maxWidth: gaugeWidth,
      maxHeight: gaugeHeight,
      child: NetworkSpeedGaugeWidget(    // <- build() returns Expanded
        speedStream: downloadSpeedStream,
      ),
    ),
  ],
)
```

The widget tree becomes `Row → LimitedBox → Expanded → StreamBuilder`.
Expanded's parent is `LimitedBox`, not `Row`, so Flutter throws:

> "Incorrect use of ParentDataWidget. Expanded widgets must be placed directly
> inside Flex widgets."

The fix: remove Expanded from `build()`, return the StreamBuilder directly,
and add Expanded at the call site inside the Row.

---

## Proposed Messages

### problemMessage

```
Expanded, Flexible, and Spacer set FlexParentData on their child, which only
RenderFlex (Row, Column, Flex) can read during layout. Placing them inside any
other parent — Stack, Center, Padding, LimitedBox, SizedBox, etc. — throws an
unrecoverable "Incorrect use of ParentDataWidget" FlutterError at runtime.
This also happens indirectly when a widget's build() returns Expanded and the
widget is later wrapped by a non-Flex container, breaking the Flex→Expanded
parent chain.
```

### correctionMessage

```
Move Expanded/Flexible/Spacer so it is a direct child of Row, Column, or Flex.
If a reusable widget needs to expand, remove Expanded from its build() method
and let the caller wrap it at the call site where the Flex parent is visible.
```

---

## Proposed Dartdoc Addition

The existing dartdoc on the class (lines 6175–6249) has good code examples but
lacks a **"Why this crashes"** section explaining the ParentData mechanism.
Suggested addition after line 6180:

```dart
///
/// ## Why This Crashes
///
/// Expanded, Flexible, and Spacer work by writing `FlexParentData` onto their
/// child's render object. Only `RenderFlex` — the render object behind Row,
/// Column, and Flex — reads that data during layout. Every other parent render
/// object either ignores or rejects it. When Flutter detects the mismatch it
/// throws an unrecoverable `ParentDataWidget` error that cannot be caught by
/// try-catch.
///
/// The most dangerous variant is when a reusable widget returns Expanded from
/// its `build()` method. The widget appears to work when placed directly in a
/// Row, but the moment anyone wraps it — with Padding, LimitedBox,
/// GestureDetector, or any other widget — the Flex→Expanded parent chain
/// breaks and the app crashes at runtime.
///
```

---

## Affected Files

| File | Line | What |
|------|------|------|
| `lib/src/rules/widget_layout_rules.dart` | 6264–6271 | `problemMessage` and `correctionMessage` |
| `lib/src/rules/widget_layout_rules.dart` | 6175–6180 | Dartdoc missing "why" explanation |

## Priority

**Medium** — The rule itself works correctly; the detection logic is sound.
The issue is purely documentation: developers who encounter the lint don't get
enough context to understand or fix the problem, especially the indirect
build-return case.
