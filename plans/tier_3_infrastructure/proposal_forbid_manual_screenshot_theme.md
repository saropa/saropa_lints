# PROPOSAL: Forbid Manually-Set Theme in Golden/Screenshot Tests

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `forbid_manual_screenshot_theme` to flag golden/screenshot test code that manually constructs and injects a `ThemeData` (e.g. `MaterialApp(theme: ThemeData(...), ...)`) instead of using the project's shared golden-test harness/theme provider, which causes visual drift between golden tests and the real app theme.

**Closes gap:** `ripplearc_linter` `forbid_manual_screenshot_theme` (project-specific golden-test convention). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "ripplearc_linter" gaps section.

---

## Motivation

Golden tests are only trustworthy if they render with the exact same theme the real app uses. A test that hand-builds its own `ThemeData` instead of pulling from the shared app theme source silently diverges over time as the real theme evolves, producing golden images that pass CI but no longer represent the actual UI.

---

## Detection / Behavior

### Should flag (bad code)

```dart
testWidgets('renders card', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(primaryColor: Colors.blue), // LINT — manually constructed ThemeData in a golden test; use the shared app theme
      home: const MyCard(),
    ),
  );
  await expectLater(find.byType(MyCard), matchesGoldenFile('card.png'));
});
```

### Should pass (good code)

```dart
testWidgets('renders card', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light, // OK — shared theme source
      home: const MyCard(),
    ),
  );
  await expectLater(find.byType(MyCard), matchesGoldenFile('card.png'));
});
```

---

## Proposed Tier

Tier: Pedantic
Justification: project-specific golden-test convention requiring configuration of the "correct" shared theme source; too project-specific for Essential/Recommended/Professional, opt-in-depth tier.

---

## Edge Cases

1. **Test intentionally verifying dark-mode rendering via `AppTheme.dark`** — should pass; still a shared theme-source reference, not a hand-built `ThemeData`.
2. **Test deliberately verifying theme-override behavior itself (a theming feature test, not a golden screenshot test)** — should pass; scope detection to files/tests that call `matchesGoldenFile`, not all widget tests.
3. **`ThemeData` built via `AppTheme.light.copyWith(...)` to test a specific themed variant intentionally** — needs discussion; `copyWith` on the shared source preserves most of the real theme, arguably acceptable — may warrant allowing `copyWith` chains rooted in the shared theme while still flagging fully fresh `ThemeData(...)` construction.
4. **No shared theme source configured in the project (rule enabled without config)** — should require explicit configuration of the shared theme source identifier; without it, the rule cannot distinguish "correct" from "incorrect" theme construction and should not fire.

---

## Alternatives Considered

- **Ship without configuration, banning all `ThemeData(...)` construction anywhere in `test/`** — rejected; too blunt, would false-positive on legitimate non-golden widget tests that don't care about visual fidelity and have no reason to reference the shared theme.

---

## Decision

---

## Implementation Notes

Requires a config option (e.g. `analysis_options_custom.yaml` entry) naming the project's shared golden-theme identifier; scope detection to test files that call `matchesGoldenFile`/`expectLater(..., matchesGoldenFile(...))`.

---

## Commits
