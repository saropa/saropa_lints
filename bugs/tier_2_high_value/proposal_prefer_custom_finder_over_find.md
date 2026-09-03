# PROPOSAL: Flag Repeated Raw `find.byType`/`find.text` Calls in Favor of a Reusable Finder

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `pass_mock_object`

---

## Summary

Add `prefer_custom_finder_over_find` to flag the same raw `find.byType(...)`/`find.text(...)`/`find.byKey(...)` call (or near-identical construction) repeated across multiple widget tests, suggesting extraction into a named, reusable `Finder` (or a page-object-style helper) so the widget lookup lives in one place.

**Closes gap:** `dart_code_metrics_presets` `prefer-custom-finder-over-find` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

When a dozen widget tests each independently call `find.byType(SubmitButton)`, renaming or restructuring `SubmitButton` in the widget tree means hunting down every duplicated call site, and a typo in one copy silently produces a finder that matches zero widgets instead of a compile error. A single named `Finder` (e.g. a `submitButtonFinder` constant or a page-object method) centralizes the lookup so it changes in one place and reads with intent at each call site.

---

## Detection / Behavior

### Should flag (bad code)

```dart
testWidgets('shows submit button', (tester) async {
  expect(find.byType(SubmitButton), findsOneWidget); // LINT — duplicated raw finder, repeated elsewhere
});

testWidgets('tapping submit triggers callback', (tester) async {
  await tester.tap(find.byType(SubmitButton)); // LINT — same raw finder duplicated across tests
});
```

### Should pass (good code)

```dart
final submitButtonFinder = find.byType(SubmitButton); // OK — single reusable, named Finder

testWidgets('shows submit button', (tester) async {
  expect(submitButtonFinder, findsOneWidget);
});

testWidgets('tapping submit triggers callback', (tester) async {
  await tester.tap(submitButtonFinder);
});
```

---

## Proposed Tier

Tier: Comprehensive
Justification: requires cross-test-file duplication analysis rather than single-file inspection, and is a test-maintainability preference rather than a correctness rule; scoped to an opt-in tier.

---

## Edge Cases

1. **The same `find.byType(X)` call appears only once in the whole test suite** — should pass; the rule targets duplication, not raw `find.*` usage in general.
2. **`find.byType`/`find.text` used with a dynamically computed argument (e.g. `find.text(user.name)`)** — should pass; not a literal duplication candidate since the argument varies per test.
3. **Duplicated finder calls within the *same* test function (e.g. built once, used twice)** — needs discussion; likely lower priority than cross-test duplication, but represents the same "extract once" opportunity locally.
4. **Duplication threshold configuration (2 occurrences vs. 3+)** — needs discussion; a low threshold risks flagging incidental coincidences in small test suites.

---

## Alternatives Considered

- **Flag every `find.*` call regardless of duplication, requiring all lookups go through named finders** — rejected as too strict for small, one-off widget tests where a single inline `find.text('OK')` is perfectly readable.

---

## Decision

---

## Implementation Notes

---

## Commits
