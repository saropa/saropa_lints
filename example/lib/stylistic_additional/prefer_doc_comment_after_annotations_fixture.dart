// ignore_for_file: unused_element, unused_field, annotate_overrides

/// Fixture for `prefer_doc_comment_after_annotations` lint rule.
///
/// BAD cases place the `///` doc comment before annotations (conventional
/// Dart style), which this rule flags because the team prefers doc comments
/// adjacent to the declaration keyword.
/// GOOD cases place the doc comment after all annotations.

class Widget {}

class _Base {
  Widget build() => Widget();
}

class _BadWidget extends _Base {
  /// Builds the widget tree. // LINT: prefer_doc_comment_after_annotations
  @override
  Widget build() => Widget();
}

class _GoodWidget extends _Base {
  @override
  /// Builds the widget tree.
  Widget build() => Widget();

  /// Doc with no annotations — nothing to reorder, not flagged.
  int plainField = 0;
}
