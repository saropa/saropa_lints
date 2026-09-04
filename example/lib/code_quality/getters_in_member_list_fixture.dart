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
