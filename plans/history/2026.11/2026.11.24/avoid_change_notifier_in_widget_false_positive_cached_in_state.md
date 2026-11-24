# BUG: `avoid_change_notifier_in_widget` — false positive on a State-cached `??=` creation inside build()

**Status: Open**

Rule: `avoid_change_notifier_in_widget`
Severity: False positive

## Summary

The rule flags `_transform ??= TransformationController(home)` inside `build()` of a `State`. The `??=` creates the controller once and caches it in a State field that `dispose()` releases, so it is not re-instantiated per rebuild.

## Repro

```dart
class _S extends State<W> {
  TransformationController? _transform;
  @override
  Widget build(BuildContext context) {
    final TransformationController t = _transform ??= TransformationController(Matrix4.identity()); // FALSE POSITIVE
    return InteractiveViewer(transformationController: t, child: const SizedBox());
  }
  @override
  void dispose() { _transform?.dispose(); super.dispose(); }
}
```

## Expected

No diagnostic when the creation is the right-hand side of `??=` on a State field.

## Found in

contacts: lib/components/chart/people_graph/chart_people_graph.dart (suppressed with `// ignore: ... -- cached in State via ??=`).
