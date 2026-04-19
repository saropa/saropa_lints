// ignore_for_file: unused_element

/// Fixture for `deprecated_new_in_comment_reference` lint rule.
/// Quick fix: Strip `new ` from `[new Foo]` doc references.

// BAD: doc reference uses deprecated `new` keyword.
/// Builds a widget via [new Widget].
// expect_lint: deprecated_new_in_comment_reference
class _WidgetBad {}

// GOOD: modern reference without `new`.
/// Builds a widget via [Widget].
class _WidgetGood {}
