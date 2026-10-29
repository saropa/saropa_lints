// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_drift_batch_operations` lint rule.

// NOTE: prefer_drift_batch_operations requires Drift framework types
// and database context to trigger.
// See rule documentation for bad/good examples.

void main() {}

// Regression (must NOT trigger):
//   await db.batch((Batch batch) {
//     for (final row in rows) { batch.insert(table, row); }
//   });
//   for (final e in entries) {
//     final n = await (db.update(t)..where((x) => x.id.equals(e.key))).write(c);
//     if (n == 0) continue;
//   }
