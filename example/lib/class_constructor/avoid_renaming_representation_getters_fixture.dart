// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_renaming_representation_getters` lint rule.
///
/// BAD: Extension type with a getter that returns the representation type
/// under a different name (renames the representation getter).
/// GOOD: No such getter, or getter name matches representation field.

// LINT: avoid_renaming_representation_getters — getter "value" renames representation "id"
extension type BadUserId(int id) {
  int get value => id;
}

// OK: No extra getter; representation name used directly
extension type GoodUserId(int id) {}

// OK: Private representation + exactly one public getter (allowed; no conflict with prefer_private_extension_type_field)
extension type GoodPrivateSingleGetter(String _sql) {
  String get sql => _sql;
}
