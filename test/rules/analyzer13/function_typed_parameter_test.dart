// Analyzer 13 folded function-typed parameters (`bool cb()`) into
// RegularFormalParameter, whose `.type` is then the RETURN type. Rules that
// read the parameter type must not treat `bool cb()` as a `bool` parameter.
// Each case has a plain-parameter control that proves the rule still fires.
library;

import 'package:saropa_lints/src/rules/code_quality/code_quality_avoid_rules.dart';
import 'package:saropa_lints/src/rules/code_quality/code_quality_prefer_rules.dart';
import 'package:saropa_lints/src/rules/core/async_rules.dart';
import 'package:saropa_lints/src/rules/core/naming_style_rules.dart';
import 'package:saropa_lints/src/rules/data/type_rules.dart';
import 'package:saropa_lints/src/rules/stylistic/stylistic_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  group('function-typed parameters are not typed-as-return-type', () {
    test('prefer_named_bool_params ignores `bool cb()`', () async {
      final rule = PreferNamedBoolParamsRule();
      expect(
        await reportedRuleCodes(rule, 'class A {\n  void f(bool cb()) {}\n}\n'),
        isNot(contains('prefer_named_bool_params')),
      );
      expect(
        await reportedRuleCodes(rule, 'class A {\n  void f(bool flag) {}\n}\n'),
        contains('prefer_named_bool_params'),
      );
    });

    test('avoid_positional_boolean_parameters ignores `bool cb()`', () async {
      final rule = AvoidPositionalBooleanParametersRule();
      const code = 'avoid_positional_boolean_parameters_with_fix';
      expect(
        await reportedRuleCodes(rule, 'class A {\n  void f(bool cb()) {}\n}\n'),
        isNot(contains(code)),
      );
      expect(
        await reportedRuleCodes(rule, 'class A {\n  void f(bool flag) {}\n}\n'),
        contains(code),
      );
    });

    test('avoid_types_on_closure_parameters ignores `int cb(int x)`', () async {
      final rule = AvoidTypesOnClosureParametersRule();
      const code = 'avoid_types_on_closure_parameters_with_fix';
      expect(
        await reportedRuleCodes(rule, 'final f = (int cb(int x)) => cb(1);\n'),
        isNot(contains(code)),
      );
      expect(
        await reportedRuleCodes(rule, 'final f = (int x) => x;\n'),
        contains(code),
      );
    });

    test('prefer_descriptive_bool_names ignores `bool x()`', () async {
      final rule = PreferDescriptiveBoolNamesRule();
      expect(
        await reportedRuleCodes(rule, 'void f(bool thing()) {}\n'),
        isNot(contains('prefer_descriptive_bool_names')),
      );
      expect(
        await reportedRuleCodes(rule, 'void f(bool thing) {}\n'),
        contains('prefer_descriptive_bool_names'),
      );
    });

    test('prefer_descriptive_bool_names_strict ignores `bool x()`', () async {
      final rule = PreferDescriptiveBoolNamesStrictRule();
      expect(
        await reportedRuleCodes(rule, 'void f(bool thing()) {}\n'),
        isNot(contains('prefer_descriptive_bool_names_strict')),
      );
    });

    test('prefer_boolean_prefixes_for_params ignores `bool x()`', () async {
      final rule = PreferBooleanPrefixesForParamsRule();
      expect(
        await reportedRuleCodes(rule, 'void f(bool thing()) {}\n'),
        isNot(contains('prefer_boolean_prefixes_for_params')),
      );
      expect(
        await reportedRuleCodes(rule, 'void f(bool thing) {}\n'),
        contains('prefer_boolean_prefixes_for_params'),
      );
    });

    test('prefer_async_callback ignores `VoidCallback x()`', () async {
      final rule = PreferAsyncCallbackRule();
      const decl = 'typedef VoidCallback = void Function();\n';
      expect(
        await reportedRuleCodes(
          rule,
          '${decl}void f(VoidCallback load()) {}\n',
        ),
        isNot(contains('prefer_async_callback')),
      );
    });
  });

  group('record literal field diagnostics', () {
    test('duplicate_field_name reports the label token only', () async {
      const src = 'final r = (a: 1, a: 2);\n';
      final diags = await runRuleResolved(DuplicateRecordFieldNameRule(), src);
      expect(diags, hasLength(2));
      for (final d in diags) {
        expect(src.substring(d.offset, d.offset + d.length), 'a');
      }
    });
  });

  group('callback position checks include record fields', () {
    test(
      'prefer_extracting_function_callbacks sees record field closures',
      () async {
        final body = List.generate(12, (i) => '    print($i);').join('\n');
        final src =
            'void g(Object o) {}\n'
            'void f() {\n'
            '  g((cb: () {\n$body\n  }));\n'
            '}\n';
        final codes = await reportedRuleCodes(
          PreferExtractingFunctionCallbacksRule(),
          src,
        );
        expect(codes, contains('prefer_extracting_function_callbacks'));
      },
    );
  });
}
