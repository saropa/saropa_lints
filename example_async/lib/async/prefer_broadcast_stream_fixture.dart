// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_broadcast_stream` lint rule.

// BAD: Should trigger prefer_broadcast_stream
void _bad() {
  final stream = Stream<int>.empty();
  // expect_lint: prefer_broadcast_stream
  stream.listen((_) {}); // first listen
  stream.listen((_) {}); // second listen — error at runtime
}

// GOOD: Should NOT trigger prefer_broadcast_stream
void _good() {
  final stream = Stream<int>.empty();
  stream.listen((_) {}); // single listener — OK
}

void main() {}
