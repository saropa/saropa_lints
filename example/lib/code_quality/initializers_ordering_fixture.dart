// Fixture for `initializers_ordering`.
//
// The rule flags a constructor initializer list whose
// `ConstructorFieldInitializer` entries (`: field = expr`) are ordered
// differently from the corresponding field declarations in the enclosing
// class body. `assert(...)` and `super(...)`/`this(...)` redirects are
// excluded from the comparison.
//
// REPORTING CONVENTION (load-bearing for markers and for any future quick
// fix): the diagnostic is reported on the SECOND entry of the first
// out-of-order pair — the entry whose field-declaration index is lower than
// its predecessor's — never on the first entry. Every `// expect_lint:` marker
// below therefore sits immediately above that second entry. Markers that drift
// off that node are silently tolerated by CI (the expect_lint machinery only
// checks the string appears somewhere in the file, never the line), so they
// must be kept correct by hand; the line-number assertions in
// test/rules/code_quality/initializers_ordering_test.dart are the actual
// guard.

// Point: BAD — assigns `y` before `x`, but `x` is declared first in the class
// body. The rule reports the SECOND entry of the out-of-order pair (`x = a`),
// not the first: it walks the declaration-index sequence and flags the entry
// whose index regresses below its predecessor. Indices here are [y=1, x=0], so
// the regression is detected at `x = a` — hence the marker sits above that
// line, and any future quick fix must target `x = a` as its node.
class Point {
  Point(int a, int b)
      : y = b,
        // expect_lint: initializers_ordering
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

// ThreeFields: BAD — `c` (3rd field) is assigned before `b` (2nd field), a
// regression partway through the list. Declaration indices are [a=0, c=2,
// b=1]; the first regression is at the THIRD entry (1 < 2), so the reported
// node is `b = b` — the second entry of the offending pair, not `c = c`.
class ThreeFields {
  ThreeFields(int a, int b, int c)
      : a = a,
        c = c,
        // expect_lint: initializers_ordering
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
// their declaration order. Indices [z=2, y=1] regress at the second entry, so
// the diagnostic lands on `y = b` (the shorthand parameter is not a
// ConstructorFieldInitializer and never enters the comparison at all).
class ThisShorthandBad {
  ThisShorthandBad(this.x, int b, int c)
      : z = c,
        // expect_lint: initializers_ordering
        y = b;

  final int x;
  final int y;
  final int z;
}

// EnumBad: BAD — an enum's const constructor initializer list can be
// out of order too; `label` (2nd field) assigned before `code` (1st field).
// Indices [label=1, code=0] regress at the second entry, so `code = code` is
// the reported node.
enum EnumBad {
  a(1, 'one'),
  b(2, 'two');

  const EnumBad(int code, String label)
      : label = label,
        // expect_lint: initializers_ordering
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
