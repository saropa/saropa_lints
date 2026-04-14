# BUG: `stale-override` — False positive when override resolves SDK-pinned transitive constraint

**Status: Closed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-04-14
Rule: `stale-override` (Package Vibrancy VS Code extension diagnostic)
File: `extension/src/vibrancy/scoring/override-analyzer.ts` (line ~91–97)
Severity: False positive
Rule version: Extension v10.12.2

---

## Summary

Package Vibrancy reports `stale-override` for `meta: 1.18.0` in `dependency_overrides`, claiming "No version conflict detected for meta — remove from dependency_overrides if unneeded." The override is **not** stale — it resolves a real conflict where `flutter_test` (SDK package) hard-pins `meta` to `1.17.0` but `analyzer ^12.0.0` (required by `drift_dev`, `saropa_lints`, `dart_style`) requires `meta ^1.18.0`. Removing it breaks `flutter pub get`.

---

## Reproducer

Any Flutter project on stable 3.41.6 that:

1. Uses `flutter_test` (from SDK) — pins `meta: 1.17.0` exactly
2. Depends on `analyzer >=12.0.0` (via `drift_dev`, `saropa_lints >=10.3.0`, or `dart_style >=3.1.8`)
3. Adds `meta: 1.18.0` to `dependency_overrides` to resolve the conflict

```yaml
# pubspec.yaml (excerpt)
dev_dependencies:
  flutter_test:
    sdk: flutter
  drift_dev: ^2.26.0       # requires analyzer ^12 → requires meta ^1.18.0
  saropa_lints: ^10.3.0     # requires analyzer ^12 → requires meta ^1.18.0

dependency_overrides:
  meta: 1.18.0   # ← Package Vibrancy flags this as stale-override
```

Without the override, `flutter pub get` fails:

```
Because every version of flutter_test from sdk depends on meta 1.17.0
  and analyzer >=12.0.0 depends on meta ^1.18.0,
  flutter_test from sdk is incompatible with analyzer >=12.0.0.
```

**Frequency:** Always — any project matching the above pattern.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No `stale-override` diagnostic — the override resolves a real transitive conflict |
| **Actual** | `[stale-override] No version conflict detected for meta — remove from dependency_overrides if unneeded.` reported at line 802 in pubspec.yaml |

---

## Root Cause

The conflict detection in `analyzeOverrides` calls `findConflict()` which calls `findTransitiveConstraint()` to determine whether the override resolves a real version conflict. **`findTransitiveConstraint` is a stub that always returns `null`** (lines 91–97):

```ts
// override-analyzer.ts lines 91-97
function findTransitiveConstraint(
    _parentName: string,
    _depName: string,
    _depGraph: Map<string, DepGraphPackage>,
): string | null {
    return null;  // ← ALWAYS returns null — no transitive constraint detection
}
```

Because `findTransitiveConstraint` always returns `null`, `findConflict` never finds a constraint that the overridden version fails to satisfy, so it returns `null` (no conflict). The override is then classified as `stale`.

The `meta` override resolves a **SDK-pinned transitive constraint** — `flutter_test` (sdk: flutter) hard-pins `meta: 1.17.0`, but `analyzer ^12` (a transitive dependency of `drift_dev`, `saropa_lints`, and `dart_style`) requires `meta ^1.18.0`. This is a real conflict that only exists because of the SDK pin, and `findConflict` has no mechanism to detect it.

### Secondary issue: SDK constraints are invisible to the dep graph

Even if `findTransitiveConstraint` were implemented, SDK packages like `flutter_test` have their constraints resolved by the Flutter SDK itself, not by pub. The dep graph built from `flutter pub deps` may not expose the exact `meta: 1.17.0` pin that `flutter_test` imposes. The conflict detection logic would need to either:

1. Parse the SDK package's `pubspec.yaml` directly (at `<flutter_root>/packages/flutter_test/pubspec.yaml`)
2. Try `flutter pub get` without the override and detect the resolution failure
3. Check the lock file for the package's resolved version and compare against the overridden version — if they differ, the override is doing something

---

## Suggested Fix

### Option A: Implement `findTransitiveConstraint` (full fix)

Parse the full dependency graph constraints to detect when an override resolves a version conflict between transitive dependencies. This is the correct long-term solution but requires access to constraint ranges from the lock file or `flutter pub deps --json`.

### Option B: Lock-file heuristic (simpler, catches this case)

Before classifying an override as `stale`, check whether the overridden version differs from what the lock file would resolve without the override. If we can't determine that, check whether the overridden package's version matches the constraint from the dep graph — if the overridden version is **newer** than what the graph would naturally resolve, assume the override is active.

Concretely: if the dep graph shows `meta` resolving to `1.17.0` (from flutter_test) but the override forces `1.18.0`, the versions differ → override is active.

### Option C: Known-issues entry (workaround)

Add `meta` to `known_issues.json` with an `overrideReason` field. The `applyKnownOverrideReasons` function in `override-runner.ts` already flips stale → active for known override reasons. This works but doesn't fix the general case.

```json
{
  "name": "meta",
  "status": "sdk-conflict",
  "reason": "flutter_test SDK pin conflicts with analyzer ^12",
  "overrideReason": "Flutter SDK pins meta to 1.17.0; analyzer ^12 requires ^1.18.0",
  "as_of": "2026-04-14"
}
```

### Option D: Pub-resolution probe (most robust)

Before emitting `stale-override`, run a dry-run `dart pub get --dry-run` with the override removed (or parse the output of `dart pub outdated --json`). If it fails, the override is active. This is slow but accurate.

---

## Fixture Gap

### `override-analyzer.test.ts`

Missing test cases:

1. **Transitive SDK conflict** — override resolves a conflict where an SDK package pins one version but a non-SDK transitive dependency requires a higher version. Expect status: `active`.
2. **Version-only override that resolves transitive conflict** — override specifies a bare version (not path/git) that is needed for resolution. Expect status: `active`. Currently: `stale` because `findTransitiveConstraint` is a no-op.

---

## Environment

- saropa_lints extension version: 10.12.2
- Dart SDK version: 3.11.4
- Flutter SDK version: 3.41.6 (stable)
- custom_lint version: N/A (Package Vibrancy is the VS Code extension, not custom_lint)
- Triggering project: `d:\src\contacts` (Flutter app with Drift migration in progress)
- Override: `meta: 1.18.0` in both `pubspec.yaml` dependency_overrides and `pubspec_overrides.yaml`
- Conflict chain: `flutter_test` → `meta: 1.17.0` (SDK pin) vs `drift_dev` → `analyzer ^12` → `meta ^1.18.0`
