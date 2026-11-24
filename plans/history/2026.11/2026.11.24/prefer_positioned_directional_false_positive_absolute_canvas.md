# BUG: `prefer_positioned_directional` — false positive for absolute canvas coordinates

**Status: Open**

Rule: `prefer_positioned_directional`
Severity: False positive (context-dependent)

## Summary

`Positioned(left:, top:)` places nodes of a pannable graph canvas at coordinates computed in one fixed left-origin space, the same space a CustomPainter draws edges in. `PositionedDirectional` would mirror only the nodes in RTL and detach them from their lines. The rule cannot know the coordinates are absolute.

## Repro

```dart
Positioned(left: center.dx - w / 2, top: center.dy - h / 2, width: w, height: h, child: node)
```
inside a Stack sized to a layout computed in absolute pixels, next to a CustomPainter using the same pixels.

## Expected

Skip when the offsets derive from computed absolute geometry, or document the rule as a heuristic.

## Found in

contacts: lib/components/chart/people_graph/people_graph_canvas.dart (`_place`).
