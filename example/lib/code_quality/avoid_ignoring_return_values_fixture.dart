// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_ignoring_return_values` lint rule.

// BAD: Should trigger avoid_ignoring_return_values
// expect_lint: avoid_ignoring_return_values
void _bad(List<int> list) {
  list.map((e) => e * 2); // Return value ignored — map result discarded
}

// GOOD: Should NOT trigger avoid_ignoring_return_values
void _good(List<int> list) {
  final doubled = list.map((e) => e * 2).toList(); // Return value used
}

// GOOD: Map mutation methods — return value is a convenience, side effect is the goal
void _goodMapMutation(Map<String, int> counts, Map<String, List<int>> grouped) {
  counts.update('key', (v) => v + 1, ifAbsent: () => 1);
  counts.putIfAbsent('other', () => 0);
  grouped.update('key', (v) => [...v, 1], ifAbsent: () => <int>[1]);
}

class _NameSpans {
  final List<String> spans = <String>[];
}

// GOOD: Project-local extension mutator matching the List.add convention —
// mutate-verb name, bool return, declared on an extension.
extension _NameTextSpanExtensions on _NameSpans {
  bool appendNamePart(String? part) {
    if (part == null || part.isEmpty) return false;
    spans.add(part);
    return true;
  }
}

void _goodExtensionMutator(_NameSpans target, String? givenName) {
  if (givenName != null && givenName.isNotEmpty) {
    target.appendNamePart(givenName); // Exempt — extension bool-mutator
  }
}

// BAD: Same mutate-verb name + bool return as appendNamePart above, but
// declared as a plain instance method (not on an extension). Proves the
// extension-only gate is load-bearing: the verb+bool shape alone is not a
// sufficient signal (a class method's bool return may be a real result the
// caller should check), so this must still lint even though it matches
// every other condition of the exemption.
class _NameBuilder {
  final List<String> parts = <String>[];

  bool appendPart(String? part) {
    if (part == null || part.isEmpty) return false;
    parts.add(part);
    return true;
  }
}

void _badNonExtensionMutator(_NameBuilder builder, String? part) {
  // expect_lint: avoid_ignoring_return_values
  builder.appendPart(part);
}
