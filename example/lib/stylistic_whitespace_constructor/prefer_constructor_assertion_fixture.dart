// ignore_for_file: unused_element, unused_field

/// Fixture for `prefer_constructor_assertion` (opinionated opposite of factory validation).

class Positive {
  final int value;

  Positive._(this.value);

  // LINT: two-statement factory validation — assert ctor is preferred here
  factory Positive(int value) {
    if (value < 0) {
      throw ArgumentError('negative');
    }
    return Positive._(value);
  }
}

class PositiveAssert {
  final int value;

  PositiveAssert(this.value) : assert(value >= 0, 'Must be positive');
}
