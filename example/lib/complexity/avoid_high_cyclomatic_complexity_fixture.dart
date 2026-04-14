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
