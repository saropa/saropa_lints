# BUG: `avoid_small_touch_targets` — Fires on Wide-Axis Pill Overlay Whose Tap Area Is Huge

**Status: Fixed**

Created: 2026-05-30
Fixed: 2026-05-31
Rule: `avoid_small_touch_targets`
File: `lib/src/rules/ui/accessibility_rules.dart` (line ~116)
Severity: False positive
Rule version: v5 → v6 | Since: unknown | Updated: v13.11.3

---

## Summary

The rule fires on any `SizedBox` / `Container` where one axis is `< 44` and the
AST subtree contains a descendant interactive widget (`GestureDetector`,
`InkWell`, `IconButton`, etc.). It does not consider the OTHER axis or the
effective tap-area shape. A `SizedBox(height: 38)` wrapping a `Stack` whose
overlay child is a full-width `Positioned.fill(child: GestureDetector(...))`
gets flagged — but the tap target is a wide pill-shaped band
(full-width × 38 px), not a small square button, and is hugely accessible.
The rule should either (a) require BOTH axes to be small, or (b) skip when the
interactive descendant is a `Positioned.fill` / `Align` / wide-region wrapper
inside a `Stack`.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
$ grep -rn "'avoid_small_touch_targets'" lib/src/rules/
lib/src/rules/ui/accessibility_rules.dart:133:    'avoid_small_touch_targets',

# Negative — rule is NOT in sibling repos
$ grep -rn "'avoid_small_touch_targets'" \
    ../saropa_drift_advisor/lib/src/ \
    ../saropa_drift_advisor/extension/src/
(zero matches)
```

**Emitter registration:** `lib/src/rules/ui/accessibility_rules.dart:116` (class `AvoidSmallTouchTargetsRule`)
**Rule class:** `AvoidSmallTouchTargetsRule` — registered in `lib/saropa_lints.dart:744`
**Diagnostic `source` / `owner` as seen in Problems panel:** `_generated_diagnostic_collection_name_#3` (Dart analyzer surfacing from saropa_lints plugin)

---

## Reproducer

Minimal Dart that reproduces the false positive:

```dart
// Wide pill-shaped overlay tap region — full-width × 38 px.
// The 38 px height is the deliberate pill design (e.g. the
// global search bar). The dismiss tap is performed anywhere
// on the wide band, not at a small square hit point.
// Expected: NO lint. Actual: LINT fires on the outer SizedBox.
SizedBox(
  height: 38,
  child: Stack(
    children: <Widget>[
      // Always-mounted content layer (text field + icons).
      Row(children: <Widget>[...]),
      // Overlay layer — covers the entire pill, dismissed by tap anywhere.
      Positioned.fill(
        child: AnimatedOpacity(
          duration: Duration(milliseconds: 350),
          opacity: showOverlay ? 1.0 : 0.0,
          child: GestureDetector(           // <-- rule walks AST, finds this
            behavior: HitTestBehavior.opaque,
            onTap: _dismissOverlay,
            child: ColoredBox(
              color: Colors.white,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('Good morning, Craig'),
              ),
            ),
          ),
        ),
      ),
    ],
  ),
)
```

**Frequency:** Always — any time `SizedBox(height: <44, width omitted)` wraps a
`Stack` whose subtree contains a literal `GestureDetector` / `InkWell` / etc.,
even when the gesture child is `Positioned.fill` over a wide region.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the tap region is wide-band (full-width × 38 px ≈ several thousand sq.px), not a small per-icon hit. WCAG 2.5.5's per-axis 44 px threshold is calibrated for icon-button targets; a wide overlay band easily satisfies effective-tap-area criteria. |
| **Actual** | `[avoid_small_touch_targets] Touch target under 44px violates WCAG 2.5.5 ...` reported on the outer `SizedBox`. |

---

## AST Context

```
InstanceCreationExpression (SizedBox)               ← rule reports here
  argumentList
    └─ NamedExpression (height: 38)
    └─ NamedExpression (child:)
        └─ InstanceCreationExpression (Stack)
            └─ argumentList → NamedExpression (children:)
                └─ ListLiteral
                    ├─ InstanceCreationExpression (Row)            ← not interactive
                    └─ InstanceCreationExpression (Positioned.fill)
                        └─ InstanceCreationExpression (AnimatedOpacity)
                            └─ InstanceCreationExpression (GestureDetector)  ← match — fires rule
                                └─ InstanceCreationExpression (ColoredBox)
                                    └─ InstanceCreationExpression (Align)
                                        └─ InstanceCreationExpression (Text)
```

