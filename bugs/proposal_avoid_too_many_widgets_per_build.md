# PROPOSAL: Flag `build()` Methods That Instantiate Too Many Widgets

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_god_class` (unrelated metric — class-level field/method count, not widget instantiation count); no existing "build method complexity" or widget-instantiation-count rule found in `lib/src/rules/widget/build_method_rules.dart` or elsewhere in `lib/src/rules/`

---

## Summary

Add `avoid_too_many_widgets_per_build` to flag a `build()` method (or any method returning `Widget`) that instantiates more than N widget nodes (configurable, default e.g. 15) in its body. A `build()` method that constructs dozens of widget nodes inline is hard to read, hard to test in isolation, and forces the whole subtree to rebuild together even when only a small part actually changed.

**Closes gap:** `many_lints` `avoid_too_many_widgets_per_build` (pub.dev, budget rule). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "Gap Theme 9" (budget rules).

---

## Motivation

Flutter's composition model rewards decomposing large widget trees into smaller, named widgets — each becomes independently testable, independently rebuildable (via `const` and `Widget` subclassing breaking a rebuild boundary), and easier to read without scrolling through a wall of nested `Container(child: Column(children: [Row(...), ...]))` calls. A `build()` method with an unchecked number of inline widget instantiations is a common code-smell entry point: it starts small, grows one `if`-branch or one more child at a time, and eventually becomes a 200-line method that is effectively unreadable and untestable as a unit. `lib/src/rules/widget/build_method_rules.dart` already contains many rules about *what happens inside* `build()` (expensive computations, gradients, JSON decoding, rebuild-count anti-patterns per the grep of its correction messages), but none of them count and cap the sheer number of widget nodes instantiated — this proposal fills that specific gap.

---

## Detection / Behavior

Walk the body of a `build()` (or other `Widget`-returning) method and count `InstanceCreationExpression` nodes whose static type is assignable to `Widget`. Flag when the count exceeds the configured threshold (default 15).

### Should flag (bad code)

```dart
@override
Widget build(BuildContext context) { // LINT — 18 widget instantiations in one build() method
  return Scaffold(
    appBar: AppBar(title: const Text('Dashboard')),
    body: Column(
      children: [
        Card(child: Text('A')),
        Card(child: Text('B')),
        Card(child: Text('C')),
        // ... 13 more inline widget instantiations ...
        ElevatedButton(onPressed: () {}, child: const Text('Submit')),
      ],
    ),
  );
}
```

### Should pass (good code)

```dart
@override
Widget build(BuildContext context) { // OK — decomposed into named widgets, each independently testable
  return Scaffold(
    appBar: const _DashboardAppBar(),
    body: const _DashboardBody(),
  );
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody();

  @override
  Widget build(BuildContext context) {
    return Column(children: const [_DashboardCardList(), _DashboardSubmitButton()]);
  }
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: A configurable size-budget metric, not a correctness bug — matches other structural/complexity budget rules; some teams intentionally write flatter, more explicit `build()` methods and would find a default-enabled threshold noisy, so this belongs in an opt-in deeper-pass tier.

---

## Edge Cases

1. **Widgets built via a `for`-in list literal / `.map()` inside `children:`** (e.g. `[for (final item in items) ItemCard(item)]`) — should count as one instantiation site (the single `ItemCard(...)` template), not multiplied by the runtime list length, since the AST only sees one `InstanceCreationExpression` regardless of how many times it executes.
2. **Widgets constructed inside a helper method called from `build()`** (e.g. `_buildHeader()` returning a `Widget`, called once from `build()`) — should NOT count toward the calling `build()`'s total; the helper method is itself subject to the same rule independently if it crosses the threshold, which correctly rewards decomposition rather than punishing it.
3. **`const` widget instantiations** — should still count; `const` reduces rebuild cost but does not reduce the reading/maintenance cost the rule targets.
4. **Widgets that are simple leaf/primitive types typically not worth extracting** (`SizedBox`, `Spacer`, `Divider`, `Padding` used purely for spacing) — needs discussion; counting every `SizedBox(height: 8)` equally with a complex composite widget risks false positives on layouts that are legitimately just "a lot of spacing." Consider excluding a short allowlist of pure-layout/spacing widgets from the count, or accept the noise and let teams tune the threshold up.
5. **Generated code, and widgets built inside `itemBuilder`/`separatorBuilder` callbacks for `ListView.builder`** — the callback itself is a distinct method-like scope; count independently per callback rather than folding into the enclosing `build()`'s total, consistent with edge case 2's "each function scope counted independently" principle.

---

## Alternatives Considered

- **Count widget *nesting depth* instead of total instantiation count** — rejected as the primary metric; deep nesting is a related but distinct smell already partially covered by general readability concerns, and `many_lints`' prior art specifically counts total widgets, which is a simpler, more directly actionable metric ("extract some of these") than a depth metric.
- **Apply the same threshold to any method returning `Widget`, not just literally named `build`** — adopted; scoping only to methods literally named `build` would miss the equally common pattern of a `Widget _buildSection()` helper that itself grows too large, and the framework already treats any `Widget`-returning method the same way for composition purposes.

---

## Decision

---

## Implementation Notes

Candidate home: `lib/src/rules/widget/build_method_rules.dart`, which already hosts the widget's other `build()`-scoped rules (rebuild-count/expensive-computation checks per its correction messages around lines 71, 716, 885, 965, 1213, 1279, 1365) — reuse its existing `build()`-method-detection entry point (`context.addMethodDeclaration` filtered to `@override` + `Widget` return type + name `build`, or similar, per that file's established pattern) rather than writing a new detector. Threshold should be configurable, following the same options pattern as other configurable-threshold rules in `lib/src/rules/code_quality/complexity_rules.dart`.

---

## Commits
