# Proposed rule: flag `SingleChildScrollView`/`ListView` with unset `clipBehavior` near shadow-painting children

Filed from `d:\src\contacts` after a real bug: `_SecondaryActionSlider` in
`lib/components/home/section/v2/home_search_result_card.dart` hosted
`CommonIconButtonElevated` tiles (which paint a `BoxShadow` past their own
layout rect) inside a `SingleChildScrollView` with no explicit `clipBehavior`.
The default `Clip.hardEdge` clipped the tiles' shadows on the cross axis,
reading as a visual "cropped" bug. Fix was `clipBehavior: Clip.none` (the
scroll view's outer ancestor already clips correctly).

## Proposed detection

Flag a `SingleChildScrollView(...)` (or scrollable with an implicit
`clipBehavior`) call with no explicit `clipBehavior:` argument, when its
`child`/descendant subtree contains a widget known to paint decoration outside
its own bounds — heuristics:
- a `BoxDecoration`/`ShapeDecoration` with non-null `boxShadow`/`shadows`
- a known project wrapper carrying elevation (e.g. this repo's
  `CommonIconButtonElevated`, generically: any widget whose constructor takes
  an `elevationCommon`/`elevation` parameter)

## Why this needs judgment, not a blanket flag

`Clip.hardEdge` is often correct (e.g. a scroller with a background fill that
should clip). The lint should suggest reviewing the choice, not assume
`Clip.none` is always right — message should read something like "scroll view
clips its child by default; if children paint shadows/decorations past their
bounds, this may crop them — set `clipBehavior` explicitly."

## Status

Not investigated for feasibility (AST cost of walking descendant subtree for
shadow-painting widgets, false-positive rate). Filed as a proposal only — no
rule implementation attempted. Triage against existing `ui` category rules
before building.
