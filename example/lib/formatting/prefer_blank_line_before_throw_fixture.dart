// ignore_for_file: unused_element

/// Fixture for `prefer_blank_line_before_throw` lint rule.

// BAD: Should trigger prefer_blank_line_before_throw
void _bad(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    _log(trimmed);
    throw ArgumentError('empty'); // expect_lint: prefer_blank_line_before_throw
  }
}

// GOOD: Should NOT trigger prefer_blank_line_before_throw
void _good(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    _log(trimmed);

    throw ArgumentError('empty');
  }
}

void _log(Object? value) {}

// FALSE POSITIVE guard: throw as the sole/first statement in a guard clause
// must NOT trigger — there is no preceding sibling statement.
void _soleThrow(bool ok) {
  if (!ok) throw StateError('invalid');
}

// FALSE POSITIVE guard: an inline throw-expression (ternary/??), not a
// block-level throw statement, has no preceding sibling and must NOT trigger.
int _inlineThrowExpression(int? value) {
  return value ?? (throw StateError('required'));
}
