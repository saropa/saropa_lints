# Phase 6: Testing & Release — Remaining Items

Tracks the outstanding work from [ROADMAP_NATIVE_PLUGIN.md](../../ROADMAP_NATIVE_PLUGIN.md) Phase 6.

**Branch**: `native-plugin-migration`
**Current version**: `5.0.0-beta.1`

---

## Quick Fix Migration (CRITICAL)

Primary motivation for the entire native plugin migration — only 2 of 213 fixes migrated (1%).

| Status | Fix | Rule File |
|--------|-----|-----------|
| Done | `CommentOutDebugPrintFix` | `debug_rules.dart` |
| Done | `RemoveEmptySetStateFix` | `widget_lifecycle_rules.dart` |
| TODO | **211 remaining fixes** | Various `*_rules.dart` files |

**Pattern**: Migrate each `DartFix` subclass to `SaropaFixProducer`, then add to the rule's `fixGenerators` getter.

---

## IDE Integration Testing

| Test | Status | Notes |
|------|--------|-------|
| VS Code squiggles appear | TODO | Verify diagnostics show inline |
| Problems panel populated | TODO | Verify rule violations listed |
| Quick fixes appear (lightbulb) | TODO | **This is the primary motivation** — verify fixes show in VS Code |
| Quick fixes apply correctly | TODO | Verify applied fix produces correct code |
| `dart analyze` integration | TODO | Verify rules run via CLI |
| `dart fix --apply` integration | TODO | Verify bulk fix application |

---

## Regression Testing

| Test | Status | Notes |
|------|--------|-------|
| v4 vs v5 output comparison | TODO | Run both versions on same codebase, diff results |
| No false positive regressions | TODO | Same violations detected, no new false positives |
| No false negative regressions | TODO | No violations missed that v4 caught |

---

## Performance Testing

| Test | Status | Notes |
|------|--------|-------|
| Benchmark vs custom_lint | TODO | Measure analysis time on large project |
| Memory usage comparison | TODO | Profile memory consumption |
| IDE responsiveness | TODO | Measure time-to-squiggle in VS Code |

---

## Release Plan

| Milestone | Version | Status | Description |
|-----------|---------|--------|-------------|
| Dev | `5.0.0-dev.1` | Done | Infrastructure + PoC |
| Beta 1 | `5.0.0-beta.1` | Done | All rules migrated, 2 quick fixes |
| Beta 2 | `5.0.0-beta.2` | TODO | All quick fixes migrated, reporter features verified |
| Stable | `5.0.0` | TODO | After beta feedback |

---

## Documentation

| Item | Status | Notes |
|------|--------|-------|
| Migration guide (`MIGRATION_V5.md`) | Done | v4 → v5 upgrade instructions |
| v4 deprecation notice | TODO | Add to README and CHANGELOG |
| v4 security fix maintenance policy | TODO | Define support window for v4.x |
| Troubleshooting guide | TODO | Common migration issues and fixes |

---

_Created: 2026-02-16_
