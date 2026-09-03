# PROPOSAL: Prefer Design-System Widget Over Raw Material/Cupertino Equivalent

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_hardcoded_colors`, `theme_data` (proposed)

---

## Summary

Add `use_design_system_item` to flag direct use of a raw Material/Cupertino widget (`ElevatedButton`, `TextField`, `Card`, ...) when the project has declared a design-system wrapper for it (e.g. `AppButton`, `AppTextField`), configured via a name-mapping table in `analysis_options_custom.yaml`.

**Closes gap:** `leancode_lint` `use_design_system_item`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` `leancode_lint` gap list.

---

## Motivation

Design systems only deliver consistency if every screen actually uses the wrapped components; a raw `ElevatedButton(...)` bypasses the design system's spacing, elevation, and theming defaults just as effectively as a hardcoded color does. This is the same class of problem saropa's `avoid_hardcoded_colors` already polices for individual style values, extended to whole-widget substitution — teams that have built an `AppButton`/`AppCard` layer want the raw SDK widget itself flagged, not just its literal style arguments.

---

## Detection / Behavior

Config declares a `{raw: 'ElevatedButton', preferred: 'AppButton'}`-shaped mapping. Flag any `InstanceCreationExpression` for a configured `raw` widget type, unless it appears inside the file that defines the `preferred` wrapper itself (so the wrapper's own implementation isn't flagged for using the widget it wraps).

### Should flag (bad code)

```dart
ElevatedButton( // LINT — project has a design-system AppButton wrapper configured
  onPressed: onSave,
  child: const Text('Save'),
);
```

### Should pass (good code)

```dart
AppButton(onPressed: onSave, label: 'Save'); // OK — uses the design-system wrapper
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Opt-in, config-driven — inert without a configured mapping, safe for broad tier placement but valuable mainly to teams with an established design-system layer.

---

## Edge Cases

1. **No mapping configured** — should no-op entirely.
2. **Raw widget used inside the wrapper's own defining file** — should pass; the wrapper has to construct the underlying widget somewhere.
3. **Raw widget used inside a third-party package the project depends on (not project source)** — should pass; the rule only scans project source, not `.dart_tool`/`pub-cache` sources.
4. **Raw widget wrapped in an intermediate helper function before reaching the design-system wrapper (multi-hop indirection)** — needs discussion; single-hop detection is the v1 scope, deeper call-chain tracing is a possible follow-up.

---

## Alternatives Considered

- **Generalize into the same engine as the proposed `banned_identifier_usage`-style config mechanism (Gap Theme 2)** — worth revisiting once that generic engine ships; for v1, keep this as its own targeted rule since "prefer X over Y" (substitution) is a slightly different shape than "ban X" (prohibition).

---

## Decision

---

## Implementation Notes

---

## Commits
