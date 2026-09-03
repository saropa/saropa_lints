# PROPOSAL: Flag Manual `Theme.of(context).brightness == Brightness.dark` — Use `MediaQuery`/Theme Convenience Getters

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `prefer_theme_mode_getters` to flag the manual comparison `Theme.of(context).brightness == Brightness.dark` (or `MediaQuery.of(context).platformBrightness == Brightness.dark`), recommending the equivalent boolean convenience getter/extension (`Theme.of(context).brightness.isDark` via saropa's or Flutter-adjacent extension conventions, or a project-defined `context.isDarkMode`) be used instead, for a single, greppable, less error-prone check.

**Closes gap:** many_lints `prefer_theme_mode_getters`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` many_lints non-themed gaps.

---

## Motivation

`brightness == Brightness.dark` scattered across the codebase is easy to get backwards (`!= Brightness.light` vs `== Brightness.dark` are subtly different if a third `Brightness` value were ever introduced, though today there are only two), and duplicates the same `Theme.of(context)`/`MediaQuery.of(context)` lookup at every call site. Centralizing to one boolean getter/extension gives one place to change the dark-mode-detection strategy (e.g. switching from `Theme.of` to `MediaQuery.platformBrightness`, or adding a "force light/dark" override) without hunting every comparison site.

---

## Detection / Behavior

Flag a `BinaryExpression` comparing `Theme.of(context).brightness` or `MediaQuery.of(context).platformBrightness` against `Brightness.dark`/`Brightness.light` with `==`/`!=`.

### Should flag (bad code)

```dart
Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark; // LINT — use Theme.of(context).brightness.isDark
  return Text(isDark ? 'Dark' : 'Light');
}
```

### Should pass (good code)

```dart
Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness.isDark; // OK
  return Text(isDark ? 'Dark' : 'Light');
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: readability/DRY rule with a mechanical rewrite, not a correctness bug — matches saropa's placement for similar "there is a named accessor for this exact comparison" convenience rules. Note the rule needs a documented, opt-in target extension name (or saropa should ship the `Brightness.isDark`/`isLight` extension itself) so the recommended fix maps to a real symbol.

---

## Edge Cases

1. **No `.isDark`/`.isLight` extension present in the project (and saropa doesn't ship one)** — needs discussion; the rule's correction message should either (a) point at a saropa-provided extension shipped alongside the rule, or (b) fall back to recommending the project define its own, since flagging code toward a non-existent symbol would be unactionable.
2. **`Theme.of(context).brightness != Brightness.light`** — should also flag (logically equivalent to `== Brightness.dark` given only two `Brightness` values today), toward `.isDark`.
3. **Comparison inside a `const` context (compile-time evaluable) — not applicable, since `Theme.of(context)` is never const** — no special case needed.
4. **`MediaQuery.platformBrightnessOf(context)` (the newer static-method form)** — should flag identically to the `.of(context).platformBrightness` instance-getter form.

---

## Alternatives Considered

- **Ship saropa's own `BrightnessX` extension (`isDark`/`isLight` on `Brightness`) as part of this proposal** — recommended; without a shipped target extension, the rule has nothing concrete to recommend, so bundling a small extension utility alongside the rule (similar to how other saropa rules ship a companion helper) is the pragmatic path.

---

## Decision

---

## Implementation Notes

---

## Commits
