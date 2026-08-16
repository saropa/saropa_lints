// ignore_for_file: unused_element
// Fixture for avoid_high_cyclomatic_complexity.
// Rule flags functions with too many branches (high cyclomatic complexity).

void badHighComplexity(bool a, bool b, bool c, bool d, bool e) {
  if (a) {}
  if (b) {}
  if (c) {}
  if (d) {}
  if (e) {}
  switch (a) {
    case true:
      break;
    case false:
      break;
  }
}

void goodSimple(bool a) {
  if (a) {}
}

// GOOD: copyWith is excluded from the rule (standard immutable-update pattern).
// Many null-coalescing branches in a single return are mechanical, not logical.
class CardOptions {
  const CardOptions({
    this.a,
    this.b,
    this.c,
    this.d,
    this.e,
    this.f,
    this.g,
    this.h,
    this.i,
    this.j,
    this.k,
    this.l,
    this.m,
    this.n,
    this.o,
    this.p,
    this.q,
    this.r,
  });
  final int? a;
  final int? b;
  final int? c;
  final int? d;
  final int? e;
  final int? f;
  final int? g;
  final int? h;
  final int? i;
  final int? j;
  final int? k;
  final int? l;
  final int? m;
  final int? n;
  final int? o;
  final int? p;
  final int? q;
  final int? r;

  CardOptions copyWith({
    int? a,
    int? b,
    int? c,
    int? d,
    int? e,
    int? f,
    int? g,
    int? h,
    int? i,
    int? j,
    int? k,
    int? l,
    int? m,
    int? n,
    int? o,
    int? p,
    int? q,
    int? r,
  }) {
    return CardOptions(
      a: a ?? this.a,
      b: b ?? this.b,
      c: c ?? this.c,
      d: d ?? this.d,
      e: e ?? this.e,
      f: f ?? this.f,
      g: g ?? this.g,
      h: h ?? this.h,
      i: i ?? this.i,
      j: j ?? this.j,
      k: k ?? this.k,
      l: l ?? this.l,
      m: m ?? this.m,
      n: n ?? this.n,
      o: o ?? this.o,
      p: p ?? this.p,
      q: q ?? this.q,
      r: r ?? this.r,
    );
  }
}

// Enum for flat dispatch table tests (18 values for basic tests, extended
// by int-based switches for guard and outlier cases)
enum _TestEnum { v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, v16, v17, v18 }

// GOOD: Flat dispatch table — every case is a single return with no nesting.
// Complexity is mechanical (enum cardinality), not logical branching.
// 18 cases × 0.2 weight + 1.0 base = 4.6, well under threshold of 15.
String _flatSwitchLookup(_TestEnum value) {
  switch (value) {
    case _TestEnum.v1: return 'one';
    case _TestEnum.v2: return 'two';
    case _TestEnum.v3: return 'three';
    case _TestEnum.v4: return 'four';
    case _TestEnum.v5: return 'five';
    case _TestEnum.v6: return 'six';
    case _TestEnum.v7: return 'seven';
    case _TestEnum.v8: return 'eight';
    case _TestEnum.v9: return 'nine';
    case _TestEnum.v10: return 'ten';
    case _TestEnum.v11: return 'eleven';
    case _TestEnum.v12: return 'twelve';
    case _TestEnum.v13: return 'thirteen';
    case _TestEnum.v14: return 'fourteen';
    case _TestEnum.v15: return 'fifteen';
    case _TestEnum.v16: return 'sixteen';
    case _TestEnum.v17: return 'seventeen';
    case _TestEnum.v18: return 'eighteen';
  }
}

// GOOD: Flat dispatch table with a default case — still classified as flat.
// 18 cases + 1 default = 19 members × 0.2 + 1.0 = 4.8, under threshold.
String _flatSwitchWithDefault(_TestEnum value) {
  switch (value) {
    case _TestEnum.v1: return 'one';
    case _TestEnum.v2: return 'two';
    case _TestEnum.v3: return 'three';
    case _TestEnum.v4: return 'four';
    case _TestEnum.v5: return 'five';
    case _TestEnum.v6: return 'six';
    case _TestEnum.v7: return 'seven';
    case _TestEnum.v8: return 'eight';
    case _TestEnum.v9: return 'nine';
    case _TestEnum.v10: return 'ten';
    case _TestEnum.v11: return 'eleven';
    case _TestEnum.v12: return 'twelve';
    case _TestEnum.v13: return 'thirteen';
    case _TestEnum.v14: return 'fourteen';
    case _TestEnum.v15: return 'fifteen';
    case _TestEnum.v16: return 'sixteen';
    case _TestEnum.v17: return 'seventeen';
    default: return 'unknown';
  }
}

// BAD: Switch with guard clauses — guards introduce real branching, so
// the switch is NOT classified as a flat dispatch table. LINT
String _switchWithGuardClauses(int x) {
  switch (x) {
    case int v when v > 100: return 'huge';
    case int v when v > 90: return 'ninety';
    case int v when v > 80: return 'eighty';
    case int v when v > 70: return 'seventy';
    case int v when v > 60: return 'sixty';
    case int v when v > 50: return 'fifty';
    case int v when v > 40: return 'forty';
    case int v when v > 30: return 'thirty';
    case int v when v > 20: return 'twenty';
    case int v when v > 10: return 'teen';
    case int v when v > 5: return 'high';
    case int v when v > 3: return 'mid';
    case int v when v > 1: return 'low';
    case int v when v > 0: return 'one';
    case int v when v == 0: return 'zero';
    case int v when v > -10: return 'neg-low';
    default: return 'neg-high';
  }
}

// BAD: Switch with >15 cases where case bodies contain nested branching.
// This is genuine complexity — each case has internal conditional logic. LINT
String _switchWithNestedBranching(int x) {
  switch (x) {
    case 0: return x > 0 ? 'pos' : 'neg';
    case 1: return x > 0 ? 'pos' : 'neg';
    case 2: return x > 0 ? 'pos' : 'neg';
    case 3: return x > 0 ? 'pos' : 'neg';
    case 4: return x > 0 ? 'pos' : 'neg';
    case 5: return x > 0 ? 'pos' : 'neg';
    case 6: return x > 0 ? 'pos' : 'neg';
    case 7: return x > 0 ? 'pos' : 'neg';
    case 8: return x > 0 ? 'pos' : 'neg';
    case 9: return x > 0 ? 'pos' : 'neg';
    case 10: return x > 0 ? 'pos' : 'neg';
    case 11: return x > 0 ? 'pos' : 'neg';
    case 12: return x > 0 ? 'pos' : 'neg';
    case 13: return x > 0 ? 'pos' : 'neg';
    case 14: return x > 0 ? 'pos' : 'neg';
    case 15: return x > 0 ? 'pos' : 'neg';
    case 16: return x > 0 ? 'pos' : 'neg';
    default: return 'other';
  }
}
