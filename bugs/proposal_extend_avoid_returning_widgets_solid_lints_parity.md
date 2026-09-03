# PROPOSAL: Extend `avoid_returning_widgets` to Cover solid_lints' Broader Detection Shape

**Status: Open**

Created: 2026-09-02
Type: Extend existing rule
Related rules: `avoid_returning_widgets` (existing — this proposal extends it)

---

## Summary

Extend saropa's existing `avoid_returning_widgets` rule (`lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart`) to also detect the shape solid_lints' same-named `avoid-returning-widgets` rule checks: **getters**, **top-level functions**, and **local (nested) functions** that return a `Widget`-typed value — not just instance methods on a class. Saropa's current implementation only visits `MethodDeclaration` nodes (excluding `build`) with a `Widget`/`*Widget`-suffixed return type; it does not visit `PropertyAccessorElement` getters, top-level `FunctionDeclaration`s, or `FunctionExpression`/local functions, all of which solid_lints' rule flags as the same underlying "widget-returning function should be a widget class" anti-pattern.

**Closes gap:** solid_lints `avoid-returning-widgets` — name collision with saropa's existing rule of the same name, which currently checks a narrower shape (methods only). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

The underlying problem — a function that builds and returns a `Widget` instead of being its own `StatelessWidget`/`StatefulWidget` class — is identical whether that function is a class method, a getter, a top-level helper, or a local closure defined inside `build()`. Saropa's current detection only catches the method form, so the exact same anti-pattern written as `Widget _buildHeader() => Row(...);` inside a local function, or `Widget get _header => Row(...);` as a getter, or `Widget buildCard(Item item) => Card(...);` as a top-level function, all pass silently today — a meaningful gap given how common getter-based and top-level "widget builder" helpers are in real Flutter codebases.

---

## Detection / Behavior

### Should flag (bad code) — currently MISSED by saropa's implementation

```dart
class _MyPageState extends State<MyPage> {
  // Getter form — MISSED today (only MethodDeclaration is visited)
  Widget get _header => Text('Header'); // LINT (after fix)

  @override
  Widget build(BuildContext context) {
    // Local function form — MISSED today
    Widget buildFooter() => Text('Footer'); // LINT (after fix)
    return Column(children: [_header, buildFooter()]);
  }
}

// Top-level function form — MISSED today
Widget buildCard(String title) => Card(child: Text(title)); // LINT (after fix)
```

### Should pass (good code) — unchanged

```dart
class _MyPageState extends State<MyPage> {
  @override
  Widget build(BuildContext context) => Column(children: [Header(), Footer()]); // OK — build() itself
}

class Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text('Header'); // OK — extracted widget class
}
```

---

## Proposed Tier

Tier: Recommended (unchanged — matches the existing rule's current tier; verify current placement in `lib/src/tiers.dart` before implementation and preserve it)
Justification: Extending detection scope on an already-shipped rule should not silently change its tier; this is a detection-completeness fix, not a new-rule tier decision.

---

## Edge Cases

1. **Getter/local/top-level function whose return type is inferred (no explicit `Widget` annotation) but resolves to `Widget` via type resolution** — needs discussion; the existing rule matches on syntactic `NamedType` (`Widget`/`*Widget` suffix) rather than resolved type, so extending to inferred-type getters requires switching that specific check to `usesTypeResolution`-backed static type comparison (which the rule already declares `usesTypeResolution => true`, so the resolved-type element is already available in-context).
2. **Top-level function returning `Widget` in a non-widget file (e.g. a pure utility file with no `StatefulWidget`/`StatelessWidget` in scope)** — should still flag; `applicableFileTypes => {FileType.widget}` currently scopes the rule to widget files, so confirm whether top-level widget-returning helpers commonly live outside files classified as `FileType.widget` — if so, this scope restriction itself may need loosening as part of the extension, and should be verified against real fixture examples before implementation.
3. **Local function/closure passed as a builder callback (e.g. `ListView.builder(itemBuilder: (context, index) => Text('$index'))`)** — should pass; that is the standard, idiomatic Flutter builder-callback pattern, not a "widget-returning helper method" anti-pattern, and must be excluded via checking whether the function literal is passed as an argument (framework callback) vs. declared as a named local function/method/getter.
4. **`build` method itself, and any getter/function literally named `build`** — should continue to pass, matching the existing method-form exclusion (`if (node.name.lexeme == 'build') return;`); apply the same name exclusion to the newly-covered getter/function forms.

---

## Alternatives Considered

- **Create a brand-new, separately-named rule for the getter/top-level/local-function cases instead of extending the existing rule** — rejected; the diagnostic message, correction guidance, and underlying anti-pattern are identical to the existing `avoid_returning_widgets` rule, and a second rule with overlapping intent would fragment configuration (two tier entries, two suppression names) for what users experience as one concept.

---

## Decision

---

## Implementation Notes

- Existing implementation location: `lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart`, class `AvoidReturningWidgetsRule`, `runWithReporter` (currently only calls `context.addMethodDeclaration`).
- Extension requires adding visitors for `PropertyAccessorElement`/getter declarations (`GetterDeclaration` shape via `MethodDeclaration` with `isGetter`, which may already partially overlap — verify whether `MethodDeclaration.isGetter` already covers class-level getters before assuming a wholly separate visitor is needed), `FunctionDeclaration` (top-level), and `FunctionExpression`/`FunctionDeclarationStatement` (local functions), each excluding the `build` name and excluding builder-callback argument positions (edge case 3).

---

## Commits
