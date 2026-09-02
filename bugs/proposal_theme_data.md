# PROPOSAL: Flag Inline `ThemeData(...)` Instantiation Outside the App Root

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_hardcoded_colors`, `avoid_hardcoded_text_styles`

---

## Summary

Add `theme_data` to flag a `ThemeData(...)` constructor call built inline anywhere other than the single app-root `MaterialApp.theme`/`darkTheme` wiring — e.g. inside a widget's `build()`, a helper function, or a one-off screen. Each inline `ThemeData(...)` is a second source of truth for design tokens (colors, text styles, shapes) that drifts from the app's real theme over time.

**Closes gap:** `design_system_lints` `theme_data` (github.com/design_system_lints). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` Gap Theme 8 "Design-system token provenance".

---

## Motivation

saropa already has `avoid_hardcoded_colors` and `avoid_hardcoded_text_styles`, which catch individual hardcoded values, but neither catches the coarser pattern of an entire `ThemeData(...)` object being reconstructed away from the app root — e.g. a `Theme(data: ThemeData(...), child: ...)` wrapper buried in a feature widget to "quickly" tweak one screen's look. That local `ThemeData` silently diverges from the design system and is invisible to per-value hardcoded-color/text-style checks because it is a single large object literal, not a scattered set of raw values.

---

## Detection / Behavior

Flag an `InstanceCreationExpression` for `ThemeData` (or `ThemeData.light`/`ThemeData.dark` factory calls) whose enclosing declaration is NOT one of: the top-level `main()`/app-bootstrap function, a field/getter directly assigned to `MaterialApp.theme`/`MaterialApp.darkTheme`/`CupertinoApp.theme`, or a file matching a configured "app theme" path (e.g. `lib/theme/*.dart`).

### Should flag (bad code)

```dart
class PromoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData( // LINT — inline ThemeData outside app-root wiring
        primaryColor: Colors.orange,
        textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 18)),
      ),
      child: const Text('Sale!'),
    );
  }
}
```

### Should pass (good code)

```dart
// lib/theme/app_theme.dart — the single source of truth
ThemeData buildAppTheme() {
  return ThemeData( // OK — recognized app-theme file
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
  );
}

// lib/main.dart
MaterialApp(theme: buildAppTheme()); // OK
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Requires configuring the app-theme file path/pattern to avoid false positives on legitimate theme-composition helpers; too setup-dependent for Essential/Recommended.

---

## Edge Cases

1. **`ThemeData.copyWith(...)` off `Theme.of(context)`** — should pass; this composes the existing theme rather than instantiating a new one from scratch.
2. **Test/golden files constructing a `ThemeData` for a widget test harness** — should pass; test files are excluded by default.
3. **A legitimate per-screen `Theme` override for a third-party embedded widget (e.g. a WebView chrome)** — needs discussion; likely needs an escape hatch via a documented `// theme-override:` comment or config allowlist rather than a blanket flag.
4. **`ThemeData()` with zero arguments (default theme)** — should still flag; even an empty override is a duplicate theme source once wrapped in `Theme(data: ...)`.

---

## Alternatives Considered

- **Extend `avoid_hardcoded_colors` to walk into `ThemeData` fields recursively** — rejected; that rule already fires per-value, and the real problem here is the object's *location*, not its contents.

---

## Decision

---

## Implementation Notes

---

## Commits
