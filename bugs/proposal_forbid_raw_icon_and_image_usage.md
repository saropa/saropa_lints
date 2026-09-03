# PROPOSAL: Forbid Raw `Icon`/`Image` Widgets Outside the Design System Wrapper

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `forbid_raw_icon_and_image_usage` to flag direct use of Flutter's raw `Icon(...)`/`Image(...)`/`Image.asset(...)`/`Image.network(...)` constructors instead of the project's design-system icon/image wrapper widgets, which centralize sizing, theming, accessibility labels, and loading/error states.

**Closes gap:** `ripplearc_linter` `forbid_raw_icon_and_image_usage`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "ripplearc_linter" gaps section.

---

## Motivation

A design-system icon/image wrapper typically enforces consistent sizing, semantic labels for accessibility, and standardized error/placeholder handling. Direct use of raw Flutter `Icon`/`Image` constructors bypasses all of that, producing UI drift (inconsistent icon sizes, missing `semanticLabel`, unhandled image load failures) one widget at a time.

---

## Detection / Behavior

### Should flag (bad code)

```dart
Icon(Icons.settings) // LINT — raw Icon widget; use the design system's icon wrapper (e.g. AppIcon)
Image.asset('assets/logo.png') // LINT — raw Image widget; use the design system's image wrapper (e.g. AppImage)
```

### Should pass (good code)

```dart
AppIcon(AppIcons.settings) // OK — design-system icon wrapper
AppImage.asset('assets/logo.png') // OK — design-system image wrapper
```

---

## Proposed Tier

Tier: Comprehensive
Justification: design-system enforcement rule requiring project-specific wrapper-widget configuration; consistent with other design-system-family rules (e.g. `edge_insets`) at Comprehensive rather than Essential/Recommended.

---

## Edge Cases

1. **Raw `Icon`/`Image` used inside the design-system wrapper's own implementation file** — should pass; the wrapper itself must construct the underlying Flutter widget. Exempt the file(s) that define the wrapper (via config path or annotation).
2. **`Icon`/`Image` constructed inside a third-party package's own widget tree that the project doesn't control** — should pass; the rule only inspects project-authored source, standard scope for a custom lint.
3. **`ImageIcon` (icon rendered from an `ImageProvider`)** — needs discussion; may warrant inclusion alongside `Icon`/`Image` since it's the same class of raw-widget bypass.
4. **Test/golden files intentionally constructing raw widgets to test the design-system wrapper itself** — should pass; standard test-file suppression applies, and this is exactly where testing the wrapper against the raw widget is expected.

---

## Alternatives Considered

- **Detect via import restriction (ban importing `Icon`/`Image` symbols directly) instead of usage detection** — rejected as the primary mechanism; an import-ban is coarser and would also block legitimate use inside the wrapper's own implementation file without extra exemption logic, so usage-site detection with a wrapper-file exemption is cleaner.

---

## Decision

---

## Implementation Notes

Requires config for: (1) the wrapper class name(s) to require instead (`AppIcon`/`AppImage` or project-specific names), (2) the exempt file path(s) where the wrapper itself is defined. Mirrors saropa's existing "use design-system X instead of raw Y" rule family if one exists — check for a shared config schema before adding a new one.

---

## Commits
