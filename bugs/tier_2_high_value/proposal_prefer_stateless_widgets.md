# PROPOSAL: Flag `StatefulWidget`/`State` Classes with No Actual Mutable-State Usage

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `prefer_stateless_widgets` to flag a `StatefulWidget`/`State<T>` pair whose `State` class never calls `setState()`, never declares a mutable (non-`final`) field, and overrides no lifecycle method other than `build` (no `initState`, `dispose`, controller fields, etc.) — i.e. a `StatefulWidget` that is functionally a `StatelessWidget` in disguise, recommending conversion.

**Closes gap:** flutter_quality_lints `prefer_stateless_widgets`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` flutter_quality_lints Gaps section.

---

## Motivation

`StatefulWidget` carries real cost over `StatelessWidget`: an extra `State` object allocated and retained for the widget's lifetime, plus the cognitive overhead for a reader who has to check the whole `State` class to confirm nothing actually mutates before concluding it could have been stateless. This is a genuine cross-check (inspecting the `State` class's real usage of `setState`/mutable fields/lifecycle methods) rather than a shallow "does this extend StatefulWidget" check, which is what makes it a distinct rule from a naive class-shape check.

---

## Detection / Behavior

Resolve the `State<T>` class paired with a `StatefulWidget` and check: no call to `setState(...)` anywhere in the class, no field declared without `final`, no override of `initState`/`dispose`/`didUpdateWidget`/`didChangeDependencies` (which imply lifecycle-dependent behavior even without `setState`), and no field typed as a `Listenable`/`AnimationController`/`TextEditingController`/etc. (which imply stateful wiring even if `setState` isn't called directly, e.g. via `ListenableBuilder`).

### Should flag (bad code)

```dart
class Greeting extends StatefulWidget {
  const Greeting({super.key, required this.name});
  final String name;

  @override
  State<Greeting> createState() => _GreetingState();
}

class _GreetingState extends State<Greeting> { // LINT — no setState/mutable state; convert to StatelessWidget
  @override
  Widget build(BuildContext context) => Text('Hello, ${widget.name}');
}
```

### Should pass (good code)

```dart
class Greeting extends StatelessWidget {
  const Greeting({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Text('Hello, $name'); // OK
}
```

---

## Proposed Tier

Tier: Professional
Justification: catches a genuine, non-trivial architectural inefficiency (unnecessary `State` object + widget-tree cost) via real cross-checking of the `State` class's body, warranting a tier above purely cosmetic style rules but below Essential/Recommended given it's a refactor suggestion, not a correctness bug.

---

## Edge Cases

1. **`State` class with a `GlobalKey`-typed field used only for a one-time layout measurement, no `setState`** — needs discussion; a `GlobalKey` field alone doesn't prove statefulness, but it's a strong enough signal of eventual mutation that a conservative rule should treat it as disqualifying (i.e. do not flag), to avoid suggesting a conversion that breaks planned functionality.
2. **`State` class overriding `build` only, but the widget is intentionally kept `Stateful` for future extensibility (documented in a comment)** — a `// ignore:` with a one-line justification is the appropriate escape hatch here, consistent with saropa's ignore-suppression policy; the rule itself should not special-case comments.
3. **Mixins on the `State` class (e.g. `with SingleTickerProviderStateMixin`) with no actual `AnimationController` field** — should still flag if genuinely unused, but this is a suspicious enough shape that the rule should verify the mixin's own state isn't itself being used (e.g. `vsync:` passed somewhere) before flagging.
4. **`State` class with only a `final` field computed once in a field initializer (not `initState`)** — should flag as a candidate for `StatelessWidget`, since a `final` field initializer has no mutation dependency on lifecycle.

---

## Alternatives Considered

- **Flag any `StatefulWidget` unconditionally if it has zero fields on its `State`** — rejected as too shallow; the whole value of this rule (vs. a trivial shape check) is verifying the class's *actual* usage (setState calls, lifecycle overrides, controller-typed fields), matching flutter_quality_lints' own approach.

---

## Decision

---

## Implementation Notes

---

## Commits
