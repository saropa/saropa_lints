# BUG: `analyzer` — saropa_lints >=10.3.0 unusable by Flutter projects on stable SDK

**Status: Fix Ready**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-04-15
Rule: N/A (infrastructure / dependency resolution)
File: `pubspec.yaml` (line ~65, `analyzer: ^12.0.0`)
Severity: Critical
Rule version: N/A | Since: v10.3.0 | Updated: v11.1.1

---

## Summary

Any Flutter project on the current stable SDK (3.41.6 / Dart 3.11.4) cannot resolve `saropa_lints >=10.3.0` because `analyzer ^12.0.0` transitively requires `meta ^1.18.0`, but the Flutter SDK pins `meta` to `1.17.0`. This blocks every Flutter consumer from using saropa_lints 10.3.0 through 11.1.1.

---

## Reproducer

In any Flutter project with the current stable SDK:

```yaml
# pubspec.yaml
environment:
  sdk: ^3.11.4

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
  saropa_lints: ^11.1.0
```

```
$ flutter pub get

Because saropa_lints >=10.3.0 depends on analyzer ^12.0.0 which depends on meta ^1.18.0,
  saropa_lints >=10.3.0 requires meta ^1.18.0.
And because every version of flutter from sdk depends on meta 1.17.0,
  saropa_lints >=10.3.0 is incompatible with flutter from sdk.
So, because saropa_bangers depends on both flutter from sdk and saropa_lints ^11.1.0,
  version solving failed.
```

Note: removing `flutter_test` does not help — the `flutter` SDK dependency itself pins `meta 1.17.0`.

**Frequency:** Always — affects every Flutter project on stable SDK 3.41.6.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | `saropa_lints ^11.1.0` resolves in Flutter projects on current stable SDK |
| **Actual** | Version solving fails due to `meta` version conflict between `analyzer 12.x` and Flutter SDK |

---

## Root Cause

The dependency chain is:

```
saropa_lints >=10.3.0
  └─ analyzer ^12.0.0
       └─ meta ^1.18.0    ← requires 1.18.x

flutter (SDK)
  └─ meta 1.17.0           ← pinned, immovable
```

Flutter's SDK pins `meta` to a specific version that cannot be overridden by dependency_overrides (it is a vendored SDK package). The `analyzer` package (published by the Dart team) moved to `meta ^1.18.0` in version 12.0.0, ahead of what Flutter stable ships.

`saropa_lints` adopted `analyzer 12.x` in v10.3.0 because of breaking API changes documented in the pubspec:
- `lowerCaseName` is now native on DiagnosticCode/LintCode (shims removed)
- `LibraryIdentifier` replaced by `DottedName` in the AST
- `RuleVisitorRegistry` added/removed visitor methods (~500 call sites migrated)

Rolling back to `analyzer 11.x` would require re-adding compatibility shims, dual AST node handling, and dual visitor interfaces across 70+ rule files.

---

## Impact

- **pub.dev consumers:** Anyone adding `saropa_lints: ^11.1.0` (or any `>=10.3.0`) to a Flutter project on stable cannot resolve dependencies. The pub solver suggests downgrading to `^10.2.2`.
- **saropa_bangers:** Blocked from upgrading past `saropa_lints 10.2.x`.
- **Other Saropa Flutter projects:** Same constraint applies to all Flutter consumers.

---

## Options

### Option A: Wait for Flutter stable to bump `meta`

No code change needed. When a new Flutter stable ships `meta 1.18.x`, the conflict resolves automatically. Downside: no timeline, and all Flutter consumers are blocked until then.

### Option B: Maintain a parallel 10.x branch for Flutter consumers

Keep `10.x` alive with `analyzer 11.x` compatibility for Flutter projects, while `11.x` continues for pure Dart consumers. Downside: doubles maintenance burden across 70+ rule files.

### Option C: Widen `analyzer` constraint to accept 11.x OR 12.x

If `analyzer 11.x` works with `meta 1.17.0`, a constraint like `analyzer: ">=11.0.0 <13.0.0"` would let the pub solver pick whichever version fits. Downside: the pubspec documents breaking API changes between analyzer 11 and 12 that required ~500 call-site migrations — this is not feasible without dual-version shims.

### Option D: Publish advisory / README warning

Document the incompatibility on pub.dev and in the README so Flutter users know to pin `^10.2.2`. Does not fix the problem but prevents confusion.

---

## Suggested Fix

Option A (wait) + Option D (document) is the lowest-effort path. Publish a note in the README and CHANGELOG that `saropa_lints >=10.3.0` requires a Flutter SDK that ships `meta >=1.18.0`, and that Flutter stable consumers should use `^10.2.2` until Flutter catches up.

If the gap persists through multiple Flutter stable releases, Option B (parallel branch) becomes necessary.

---

## Environment

- saropa_lints version: 11.1.1
- Dart SDK version: 3.11.4
- Flutter SDK version: 3.41.6
- Flutter `meta` pin: 1.17.0
- `analyzer` resolved version: 12.0.0
- `analyzer` required `meta`: ^1.18.0
- Triggering project: saropa_bangers (d:\src\saropa_bangers)
