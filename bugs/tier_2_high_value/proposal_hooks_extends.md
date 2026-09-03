# PROPOSAL: Require Widgets Using Hooks to Extend HookWidget/HookConsumerWidget

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `hooks_extends` to flag a widget class that calls a `flutter_hooks` hook function (`useState`, `useEffect`, `useMemoized`, `useContext`, etc.) inside `build()` but does not extend `HookWidget` or `HookConsumerWidget` (from `flutter_hooks` / `hooks_riverpod`). Calling a hook outside a `HookWidget`'s build context throws at runtime.

**Closes gap:** `flutter_hooks_lint` `hooks_extends` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`flutter_hooks` hooks rely on `HookWidget`/`HookConsumerWidget` to track hook call order and lifecycle across rebuilds. Calling `useState()` etc. inside a plain `StatelessWidget` or `StatefulWidget`'s `build()` compiles fine but throws `Hook can only be called within the build method of a HookWidget` at runtime — a class of bug the analyzer can catch statically by checking the class hierarchy against the presence of hook calls.

---

## Detection / Behavior

Only applies when the `flutter_hooks` (or `hooks_riverpod`) package is a project dependency. Flag a class whose `build()` method body calls any function whose name matches `use[A-Z]\w*` (the hooks naming convention) while the class's supertype is not `HookWidget`, `HookConsumerWidget`, or a subtype of either.

### Should flag (bad code)

```dart
class Counter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final count = useState(0); // LINT — useState called but class extends StatelessWidget
    return Text('${count.value}');
  }
}
```

### Should pass (good code)

```dart
class Counter extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final count = useState(0); // OK — HookWidget supports hooks
    return Text('${count.value}');
  }
}
```

---

## Proposed Tier

Tier: Professional
Justification: Package-specific (flutter_hooks) runtime-crash prevention rule; only relevant to projects using the dependency, matching saropa's placement for other library-specific correctness rules.

---

## Edge Cases

1. **`HookConsumerWidget` (hooks_riverpod)** — should pass; treated as a valid hook-capable base class.
2. **Custom hook function (`useMyHook()`) defined in the same project** — should still flag if the containing class isn't hook-capable; the naming convention, not the origin package, drives detection.
3. **Hook call inside a nested closure/callback within `build()`** — should flag; hooks called from callbacks are also invalid per `flutter_hooks` rules, and this pattern is doubly wrong.
4. **A method named `useSomething` that is not actually a hook (false-positive risk)** — needs discussion; consider requiring the call's static type to resolve to a symbol imported from `flutter_hooks` to avoid flagging unrelated `use*`-named helper methods.

---

## Alternatives Considered

- **Detect via `Hook<T>` return type only** — rejected; many hooks return primitives (`bool`, `int`) or `void` (`useEffect`), so return-type detection would miss coverage. Name-prefix + import-source matching is more reliable.

---

## Decision

---

## Implementation Notes

---

## Commits
