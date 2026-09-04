// Oracle-backed tests for `getters_in_member_list`.
//
// Verifies the rule flags a plain getter declared after a regular method
// when an earlier field/getter/setter existed to group it with, and stays
// silent on: getters grouped near fields, a lone getter with nothing
// earlier to reorder against, `@override` getters, and setters (which are
// never the flagged member type). Also covers: a setter (not a field) as
// the earlier property member, an operator method counted as a behavior
// member, mixin/extension/extension-type bodies, enum bodies, static members
// being excluded from the ordering check entirely, and multiple offending
// getters each flagged independently.
library;

import 'package:saropa_lints/src/rules/code_quality/getters_in_member_list_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

const String _rule = 'getters_in_member_list';

void main() {
  group('getters_in_member_list', () {
    test('LINT: getter declared after a method, with an earlier field', () async {
      const String code = '''
class Order {
  Order(this.items);

  final List<int> items;

  void addItem(int item) {
    items.add(item);
  }

  double get total => items.fold(0, (sum, i) => sum + i);
}
''';
      final codes = await reportedRuleCodes(GettersInMemberListRule(), code);
      expect(codes, contains(_rule));
    });

    test('NO lint: getter grouped with the field before the first method', () async {
      const String code = '''
class Order {
  Order(this.items);

  final List<int> items;

  double get total => items.fold(0, (sum, i) => sum + i);

  void addItem(int item) {
    items.add(item);
  }
}
''';
      final codes = await reportedRuleCodes(GettersInMemberListRule(), code);
      expect(codes, isNot(contains(_rule)));
    });

    test('NO lint: lone getter with no preceding method', () async {
      const String code = '''
class Value {
  final int value = 1;

  int get doubled => value * 2;
}
''';
      final codes = await reportedRuleCodes(GettersInMemberListRule(), code);
      expect(codes, isNot(contains(_rule)));
    });

    test('NO lint: getter trails a method but nothing earlier to group with', () async {
      const String code = '''
class NoEarlierProperty {
  void run() {}

  int get result => 42;
}
''';
      final codes = await reportedRuleCodes(GettersInMemberListRule(), code);
      expect(codes, isNot(contains(_rule)));
    });

    test('NO lint: @override getter is exempt even after a method', () async {
      const String code = '''
abstract class Labeled {
  String get label;
}

class OverrideExempt implements Labeled {
  OverrideExempt(this.name);

  final String name;

  void log() {}

  @override
  String get label => name;
}
''';
      final codes = await reportedRuleCodes(GettersInMemberListRule(), code);
      expect(codes, isNot(contains(_rule)));
    });

    test('LINT: setter (not a field) counts as the earlier property member', () async {
      const String code = '''
class Box {
  int _value = 0;

  set value(int v) {
    _value = v;
  }

  void reset() {
    _value = 0;
  }

  int get value => _value;
}
''';
      final codes = await reportedRuleCodes(GettersInMemberListRule(), code);
      expect(codes, contains(_rule));
    });

    test('LINT: operator method counts as a behavior member', () async {
      const String code = '''
class Vector {
  Vector(this.x);

  final int x;

  Vector operator +(Vector other) => Vector(x + other.x);

  int get doubled => x * 2;
}
''';
      final codes = await reportedRuleCodes(GettersInMemberListRule(), code);
      expect(codes, contains(_rule));
    });

    test('LINT: mixin body applies the same grouping rule', () async {
      const String code = '''
mixin Counter {
  int count = 0;

  void increment() {
    count++;
  }

  int get doubledCount => count * 2;
}
''';
      final codes = await reportedRuleCodes(GettersInMemberListRule(), code);
      expect(codes, contains(_rule));
    });

    // Extensions cannot declare instance fields, so the earlier property
    // member here has to be an instance getter — a `static const` no longer
    // counts (statics are excluded from the ordering check).
    test('LINT: extension body applies the same grouping rule', () async {
      const String code = '''
extension NumberOps on int {
  int get doubled => this * 2;

  void logSelf() {}

  int get tripled => this * 3;
}
''';
      final codes = await reportedRuleCodes(GettersInMemberListRule(), code);
      expect(codes, contains(_rule));
    });

    // Extension types were a registered node kind with zero coverage. Like
    // extensions they have no instance fields, so the leading instance
    // getter is what the trailing getter should have been grouped with.
    test('LINT: extension type body applies the same grouping rule', () async {
      const String code = '''
extension type Meters(int value) {
  int get feet => value * 3;

  void log() {}

  int get inches => value * 39;
}
''';
      final codes = await reportedRuleCodes(GettersInMemberListRule(), code);
      expect(codes, contains(_rule));
    });

    // Negative half of the extension-type pair: same body, getters grouped
    // ahead of the method, so the shim path is exercised without reporting.
    test('NO lint: extension type with getters grouped before the method', () async {
      const String code = '''
extension type Feet(int value) {
  int get inches => value * 12;

  int get yards => value ~/ 3;

  void log() {}
}
''';
      final codes = await reportedRuleCodes(GettersInMemberListRule(), code);
      expect(codes, isNot(contains(_rule)));
    });

    // The documented static false positive, now fixed: a static-only utility
    // holder has no instance data shape, so the ordering convention does not
    // apply and nothing is reported.
    test('NO lint: static-only utility class is exempt', () async {
      const String code = '''
class MathUtils {
  static const double pi = 3.14;

  static double square(double x) => x * x;

  static double get piSquared => pi * pi;
}
''';
      final codes = await reportedRuleCodes(GettersInMemberListRule(), code);
      expect(codes, isNot(contains(_rule)));
    });

    // A static method in the middle of an instance body must not count as
    // the "behavior member" that makes the following instance getter late.
    test('NO lint: static method does not start the behavior section', () async {
      const String code = '''
class Mixed {
  Mixed(this.value);

  final int value;

  static int parse(String raw) => int.parse(raw);

  int get doubled => value * 2;
}
''';
      final codes = await reportedRuleCodes(GettersInMemberListRule(), code);
      expect(codes, isNot(contains(_rule)));
    });

    test('LINT: enum body applies the same grouping rule', () async {
      const String code = '''
enum Status {
  active(1),
  inactive(0);

  const Status(this.code);

  final int code;

  void log() {}

  String get label => code == 1 ? 'active' : 'inactive';
}
''';
      final codes = await reportedRuleCodes(GettersInMemberListRule(), code);
      expect(codes, contains(_rule));
    });

    test('LINT: multiple offending getters are each flagged independently', () async {
      const String code = '''
class Multi {
  Multi(this.value);

  final int value;

  void log() {}

  int get first => value;

  int get second => value * 2;
}
''';
      final diags = await runRuleResolved(GettersInMemberListRule(), code);
      final matches = diags.where((d) => d.ruleName == _rule).toList();
      expect(matches, hasLength(2));
    });
  });

  // Rule Instantiation: metadata smoke test.
  group('getters_in_member_list - Rule Instantiation', () {
    test('GettersInMemberListRule', () {
      final rule = GettersInMemberListRule();
      expect(rule.code.lowerCaseName, _rule);
      expect(rule.code.problemMessage, contains('[$_rule]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });
}
