# PROPOSAL: Flag Private `Widget`-Returning Helper Methods That Should Be Widget Classes

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `returning_widgets` to flag a non-`build()` method or getter that returns a `Widget` (or `Widget` subtype) — the common `Widget _buildHeader() { ... }` pattern — recommending extraction into a dedicated `StatelessWidget`/`StatefulWidget` subclass instead. A widget-returning method has no independent `Element` in the widget tree: its entire body re-executes on every parent rebuild, it cannot be `const`, and it cannot short-circuit via `shouldRebuild`/`==` the way an extracted widget class can.

**Closes gap:** essential_lints `returning_widgets` (github.com/FMorschel/essential_lints). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

This is well-established Flutter performance/architecture guidance, independently documented by the Flutter team and widely repeated in the community: a method like `Widget _buildHeader() => Container(...)` looks like it "builds a widget," but it does not create a new `Element` in the tree — it's just a regular Dart method call inlined into the parent's `build()` output. Every time the parent widget rebuilds, the ENTIRE body of `_buildHeader()` re-executes unconditionally, with no opportunity for Flutter's element-diffing to skip work, no ability to mark the returned tree `const`, and no way to give the extracted UI its own `shouldRebuild`/equality-based rebuild avoidance.

Extracting the same logic into `class _Header extends StatelessWidget { ... }` fixes all three: the widget gets its own `Element`, can be `const`-constructed when its inputs allow, and Flutter's reconciliation can skip rebuilding it entirely when its `Key` and configuration are unchanged. This is a widely-cited "widget methods vs. widget classes" performance pattern, essential_lints is the only surveyed package that codifies it as an enforced lint rather than leaving it as scattered blog-post advice.

---

## Detection / Behavior

Flag a method or getter declaration where:

1. The declared return type is `Widget` or a class that extends/implements `Widget`, AND
2. The declaration is NOT itself an override of `Widget build(BuildContext context)` (i.e. not the canonical `build` method of a `StatelessWidget`/`StatefulWidget`/`State`), AND
3. The declaration is a member of a class that extends/implements `Widget` or `State` (i.e. it's a widget-building helper inside a widget/state class, not, e.g., a factory function in an unrelated utility file — see Edge Cases for that boundary).

### Should flag (bad code)

```dart
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(), // re-executes in full on every ProfilePage rebuild
        Text(name),
      ],
    );
  }

  // LINT — widget-returning method; has no independent Element, cannot be
  // const, and cannot skip rebuilding when its inputs are unchanged.
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Text('Profile'),
    );
  }
}
```

### Should pass (good code)

```dart
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _Header(), // OK — its own Element; can be const; skips rebuild when unchanged
        Text(name),
      ],
    );
  }
}

// OK — extracted into its own widget class instead of a helper method.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Text('Profile'),
    );
  }
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: This is a performance/architecture refactor recommendation, not a correctness bug — code using widget-returning helper methods works correctly, it merely rebuilds less efficiently than it could. Comprehensive matches saropa's placement for other rebuild-cost/architecture rules that require a deliberate extraction rather than a mechanical one-line fix.

---

## Edge Cases

1. **The canonical `build(BuildContext context)` override itself** — must never flag; that is the one method every widget/state class is required to have return `Widget`.
2. **A method that returns `Widget` but lives OUTSIDE any widget/state class** (e.g. a standalone builder function in a utility file, `Widget buildErrorBanner(String message) => ...` at top level, used as a factory pattern rather than an inline helper) — should pass for the initial rule; the "re-executes on every parent rebuild" cost specifically applies to methods called from inside another widget's `build()`, and top-level/utility factory functions are a different, more debatable pattern (some teams use these deliberately for pure, cheap widget construction). Scope the rule to widget/state class members only to avoid over-flagging.
3. **A getter (not a method) returning `Widget`** (`Widget get _header => ...`) — should flag identically; the rebuild-cost argument applies the same to getters as to methods.
4. **A method returning `Widget?`** (nullable) used for conditional rendering (`Widget? _buildBadgeIfNeeded() => condition ? Badge() : null;`) — should still flag; the same extraction applies (`_Badge` widget class returning `SizedBox.shrink()` or using a conditional in the parent's tree), though the correction message may need to note the nullable-return case explicitly.
5. **`build()` overrides in a `StatefulWidget`'s associated `State<T>` class** — must not flag; same exemption as item 1, just on the `State` side.

---

## Alternatives Considered

- **Auto-fix that mechanically extracts the method into a new class** — deferred; correctly inferring the extracted class's constructor parameters (which fields/locals the method body captures from the enclosing widget) is non-trivial and risks incorrect extractions. Flag now; consider a quick fix in a follow-up once the detection rule has field experience.
- **Also flag top-level/utility widget-returning functions (item 2 above)** — rejected for the initial scope; the performance argument is weaker and more contested for standalone factory functions not called from inside a specific widget's `build()`, and flagging them risks false positives against a legitimate, common pattern.

---

## Decision

---

## Implementation Notes

---

## Commits