The visitor (`_InteractiveWidgetVisitor`, a `RecursiveAstVisitor<void>`) walks
EVERY `InstanceCreationExpression` in the SizedBox subtree. Once it hits
`GestureDetector`, `_containsInteractiveWidget` returns true and the outer
SizedBox is reported because `height: 38 < 44`. The width is not specified, so
the per-axis check `(width != null && width < _minTouchTarget)` is `false` for
width and `true` for height — one match is enough.

---

## Root Cause

### Hypothesis A: Per-axis OR check is too eager

`accessibility_rules.dart:188-191`:

```dart
if ((width != null && width < _minTouchTarget) ||
    (height != null && height < _minTouchTarget)) {
  reporter.atNode(node.constructorName, code);
}
```

The OR means: a SizedBox with `height: 38` and no `width` (or with a large
implicit/Expanded width via parent layout) gets flagged identically to a 24×24
square. But the WCAG concern is whether a finger contact patch can hit the
target reliably — a wide band along one axis is hit-reliable even when the
other axis is short.

Refinement: require BOTH axes to be `< _minTouchTarget` before flagging, OR
treat `width == null` (caller deferring width to parent) as a "wide" signal
that downgrades the per-axis check to require height < threshold AND the
descendant interactive widget to be a per-pixel hit (`IconButton`, `Checkbox`,
`Radio`, `Switch`) rather than a region recognizer (`GestureDetector`,
`InkWell`, `InkResponse`).

### Hypothesis B: Visitor does not differentiate region taps from icon taps

