// ignore_for_file: unused_element, unused_field, annotate_overrides

/// Fixture for `always_put_doc_comments_before_annotations` lint rule.
///
/// BAD cases place the `///` doc comment after (or between) annotations,
/// where dartdoc can no longer associate it with the declaration. GOOD
/// cases keep the doc comment above every annotation.

class Widget {}

class _Base {
  Widget build() => Widget();
}

class _BadWidget extends _Base {
  @override
  /// Builds the widget tree. // LINT: always_put_doc_comments_before_annotations
  Widget build() => Widget();

  @Deprecated('kept for migration')
  /// Doc sits between the annotations below, not above all of them. // LINT: always_put_doc_comments_before_annotations
  @pragma('vm:prefer-inline')
  void legacyMethod() {}
}

class _GoodWidget extends _Base {
  /// Builds the widget tree.
  @override
  Widget build() => Widget();

  /// Doc with no annotations at all — nothing to reorder.
  int plainField = 0;

  @override
  // A plain `//` comment (not `///`) is never dartdoc-recognized regardless
  // of position, so this is not flagged even though it sits after @override.
  Widget build2() => Widget();
}
