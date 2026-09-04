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

// ThisShorthandOk: GOOD — `this.x` shorthand fills one field directly (never
// appears as a ConstructorFieldInitializer), and the remaining two explicit
// initializer-list entries (`y`, `z`) are in declaration order. The
// shorthand field's position must not taint the comparison of the rest.
class ThisShorthandOk {
  ThisShorthandOk(this.x, int b, int c) : y = b, z = c;

  final int x;
  final int y;
  final int z;
}

// ThisShorthandBad: BAD — `this.x` shorthand fills the first field, but the
// two explicit initializer-list entries (`z`, `y`) are reversed relative to
// their declaration order.
class ThisShorthandBad {
  ThisShorthandBad(this.x, int b, int c)
      // expect_lint: initializers_ordering
      : z = c,
        y = b;

  final int x;
  final int y;
  final int z;
}

// EnumBad: BAD — an enum's const constructor initializer list can be
// out of order too; `label` (2nd field) assigned before `code` (1st field).
enum EnumBad {
  a(1, 'one'),
  b(2, 'two');

  const EnumBad(int code, String label)
      // expect_lint: initializers_ordering
      : label = label,
        code = code;

  final int code;
  final String label;
}

// EnumOk: GOOD near-miss — same shape as EnumBad but correctly ordered, so
// enum constructors are not flagged just for existing.
enum EnumOk {
  a(1, 'one'),
  b(2, 'two');

  const EnumOk(int code, String label) : code = code, label = label;

  final int code;
  final String label;
}