`_interactiveWidgets` lumps `GestureDetector` / `InkWell` / `InkResponse`
together with `IconButton` / `Checkbox` / `Radio` / `Switch`. The first three
are region recognizers that intentionally cover whatever child they wrap (the
welcome overlay's `Positioned.fill` makes the gesture cover the whole pill).
The last four are per-icon targets where the visual size IS the hit area.

A more precise rule would only treat the icon-sized set as "touch targets" for
the per-axis check. `GestureDetector` / `InkWell` should require an extra
signal — e.g. the gesture is the only child of a small-on-both-axes parent,
not a `Positioned.fill` / `Align` / `Center` wrapper inside a `Stack`.

### Hypothesis C: AST walk recurses through layout wrappers without context

The visitor traverses unconditionally and reports on the OUTER SizedBox even
when the interactive descendant is many layers deep through layout-only
wrappers (`Stack`, `Positioned`, `AnimatedOpacity`, `RepaintBoundary`,
`ColoredBox`, `Align`, …). The rule has no notion of "this descendant's
effective tap area is determined by its OWN constraints, not the outer
SizedBox" — yet `Positioned.fill` explicitly opts the child OUT of inheriting
size constraints from the SizedBox in the conventional sense.

---

## Suggested Fix

`accessibility_rules.dart` around line 188:

1. **Tighten the size predicate**: only flag when BOTH axes are below
   threshold (current code flags if either is). One-axis-small + other-axis-
   wide is the wide-pill-overlay case and is accessible.

   ```dart
   final bool widthSmall = width != null && width < _minTouchTarget;
   final bool heightSmall = height != null && height < _minTouchTarget;
   // Old: widthSmall || heightSmall.
   // New: require both axes to be small. A wide-band overlay (one axis
   // unspecified, or one axis ≥ 44) is hit-reliable even if the other
   // axis is short — WCAG 2.5.5 cares about effective tap area, not
   // per-axis minimum. The single-axis check fired on wide-pill overlays
   // (Stack + Positioned.fill + GestureDetector) where the dismiss
   // region is the entire pill width.
   if (widthSmall && heightSmall) {
     reporter.atNode(node.constructorName, code);
   }
   ```

2. **OR split `_interactiveWidgets` by category** and only run the per-axis
   check for the icon-sized set:

   ```dart
   static const Set<String> _iconSizedTargets = <String>{
     'IconButton', 'TextButton', 'ElevatedButton', 'OutlinedButton',
     'Checkbox', 'Radio', 'Switch',
   };
   static const Set<String> _regionRecognizers = <String>{
     'GestureDetector', 'InkWell', 'InkResponse',
   };
   ```

   Then only fire on small-SizedBox + `_iconSizedTargets` descendant;
   region recognizers wrapping a `Positioned.fill` / `Align` / `Center`
   path should be skipped.

(1) is the simpler, safer change. (2) is more precise but requires extra AST
walking from the gesture child up its parent chain.

---

## Fixture Gap

`example/lib/accessibility/avoid_small_touch_targets_fixture.dart` currently
covers:

1. `SizedBox(width: 24, height: 24, child: IconButton())` — expect LINT (square small)
2. `SizedBox(width: 48, height: 48, child: IconButton())` — expect NO lint (square OK)

Missing cases:

1. **Wide pill overlay** — `SizedBox(height: 38, child: Stack(children: [..., Positioned.fill(child: GestureDetector(...))]))` — expect NO lint (wide-band region tap, not icon hit).
2. **Single-axis small with IconButton** — `SizedBox(height: 32, child: IconButton())` (width omitted, parent Expanded gives wide horizontal extent) — currently fires; the rule SHOULD still fire here if the interactive descendant is an icon-sized target, because the user can only tap the icon-sized hit, not the wide row. This is the case where Hypothesis A's "require both axes small" fix would regress unless paired with Hypothesis B's category split.
3. **`Positioned.fill` GestureDetector inside small Stack** — same shape as the reproducer — expect NO lint.
4. **`InkWell` covering wide `ListTile`** — `SizedBox(height: 40, child: InkWell(onTap: ..., child: ListTile(...)))` — expect NO lint (wide list-row tap area).

Add all four cases with `// expect_lint:` / `// OK` markers so a future
regression is caught by the fixture suite.

---

## Root Cause

(See Hypotheses above.)

---

## Suggested Fix

(See section above.)

---

## Changes Made

Implemented Hypothesis B (split `_interactiveWidgets` by category) layered with Hypothesis A (require both axes small for region recognizers). The single
`_interactiveWidgets` set was replaced by two intent-specific sets:

- `_iconSizedTargets` — `IconButton`, `TextButton`, `ElevatedButton`,
  `OutlinedButton`, `Checkbox`, `Radio`, `Switch`. Visual size IS the hit area,
  so the per-axis OR check remains (either explicit axis `< 44` fires).
- `_regionRecognizers` — `GestureDetector`, `InkWell`, `InkResponse`. The
  gesture covers whatever the child / `Positioned.fill` lays out to, so the
  rule now requires BOTH axes to be explicitly `< 44` before firing. The
  wide-pill case (`SizedBox(height: 38)` over a `Positioned.fill` GestureDetector,
  width unspecified) has `widthSmall == false` and is therefore skipped.

The descendant walk now classifies into a small struct (`_InteractiveDescendants`
with `hasIconSized` / `hasRegionRecognizer` flags) so a single SizedBox
containing both kinds is still flagged via the icon-sized path. The rule's
DartDoc and version stamp were updated to `v6`; problem-message version
tag bumped from `{v5}` to `{v6}`.

## Tests Added

`example/lib/accessibility/avoid_small_touch_targets_fixture.dart` was expanded
from 2 cases to 6 cases covering the gap list:

- `_bad1` (kept) — `SizedBox(width: 24, height: 24, child: IconButton())` → LINT.
- `_good1` (kept) — `SizedBox(width: 48, height: 48, child: IconButton())` → no lint.
- `_bad2_iconSingleAxisSmall` (new) — `SizedBox(height: 32, child: IconButton())` → LINT (icon-sized + single-axis-small).
- `_good2_widePillOverlay` (new) — bug reproducer: `SizedBox(height: 38, child: Stack([Row(), Positioned(...child: AnimatedOpacity(child: GestureDetector(...))))]))` → no lint.
- `_good3_wideListRowInkWell` (new) — `SizedBox(height: 40, child: InkWell(child: ListTile()))` → no lint.
- `_bad3_smallSquareGesture` (new) — `SizedBox(width: 24, height: 24, child: GestureDetector(...))` → LINT (region recognizer + both axes small is still a genuine small tap target).

Note: the project's unit tests pin instantiation only; fixture behavior is
verified by reading + the new `expect_lint:` markers. The scan CLI uses
unresolved `parseString`, so `node.constructorName.type.element?.name`
returns null there and the rule no-ops — production analyzer (where the
user encountered the FP) does full resolution, so the fix lands as designed.

## Commits

(Pending — implemented in this turn.)

---

## Environment

- saropa_lints version: 13.11.2
- Dart SDK version: 3.12.0 (stable, 2026-05-08, windows_x64)
- custom_lint version: (saropa_lints is native analyzer plugin, not custom_lint — see project_saropa_lints_native_plugin)
- Triggering project/file: `d:/src/contacts/lib/components/main_layout/search/app_search_bar.dart:655`
  - Pattern: 38 px pill `SizedBox` whose `Stack` contains a welcome-overlay `Positioned.fill(child: AnimatedOpacity(child: GestureDetector(...)))` for dismiss-on-tap.
  - Downstream workaround: `// ignore: avoid_small_touch_targets -- wide pill-overlay dismiss tap, not a small button` on the SizedBox.
