# Deferred: External Dependency Rules

> **Last reviewed:** 2026-04-13

## Why these rules cannot be implemented

These rules require **network calls to external APIs** or **maintained databases of package metadata** that do not exist in the project. Even if the infrastructure to read `pubspec.yaml` exists (it does — via `ProjectContext` on the Dart side and `pubspecReader.ts` in the extension), these rules need data that is not available locally.

### What would unblock these rules

1. **pub.dev API integration**: A service that queries pub.dev for latest versions, deprecation status, and null-safety status. This could run in the extension (TypeScript) or as a CLI command. It cannot run inside the analyzer plugin (no network access during analysis).
2. **Version conflict database**: A maintained list of known incompatible package version combinations. Someone would need to build and maintain this — high ongoing effort.
3. **Package metadata cache**: A local cache of pub.dev data to avoid network calls on every analysis run. Could be refreshed periodically or on demand.

---

## Rules (5)

| Rule | Tier | Severity | What external data it needs |
|------|------|----------|-----------------------------|
| `prefer_latest_stable` | Recommended | INFO | **pub.dev API**: Must query latest stable version for each dependency and compare against `pubspec.yaml` version constraint. |
| `require_compatible_versions` | Essential | ERROR | **Conflict database**: Must check dependency version combinations against a maintained list of known incompatible pairs. No such database exists. |
| `avoid_deprecated_packages` | Essential | WARNING | **pub.dev API**: Must check each dependency's deprecation status on pub.dev. Packages can be deprecated at any time. |
| `require_null_safe_packages` | Essential | ERROR | **pub.dev API + SDK parsing**: Must check each dependency's SDK constraint to verify null-safety support. Requires parsing version constraints. |
| `prefer_first_party_packages` | Recommended | INFO | **Maintained list**: Must compare each dependency against a list of "official" Flutter/Dart packages and their unofficial alternatives. Someone must curate and maintain this list. |

**Total: 5 rules**
