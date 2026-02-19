# Task: `avoid_dependency_overrides`

## Summary
- **Rule Name**: `avoid_dependency_overrides`
- **Tier**: Recommended
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §1.62 Pubspec Rules

## Problem Statement

`dependency_overrides` in `pubspec.yaml` replaces the version of a package across the entire dependency graph, overriding what transitive dependencies request. While useful to temporarily resolve version conflicts, overrides left in production code:
1. Mask real version incompatibilities that should be fixed upstream
2. Can cause subtle bugs if the overridden version has breaking changes
3. Create build reproducibility issues for collaborators
4. Get easily forgotten and never removed

They are a form of technical debt that should be tracked and resolved.

## Description (from ROADMAP)

> dependency_overrides should only be used temporarily.

## Trigger Conditions

**YAML parsing required** — same challenge as `avoid_any_version`.

Detect `dependency_overrides:` section in `pubspec.yaml` that contains any entries.

Optionally: Detect that the override has been present for longer than N days (requires git blame — not feasible in static analysis).

## Implementation Notes

Same YAML parsing challenge as `avoid_any_version`. See that task for implementation options.

### Configuration
```yaml
custom_lint:
  rules:
    avoid_dependency_overrides:
      # Allow specific known-needed overrides
      allowed:
        - 'flutter_test'
```

## Code Examples

### Bad (pubspec.yaml — Should trigger)
```yaml
dependency_overrides:
  http: ^0.14.0  # ← trigger: overriding http
  path: 1.8.3    # ← trigger
```

### Good (pubspec.yaml — Should NOT trigger)
```yaml
# No dependency_overrides section, or empty section
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| Monorepo with local path overrides | **Suppress or note** — path overrides are common in monorepos | `path:` overrides are more acceptable |
| Flutter test override (common) | **Suppress if configured as allowed** | `flutter_test` is commonly overridden |
| Override added to fix a known CVE | **Trigger but note security context** | Security patches are legitimate |
| `git:` ref override for unreleased fix | **Trigger** — document the override reason | |

## Unit Tests

### Violations
1. `pubspec.yaml` with `dependency_overrides: http: ^0.14.0` → 1 lint

### Non-Violations
1. No `dependency_overrides` section → no lint
2. `dependency_overrides: {}` empty → no lint

## Quick Fix

No automated fix.

```
correctionMessage: 'dependency_overrides should only be used temporarily. Remove the override once the upstream package fixes the version conflict.'
```

## Notes & Issues

1. **YAML PARSING CHALLENGE** — same as `avoid_any_version`. See that task.
2. **Consider combining all pubspec rules** into a single YAML analysis pass: `avoid_any_version`, `avoid_dependency_overrides`, `prefer_semver_version`. These all require reading `pubspec.yaml`.
3. **The `_analyze_pubspec.py`** script may already check this.
