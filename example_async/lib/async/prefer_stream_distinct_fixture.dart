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

void main() {}
