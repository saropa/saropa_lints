// Test fixture for: avoid_unnecessary_factory_constructor
// Source: lib/src/rules/code_quality/unnecessary_code_rules.dart

// BAD: factory body is a single unconditional forward to a plain
// constructor of the same class — the factory keyword adds nothing here.
class Point {
  Point(this.x, this.y);
  final double x;
  final double y;

  // expect_lint: avoid_unnecessary_factory_constructor
  factory Point.origin() {
    return Point(0, 0);
  }
}

// BAD: same unnecessary-forward shape, but written as an expression body.
class Padding {
  Padding(this.amount);
  final double amount;

  // expect_lint: avoid_unnecessary_factory_constructor
  factory Padding.zero() => Padding(0);
}

// GOOD: redirecting constructor instead of factory — nothing to flag.
class GoodPoint {
  GoodPoint(this.x, this.y);
  final double x;
  final double y;

  GoodPoint.origin() : this(0, 0);
}

// GOOD: genuine factory — branches between multiple construction paths,
// so the factory keyword is doing real work.
abstract class Shape {
  factory Shape.fromType(String type) {
    if (type == 'circle') {
      return Circle();
    }
    return Rectangle();
  }
}

class Circle implements Shape {}

class Rectangle implements Shape {}

// GOOD: caching factory — returns a cached static field, not a fresh
// InstanceCreationExpression, so this is a legitimate use of factory.
class Singleton {
  Singleton._();
  static final Singleton _instance = Singleton._();

  factory Singleton() => _instance;
}

// GOOD: factory forwards to a DIFFERENT class's constructor (subtype
// dispatch) — not a same-class forward, so nothing to flag.
class Logger {
  factory Logger() {
    return ConsoleLogger();
  }
}

class ConsoleLogger implements Logger {}
