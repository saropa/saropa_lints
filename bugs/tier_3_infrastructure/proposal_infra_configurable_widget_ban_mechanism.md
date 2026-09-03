# PROPOSAL: Generic Configurable Widget/Type Ban Mechanism With Auto-Replace Quick Fix

**Status: Open**

Created: 2026-09-02
Type: New rule (infrastructure — generic, project-configurable engine)
Related rules: banned_identifier_usage (existing saropa rule — see Motivation for the two-way distinction)

---

## Summary

Add a generic, project-configurable rule letting a team declare "ban this widget/class, here's what to use instead" purely via config — type-aware (matches the resolved class/widget type, not just an identifier string token) and ships a quick fix that auto-replaces the banned widget with the suggested replacement, including auto-fixing the import if the replacement lives in a different file/package.

**Closes gap:** team_guard `team_guard.forbidden_widget` (github.com/HazemHamdy7/team_guard). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "Gap Theme 2".

---

## Motivation

saropa already has `banned_identifier_usage` (verified via `Grep` in `lib/src/rules/code_quality/code_quality_avoid_rules.dart`: `'[banned_identifier_usage] Usage of this identifier is banned. See analysis_options_custom.yaml banned_usage for the configured reason.'`, `configAliases: ['banned_usage']`), but that rule matches on the identifier NAME as a string token — it can misfire on an unrelated local variable, parameter, or method that happens to share a banned name with a widget class, and it carries no notion of the resolved type. This proposal is a distinct, TYPE-AWARE mechanism: it matches on the actual resolved class/widget type via type resolution, so it only fires on genuine instantiations of the banned type (not on any identifier that happens to share its name), and it ships an executable quick fix — auto-replacing the banned constructor call with the suggested replacement's constructor and fixing the import — where `banned_identifier_usage` offers no fix at all. Two-way difference: `banned_identifier_usage` = identifier-name matching, string-based, no fix; this proposal = resolved-type matching, type-aware, with an auto-fix.

---

## Detection / Behavior

This is an infrastructure proposal — the "detection" is driven entirely by project configuration. Describe the config schema and give a worked example.

### Config schema (proposed, in `analysis_options_custom.yaml`)

```yaml
saropa_lints:
  banned_widgets:
    - banned: "Container"
      suggested: "AppContainer"
      suggestedImport: "package:myapp/widgets/app_container.dart"
      reason: "Use the project's AppContainer wrapper for consistent theming."
    - banned: "LegacyLoadingSpinner"
      suggested: "AppLoadingIndicator"
      suggestedImport: "package:myapp/widgets/app_loading_indicator.dart"
      reason: "LegacyLoadingSpinner is deprecated; replace during any touch of this file."
```

### Should flag (bad code)

Given the config above:

```dart
Widget build(BuildContext context) {
  return Container(color: Colors.white);
  // LINT — banned_widget: "Container" is banned; use "AppContainer" instead.
  // Use the project's AppContainer wrapper for consistent theming.
}
```

### Should pass (good code)

```dart
import 'package:myapp/widgets/app_container.dart';

Widget build(BuildContext context) {
  return AppContainer(color: Colors.white); // OK — uses the suggested replacement
}
```

### Quick fix outcome

Applying the quick fix on the flagged `Container(color: Colors.white)` call rewrites the constructor name to `AppContainer(color: Colors.white)` AND adds `import 'package:myapp/widgets/app_container.dart';` to the file's import list (deduplicated against any import already present, inserted in the project's existing import-sort order) — a single-action fix, not an insert-TODO placeholder.

---

## Proposed Tier

Tier: Comprehensive/Pedantic, opt-in via config presence.
Justification: Zero default behavior — a project must author `banned_widgets` config entries before any diagnostic fires. Purely a team-governance mechanism, not a general correctness rule.

---

## Edge Cases

1. **Resolved-type matching vs. name shadowing** — a local class or import alias that happens to share the banned name but resolves to a DIFFERENT type (e.g. a project's own unrelated `Container` class in a non-Flutter context) must NOT be flagged; matching must go through the resolved element/type, not the bare identifier string, which is precisely the failure mode this proposal fixes relative to `banned_identifier_usage`.
2. **Replacement constructor with an incompatible parameter signature** — the quick fix should only apply automatically when the banned and suggested constructors are argument-compatible enough for a straight rename (same named-parameter set, or a documented safe subset); when they diverge, the fix should either skip named arguments that don't exist on the replacement (surfacing a partial-fix warning) or decline to offer an automatic fix at all rather than silently dropping/breaking arguments.
3. **Multiple banned entries for the same type name in different scopes** (e.g. banning `Container` project-wide but allowing it inside a specific legacy directory during migration) — consider a `target`/scope glob on each `banned_widgets` entry (reusing the same glob convention as the import-boundary DSL proposal) so bans can be rolled out incrementally rather than all-or-nothing.
4. **Import already present under a different prefix (`import '...' as legacy;`)** — the import-fixing part of the quick fix must detect an existing import of the suggested file (even if prefixed) and reuse it rather than adding a duplicate unprefixed import that could collide.
5. **Banning a type with no `suggested` replacement configured (ban-only, no migration path yet)** — should still flag with no quick fix offered, falling back to the same fix-less behavior as `banned_identifier_usage` for that entry.

---

## Alternatives Considered

- **Extend `banned_identifier_usage` in place to add type resolution and a quick fix** — considered, but the existing rule's whole design center is string/identifier matching (its `configAliases: ['banned_usage']` and problem message are both scoped to "identifier"); retrofitting type resolution and an auto-import-fixing quick fix onto it risks scope-creeping a simple rule into two very different mechanisms under one name. A separate rule keeps the identifier-based ban (cheap, no type resolution required) and the type-aware ban-with-fix (more expensive, requires `usesTypeResolution`) independently selectable per project.

---

## Decision

---

## Implementation Notes

---

## Commits
