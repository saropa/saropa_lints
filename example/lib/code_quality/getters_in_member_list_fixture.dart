// Fixture for `getters_in_member_list`.
//
// The rule flags a plain (non-`@override`) getter declared after a regular
// method, when the class already has an earlier field/getter/setter it
// could have been grouped with instead.

class Item {
  Item(this.price);
  final double price;
}

// Order: BAD — `total` is declared after `addItem`, a regular method, even
// though `items` (a field) was declared earlier in the class.
class Order {
  Order(this.items);

  final List<Item> items;

  void addItem(Item item) {
    items.add(item);
  }

  // expect_lint: getters_in_member_list
  double get total =>
      items.fold(0, (double sum, Item i) => sum + i.price);
}

// OrderOk: GOOD — the getter is grouped with the field, before the first
// method. No lint.
class OrderOk {
  OrderOk(this.items);

  final List<Item> items;

  double get total =>
      items.fold(0, (double sum, Item i) => sum + i.price);

  void addItem(Item item) {
    items.add(item);
  }
}

// SingleGetterNoMethods: GOOD near-miss — a getter with no preceding
// method; nothing to reorder against.
class SingleGetterNoMethods {
  final int value = 1;

  int get doubled => value * 2;
}

// OverrideExempt: GOOD near-miss — the trailing getter overrides an
// interface member. Override getters are exempt so they can stay grouped
// with other overrides instead of the field block.
abstract class Labeled {
  String get label;
}

class OverrideExempt implements Labeled {
  OverrideExempt(this.name);

  final String name;

  void log() {
    // no-op
  }

  @override
  String get label => name;
}

// NoEarlierPropertyMember: GOOD near-miss — the getter trails a method, but
// there is no earlier field/getter/setter to have grouped it with, so
// nothing is flagged.
class NoEarlierPropertyMember {
  void run() {
    // no-op
  }

  int get result => 42;
}

// Status: BAD — enhanced enums can declare fields/getters/methods just like
// a class body, so the same grouping rule applies to the enum's `label`
// getter, which trails a method after an earlier field.
enum Status {
  active(1),
  inactive(0);

  const Status(this.code);

  final int code;

  void log() {
    // no-op
  }

  // expect_lint: getters_in_member_list
  String get label => code == 1 ? 'active' : 'inactive';
}

// Counter: BAD — mixin bodies carry the same field/getter/method split as a
// class, so a getter trailing `increment()` after the `count` field is the
// same readability gap.
mixin Counter {
  int count = 0;

  void increment() {
    count++;
  }

  // expect_lint: getters_in_member_list
  int get doubledCount => count * 2;
}

// NumberOps: BAD — extensions cannot declare instance fields, so the earlier
// property member is the `doubled` getter; `tripled` trails a method and
// should have been grouped with it.
extension NumberOps on int {
  int get doubled => this * 2;

  void logSelf() {
    // no-op
  }

  // expect_lint: getters_in_member_list
  int get tripled => this * 3;
}

// Meters: BAD — extension-type bodies are member lists like any other; the
// representation field aside, `feet` is the earlier property member and
// `inches` trails `log()`.
extension type Meters(int value) {
  int get feet => value * 3;

  void log() {
    // no-op
  }

  // expect_lint: getters_in_member_list
  int get inches => value * 39;
}

// FeetOk: GOOD near-miss — same extension-type shape with both getters ahead
// of the method. Nothing to reorder.
extension type FeetOk(int value) {
  int get inches => value * 12;

  int get yards => value ~/ 3;

  void log() {
    // no-op
  }
}

// MathUtils: GOOD near-miss — a static-only utility holder. The rule's
// rationale is about an instance's data shape versus its behavior, and a
// class with no instance members has neither, so `piSquared` trailing
// `square` is not flagged even though the shape mirrors the BAD cases above.
class MathUtils {
  static const double pi = 3.14;

  static double square(double x) => x * x;

  static double get piSquared => pi * pi;
}

// MixedStatics: GOOD near-miss — a static method sitting between the
// instance field and the instance getter does not start the "behavior"
// section, so the getter is still considered grouped with the field.
class MixedStatics {
  MixedStatics(this.value);

  final int value;

  static int parse(String raw) => int.parse(raw);

  int get doubled => value * 2;
}
