# Task: `prefer_semver_version`

## Summary
- **Rule Name**: `prefer_semver_version`
- **Tier**: Essential
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §1.62 Pubspec Rules

## Problem Statement

The `version` field in `pubspec.yaml` should follow semantic versioning (major.minor.patch) as required by pub.dev:
- `1.0.0` ✓
- `1.0.0+1` ✓ (build metadata)
- `1.0.0-beta.1` ✓ (pre-release)
- `1.0` ✗ (missing patch)
- `1` ✗ (missing minor.patch)
- `version1.0` ✗ (invalid format)

Non-semver version strings cause `dart pub publish` failures and confuse package consumers.

## Description (from ROADMAP)

> Version should follow semantic versioning (major.minor.patch).

## Implementation Notes

**YAML parsing required** — same challenge as `avoid_any_version`.

Validate `version:` field in `pubspec.yaml` matches semver pattern:
```regex
^\d+\.\d+\.\d+(\+\d+)?(-[\w.]+)?$
```

## Code Examples

### Bad (pubspec.yaml — Should trigger)
```yaml
version: 1.0  # ← trigger: missing patch
version: 1    # ← trigger: missing minor.patch
version: v1.0.0  # ← trigger: 'v' prefix not semver
```

### Good (pubspec.yaml — Should NOT trigger)
```yaml
version: 1.0.0
version: 2.3.1+4
version: 1.0.0-beta.1
```

## Edge Cases

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| No `version` field (package has no version) | **Suppress** — apps don't need version | Or trigger with different message |
| `version: null` | **Trigger** — null is invalid | |
| Flutter app (no publish) | **Suppress** or lower severity | Apps don't publish to pub.dev |

## Notes & Issues

1. **YAML PARSING CHALLENGE** — same as `avoid_any_version`.
2. **Combined with other pubspec rules** — implement in one pass.
3. **`version` for apps vs libraries**: App `pubspec.yaml` has a version field for `flutter build` and store releases — this is still important for apps to follow semver.
