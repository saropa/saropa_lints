// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier

/// Fixture for `check_mounted_after_async` lint rule.

Future<void> _fetch() async {}

// BAD: Should trigger check_mounted_after_async
Future<void> _bad() async {
  await _fetch();
  // expect_lint: check_mounted_after_async
  setState(() {}); // setState after await — no mounted check
}

// GOOD: Should NOT trigger check_mounted_after_async
Future<void> _good() async {
  await _fetch();
  if (!mounted) return;
  setState(() {}); // mounted check before setState
}

void main() {}
