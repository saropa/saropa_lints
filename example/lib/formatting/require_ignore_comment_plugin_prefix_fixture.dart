// Test fixture for: require_ignore_comment_plugin_prefix
// ignore_for_file: unused_local_variable

// BAD: bare rule name targeting a saropa_lints rule — silently ineffective in IDE.

// LINT: require_ignore_comment_plugin_prefix
// ignore: avoid_null_assertion
final x1 = 1;

// LINT: require_ignore_comment_plugin_prefix
// ignore_for_file: avoid_null_assertion

// BAD: hyphenated variant of a saropa_lints rule name (also bare).

// LINT: require_ignore_comment_plugin_prefix
// ignore: avoid-null-assertion

// BAD: mixed bare and prefixed in one directive — bare entries trigger the lint.

// LINT: require_ignore_comment_plugin_prefix
// ignore: avoid_null_assertion, saropa_lints/avoid_unsafe_collection_methods

// GOOD: prefixed form — correctly suppressed in IDE.

// ignore: saropa_lints/avoid_null_assertion
final x2 = 2;

// GOOD: ignore_for_file prefixed form.

// ignore_for_file: saropa_lints/avoid_null_assertion

// GOOD: bare name targeting a non-saropa_lints rule (e.g. core analyzer lint).

// ignore: unused_import
final x3 = 3;

// GOOD: bare name that is not a known saropa_lints rule.

// ignore: some_unknown_rule_xyz
final x4 = 4;

// BAD: bare rule with trailing comment.

// LINT: require_ignore_comment_plugin_prefix
// ignore: avoid_null_assertion -- this is a false positive

void main() {}
