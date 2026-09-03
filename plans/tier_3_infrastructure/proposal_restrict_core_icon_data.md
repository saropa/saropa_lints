# PROPOSAL: Ban Raw Material `Icons.*` / `IconData` Literals Outside an Approved Icon Provider

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none (sibling rule `forbid_raw_icon_and_image_usage` exists in the same source package, ripplearc_linter, and covers the same underlying concern for `Image`/asset literals in addition to icons — not yet proposed separately here)

---

## Summary

Add `restrict_core_icon_data` to flag direct use of Material's built-in `Icons.*` constants (`Icon(Icons.home)`) or ad-hoc `IconData(...)` construction anywhere in widget-tree/UI code outside a project-configured "approved icon source" file (e.g. `lib/design_system/app_icons.dart`). Scattering raw `Icons.*` references through the codebase makes a design-system icon swap (rebrand, icon-pack migration, accessibility-driven glyph replacement) require a project-wide find/replace instead of a single centralized-file edit.

**Closes gap:** ripplearc_linter `restrict_core_icon_data` (source: ripplearc_linter). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

**Configuration dependency note:** this rule requires a project-configured allowlist path (the "approved icon provider" file, e.g. `lib/design_system/app_icons.dart`) — without that configuration surface, the rule cannot distinguish "the one file that's allowed to reference `Icons.*`" from "everywhere else." This is a configurable, opt-in architecture rule, not a universal Dart/Flutter concern.

Teams that build a design system typically centralize icon selection behind a single wrapper (an `AppIcons` class/enum, or a mapping from semantic names like `AppIcons.settings` to the underlying `IconData`) so that: (1) icon-pack or brand changes touch one file, (2) a consistent icon size/style/tint policy can be enforced at the wrapper boundary, and (3) accessibility label pairing (`semanticLabel`) can be enforced alongside every icon exposed by the wrapper. When `Icon(Icons.settings)` is written directly in a feature widget instead of `Icon(AppIcons.settings)`, none of those guarantees hold for that call site, and the design system's centralization is silently bypassed. This is the same category of problem saropa already addresses for design-system color tokens ("raw hex where a token exists is a defect" — project CLAUDE.md) but applied to icon selection instead of color.

---

## Detection / Behavior

Flag any of the following when they appear in a file OTHER than the project-configured approved icon provider path:

1. `Icons.<identifier>` (a `PrefixedIdentifier`/`PropertyAccess` referencing the `Icons` class from `package:flutter/material.dart` or `package:flutter/cupertino.dart`'s `CupertinoIcons`), used directly as an `Icon(...)`/`IconButton(icon: ...)` argument or any other expression position.
2. A raw `IconData(...)` constructor call (`IconData(0xe900, fontFamily: 'MyIconFont')`).

Configuration: a `restrict_core_icon_data` entry in `analysis_options_custom.yaml` specifying the allowed provider path(s), following the same allowlist-configuration pattern as saropa's other path-scoped architecture rules.

### Should flag (bad code)

```dart
// lib/features/settings/settings_page.dart
class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings), // LINT — raw Icons.* outside app_icons.dart
      onPressed: () {},
    );
  }
}
```

```dart
// Raw IconData construction outside the approved provider file.
const IconData customGlyph = IconData(0xe900, fontFamily: 'CustomIcons'); // LINT
```

### Should pass (good code)

```dart
// lib/design_system/app_icons.dart — the configured approved icon provider
class AppIcons {
  AppIcons._();

  static const IconData settings = Icons.settings; // OK — centralized definition site
}
```

```dart
// lib/features/settings/settings_page.dart
class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(AppIcons.settings), // OK — routed through the design-system wrapper
      onPressed: () {},
    );
  }
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Requires project-specific configuration (the approved provider path) to be meaningful, and only benefits teams that have already built a centralized icon wrapper. Not appropriate for Essential/Recommended, where the default configuration would either need a sensible guess (fragile) or flag every project without a design system (noisy). Matches saropa's placement of other config-driven design-system rules.

---

## Edge Cases

1. **No `restrict_core_icon_data` configuration present** — should pass entirely (rule is a no-op without a configured allowlist path, same as other opt-in path-scoped rules).
2. **`CupertinoIcons.*`** — should also flag under the same rule, since the concept (centralize the icon source) applies equally to the Cupertino icon set.
3. **Third-party package widgets that internally use `Icons.*`** (outside the analyzed project's own `lib/`) — out of scope; the rule only analyzes the project's own source files, standard for all saropa rules.
4. **The approved provider file itself referencing `Icons.*`** — should pass; that is precisely the one file allowed to do so.
5. **`Icon(Icons.error)` used inside a widget test/fixture file** — should flag same as production code unless the project's test directories are excluded via the same path-scoping mechanism other saropa rules use; note this as a config detail rather than a rule-logic exception.

---

## Alternatives Considered

- **Hardcode a single default allowed path** (`lib/design_system/app_icons.dart`) with no configuration option — rejected; project layouts vary too much (some teams use `lib/theme/icons.dart`, others `lib/core/ui/icons.dart`), and a rigid default would either miss real violations or force every project to conform to one naming convention just to use the rule.
- **Also ban `Image.asset(...)` literals in the same rule** (matching ripplearc_linter's broader sibling rule `forbid_raw_icon_and_image_usage`) — deferred to a separate proposal; icon and image-asset centralization are related but distinct concerns with different AST patterns and configuration surfaces, better landed independently.

---

## Decision

---

## Implementation Notes

---

## Commits
