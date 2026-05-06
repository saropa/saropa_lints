# Drift rules considered not viable

**For developers:** Reference list of proposed Drift rules that were reviewed and rejected. Rationale preserved from `bugs/history/not_viable/drift/*.md` during history integration. Do not re-propose these rules.

Proposed Drift-related lint rules that were reviewed and **not** implemented. Rationale is preserved here to avoid re-proposing.

| Proposed rule | Reason not viable | Category |
|---------------|-------------------|----------|
| `avoid_drift_client_default_for_timestamps` | `clientDefault(() => DateTime.now())` vs `withDefault(currentDateAndTime)` are both valid: clientDefault = Dart runtime clock (e.g. local TZ); withDefault = SQL/canonical. Design choice, not a bug. | Design choice |
| `avoid_drift_custom_constraint_without_not_null` | customConstraint() intentionally overrides NOT NULL; power users need exact SQL. Flagging would annoy advanced users and cause false positives. | Too niche |
| `avoid_drift_downgrade` | Drift already throws on schema version downgrade. Lint would duplicate runtime protection. | Redundant — library-enforced |
| `avoid_drift_multiple_auto_increment` | SQLite/Drift codegen forbids multiple autoIncrement columns; code won't compile. | Redundant — compiler-enforced |
| `prefer_drift_modular_generation` | *.g.dart vs *.drift.dart is project preference (small vs large). No single correct pattern. | Design choice |
| `require_drift_build_runner` | Lint analyzes source at rest; cannot detect stale/missing generated files. Build either succeeds or fails. | Undetectable — build state |
| `require_drift_table_column_trailing_parens` | Missing trailing `()` on column definition is a compile error. Redundant with compiler. | Redundant — compiler-enforced |
| `require_drift_wal_mode` | drift_flutter sets WAL automatically. Requiring manually would false-positive on recommended setup. | Automatically handled |
