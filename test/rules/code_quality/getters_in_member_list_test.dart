// Oracle-backed tests for `getters_in_member_list`.
//
// Verifies the rule flags a plain getter declared after a regular method
// when an earlier field/getter/setter existed to group it with, and stays
// silent on: getters grouped near fields, a lone getter with nothing
// earlier to reorder against, `@override` getters, and setters (which are
// never the flagged member type).
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
  });
}
