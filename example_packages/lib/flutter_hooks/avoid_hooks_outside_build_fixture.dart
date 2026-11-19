// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_hooks_outside_build` lint rule.

// NOTE: avoid_hooks_outside_build requires specific framework types
// and widget/package context to trigger.
// See rule documentation for bad/good examples.

void main() {}

// GOOD: static helper whose name starts with `use` is not a hook, and this
// file does not import flutter_hooks.
class _ClaimWrite {
  static List<String> useCleanedRows(List<String> rows) => rows;
}

Future<void> _process(List<String> rows) async {
  final List<String> out = _ClaimWrite.useCleanedRows(rows);
}
