// Fixture for require_named_for_acronym_drift_columns
// ignore_for_file: unused_local_variable, unused_element, depend_on_referenced_packages

// This fixture requires real Drift framework context (imports
// package:drift/drift.dart and a `class X extends Table` with column-builder
// getters). It exists as a stub matching the other drift_rules fixtures in this
// directory; example_packages does not depend on package:drift, so the rule's
// import gate keeps it silent here. End-to-end triggering is exercised in the
// consuming Saropa Contacts project, where the hazard was first observed (see
// plans/history/2026.06/2026.06.24/feature_lint_rule_require_named_for_acronym_drift_columns.md).

// Bad examples (SHOULD trigger):
// - TextColumn get contactSaropaUUID => text()();          — acronym UUID, no .named()
// - TextColumn get youTubeAPIId => text()();               — acronym API, no .named()
// - TextColumn get contactSaropaUUIDs => text()();         — plural after acronym, no .named()
// - TextColumn get contactSaropaUUID =>                    — chain-order independence:
//     text().nullable()();                                   .nullable() present, .named() absent
void badExamples() {}

// Good examples (should NOT trigger):
// - TextColumn get contactSaropaUUID =>
//     text().named('contact_saropa_uuid')();               — pinned SQL name
// - TextColumn get displayName => text()();                — no acronym run
// - String get contactSaropaUUID => _value;                — not a Drift column builder
// - acronym getter in a class that does NOT extend Table   — not a Drift table
void goodExamples() {}
