// @dart=3.13
// Dart 3.13 primary-constructor syntax. Shared smoke fixture: every registered
// rule is run over this file (test/rules/primary_constructor_smoke_test.dart)
// to prove none crashes on the new declaration shapes. No expect_lint markers.
// ignore_for_file: unused_element, unused_field

/// Plain primary constructor, no body.
class Point(final int x, final int y);

/// Primary constructor plus a class body.
class Circle(final Point center, final int radius) {
  int get diameter => radius * 2;

  bool contains(Point p) =>
      (p.x - center.x) * (p.x - center.x) +
          (p.y - center.y) * (p.y - center.y) <=
      radius * radius;
}

/// Const primary constructor.
class const ConstPoint(final int x, final int y);

/// Named and optional parameters, defaults.
class Options({
  final String name = 'default',
  final int? retries,
  int count = 0,
});

/// Named-parameter primary constructor with required.
class Config({required final String host, required final int port}) {
  String get url => 'http://$host:$port';
}

/// Plain (non-declaring) parameter plus an extra body constructor.
class Wrapper(int seed) {
  final int doubled = seed * 2;
  Wrapper.zero() : this(0);
}

void useAll() {
  const p = ConstPoint(1, 2);
  final c = Circle(Point(0, 0), 3);
  final o = Options(name: 'a', retries: 2);
  final cfg = Config(host: 'h', port: 80);
  print('$p $c $o ${cfg.url} ${Wrapper.zero().doubled}');
}
