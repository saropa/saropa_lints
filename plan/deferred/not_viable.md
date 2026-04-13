# Not Viable: Permanently Rejected Rules

> **Last reviewed:** 2026-04-13

## Purpose

Rules in this file were **reviewed and rejected**. They will not be implemented. This list exists so contributors do not re-propose them.

---

## Drift Rules (3 rules)

| Rule | Why rejected |
|------|-------------|
| `avoid_drift_client_default_for_timestamps` | `clientDefault(() => DateTime.now())` vs `withDefault(currentDateAndTime)` are both valid design choices (Dart runtime clock vs SQL canonical). Not a bug. |
| `avoid_drift_custom_constraint_without_not_null` | `customConstraint()` intentionally overrides NOT NULL. Power users need exact SQL control. Flagging would cause false positives. |
| `require_drift_build_runner` | Lint analyzes source at rest; cannot detect stale/missing generated files. Build either succeeds or fails — no lint can help here. |

Other rejected Drift ideas (redundant with compiler/library or trivial): schema downgrade, multiple autoIncrement, trailing column `()`, WAL mode, modular generation preference.

## Roadmap Rules (11 rules)

| Rule | Why rejected |
|------|-------------|
| `avoid_any_version` | Requires YAML parsing of `pubspec.yaml`. Moved to pubspec rules — could be implemented via extension or CLI, but NOT as an analyzer plugin rule on `.dart` files. See note below. |
| `avoid_banned_api` | Configurable layer-boundary rule requires per-project config parsing from `analysis_options.yaml`. High maintenance, overlaps with `banned_usage`. |
| `avoid_connectivity_ui_decisions` | False positive rate too high. Cannot distinguish full-screen offline block (bad) from small offline indicator (fine) — identical AST: `StreamBuilder` → `if` on `ConnectivityResult` → `return widget`. |
| `avoid_dependency_overrides` | Requires reading `pubspec.yaml`. Same barrier as `avoid_any_version`. |
| `avoid_firestore_admin_role_overuse` | Cannot distinguish security enforcement (bad) from UI personalization (fine). `claims['admin']` for UI gating looks identical in both cases. |
| `avoid_large_assets_on_web` | Lint cannot read file sizes from disk. Asset paths are strings. Analyzer does not resolve to filesystem. Build-time/CI concern, not a lint. |
| `avoid_large_object_in_state` | Static analysis cannot measure runtime object size. `Uint8List` could be 16 bytes or 5 MB. DevTools memory profiler is the correct tool. |
| `avoid_pagination_refetch_all` | Detection surface too narrow. Real apps use BLoC/Riverpod/PagingController, not for-loops. Near-zero real-world detections expected. |
| `avoid_repeated_widget_creation` | Determining "identical widgets with all-const args" requires deep expression analysis. Trivial case is rare, complex case is unreliable. |
| `avoid_suspicious_global_reference` | Allowlist would not converge (Theme.of, Navigator.of, MediaQuery, GetIt, singletons, etc.). Estimated 90%+ false positive rate. |
| `avoid_unbounded_collections` | `List.add()` used everywhere. Linter cannot determine if a list "should" have a bound — that is a domain-level decision. Would flag virtually every stateful list. |

### Note on pubspec rules listed here

`avoid_any_version` and `avoid_dependency_overrides` were rejected specifically as **analyzer plugin rules** (running on `.dart` files). They could still be implemented as:
- Extension-side checks (TypeScript, reading `pubspec.yaml` directly)
- CLI commands
- A future pubspec-aware analysis path

If implemented via a non-plugin path, remove them from this file and track them as active work.

**Total: 14 rules**
