// Fixture for avoid_drift_insert_missing_conflict_target
// ignore_for_file: unused_local_variable, unused_element, depend_on_referenced_packages

// This fixture requires real Drift framework context (imports
// package:drift/drift.dart, real @TableIndex(unique: true) metadata, and
// generated $XxxTable helpers). It exists as a stub matching the other
// drift_rules fixtures in this directory. End-to-end triggering is exercised
// in the consuming Saropa contacts project, which is where this hazard was
// first observed (see bugs/infra_new_rule_drift_insert_missing_conflict_target.md).

// Bad examples (SHOULD trigger):
// - batch.insert(db.contactPoints, row)                   — no onConflict
// - batch.insertAll(db.contactPoints, rows)               — no onConflict
// - db.into(db.contactPoints).insert(row)                 — no onConflict
// - db.contactPoints.insertOnConflictUpdate(row)          — defaults to PK
// - batch.insert(db.contactPoints, row,                    — target references
//     onConflict: DoUpdate((_) => row, target: [db.contactPoints.id]))
//     a column that does NOT cover the UNIQUE index
void badExamples() {}

// Good examples (should NOT trigger):
// - batch.insert(db.contactPoints, row,
//     onConflict: DoUpdate((_) => row, target: [db.contactPoints.uuid]))
// - batch.insert(db.contactPoints, row,
//     onConflict: DoUpdate.withExcluded((_, __) => row,
//       target: [db.contactPoints.uuid]))
// - db.into(db.contactPoints).insert(row, mode: InsertMode.replace)
// - batch.insert(db.plainTable, row)                      — no UNIQUE index
void goodExamples() {}
