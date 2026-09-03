# PROPOSAL: Prefer Automatic Dispose

**Status: Open**

Created: 2026-09-02

## Summary

Flags a `State`/controller class that manually overrides `dispose()` to close/cancel a resource (`AnimationController`, `StreamSubscription`, `TextEditingController`, etc.) when a mixin or helper that auto-disposes the same resource type is available and would remove the manual override entirely.

## Existing Coverage

`lib/src/rules/architecture/disposal_rules.dart` has many rules that *require* a manual `dispose()` override for specific controller types (`RequireTextEditingControllerDisposeRule`, `RequireTabControllerDisposeRule`, `RequireVideoPlayerControllerDisposeRule`, etc.) — these ensure disposal happens, but never suggest replacing it with an automatic mechanism. `lib/src/rules/packages/riverpod_rules.dart` has `PreferRiverpodAutoDisposeRule` and `RequireAutoDisposeRule`, but both are scoped to Riverpod's `autoDispose` provider modifier, not to general `State`-class resource fields. This proposal is a genuine extension covering the non-Riverpod, general-Flutter-widget case: preferring a disposal mixin/helper (e.g. a `DisposableMixin`, `AutoDisposeMixin`, or this package's own resource-tracking helper if one exists) over a hand-rolled `dispose()` override.

## Motivation

Manual `dispose()` overrides are a common source of leaks: every new controller field added to a `State` class requires a matching line in `dispose()`, and it's easy to add the field and forget the disposal line (this package's own `disposal_rules.dart` exists to catch exactly that gap after the fact). An auto-dispose helper that tracks registered resources and disposes them all in one place removes the failure mode structurally — there's no separate line to forget, because registration and disposal are coupled at the point the resource is created.

## Detection / Behavior

Triggers when a `State` class's `dispose()` override body consists only of calls to `.dispose()`/`.cancel()`/`.close()` on fields also initialized in `initState()` or as field initializers, and the project has an available auto-dispose mixin/utility (detected via `ProjectContext` or a configurable helper class name) that is not already applied to this class.

```dart
// BAD
class _MyWidgetState extends State<MyWidget> {
  late final AnimationController _controller;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _controller.dispose();
    _textController.dispose();
    super.dispose();
  }
}

// GOOD
class _MyWidgetState extends State<MyWidget> with AutoDisposeMixin {
  late final AnimationController _controller = autoDispose(
    AnimationController(vsync: this, duration: const Duration(seconds: 1)),
  );
  final TextEditingController _textController = autoDispose(TextEditingController());
  // No manual dispose() override needed — the mixin disposes everything registered.
}
```

## Quick Fix

None — manual refactor required. Adopting a disposal mixin changes field initialization and removes the `dispose()` override, which needs the developer to confirm the mixin is available/appropriate for the project.

## Alternatives Considered

Making this rule fire even when no auto-dispose helper exists in the project (suggesting the developer add one) was considered, but that risks prescribing a specific third-party or in-house pattern the project may not want; gating on an existing, detected helper keeps the rule actionable rather than aspirational.
