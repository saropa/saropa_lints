// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_stream_distinct` lint rule.

// NOTE: prefer_stream_distinct fires when stream.listen() callback
// contains setState() — indicating UI rebuilds on every emission.
// Requires properly typed Stream and setState context.
//
// BAD:
// stream.listen((value) {
//   setState(() => _value = value); // rebuilds even if value unchanged
// });
//
// GOOD:
// stream.distinct().listen((value) {
//   setState(() => _value = value); // only rebuilds on actual changes
// });
//
// GOOD (false-positive regression): payload-less refresh signal. Every event
// carries the same value, so .distinct() would drop all but the first and
// stop the refresh. The listener ignores its parameter, so no lint.
// prefChanged.stream.listen((_) {
//   setState(() => _reloadCounter++);
// });

void main() {}
