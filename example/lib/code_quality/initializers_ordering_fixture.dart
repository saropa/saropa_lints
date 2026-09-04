// Fixture for `initializers_ordering`.
//
// The rule flags a constructor initializer list whose
// `ConstructorFieldInitializer` entries (`: field = expr`) are ordered
// differently from the corresponding field declarations in the enclosing
// class body. `assert(...)` and `super(...)`/`this(...)` redirects are
// excluded from the comparison.

// Point: BAD entry point below assigns `y` before `x`, but `x` is declared
// first in the class body.
class Point {
  Point(int a, int b)
      // expect_lint: initializers_ordering
      : y = b,
        x = a;

  final int x;
  final int y;
}

// PointOk: initializer-list order matches declaration order — no lint.
class PointOk {
  PointOk(int a, int b) : x = a, y = b;

  final int x;
  final int y;
}

// ThreeFields: BAD — `c` (3rd field) is assigned before `b` (2nd field),
// a regression partway through the list.
class ThreeFields {
  ThreeFields(int a, int b, int c)
      : a = a,
        // expect_lint: initializers_ordering
        c = c,
        b = b;

  final int a;
  final int b;
  final int c;
}

// AssertBetween: GOOD near-miss — an `assert(...)` sits between two field
// initializers that are themselves correctly ordered. asserts are not a
// field-declaration-order concept and must not be counted or cause a false
// positive.
class AssertBetween {
  AssertBetween(int a, int b)
      : assert(a >= 0),
        x = a,
        assert(b >= 0),
        y = b;

  final int x;
  final int y;
}

// RedirectingSuper: GOOD near-miss — a `super(...)` call plus field
// initializers in matching order. The redirect must be excluded from the
// ordering comparison entirely.
class Base {
  Base(this.label);
  final String label;
}

class RedirectingSuper extends Base {
  RedirectingSuper(int a, int b, String label)
      : x = a,
        y = b,
        super(label);

  final int x;
  final int y;
}

// SingleInitializer: GOOD near-miss — only one field initializer, so there
// is nothing to compare; must never be flagged (rule requires >= 2 entries).
class SingleInitializer {
  SingleInitializer(int a) : x = a;

  final int x;
  final int y = 0;
}
