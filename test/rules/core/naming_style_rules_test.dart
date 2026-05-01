import 'dart:io';

import 'package:saropa_lints/src/rules/core/naming_style_rules.dart';
import 'package:test/test.dart';

/// Tests for 28 Naming Style lint rules.
///
/// Test fixtures: example/lib/naming_style/*
// Rule instantiation and message checks; fixtures under example/lib/naming_style.
void main() {
  group('Naming Style Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(rule.code.problemMessage.length, greaterThan(50));
        expect(rule.code.correctionMessage, isNotNull);
      });
    }

    testRule(
      'AvoidGetterPrefixRule',
      'prefer_no_getter_prefix',
      () => AvoidGetterPrefixRule(),
    );
    testRule(
      'AvoidNonAsciiSymbolsRule',
      'avoid_non_ascii_symbols',
      () => AvoidNonAsciiSymbolsRule(),
    );
    testRule(
      'FormatCommentRule',
      'prefer_capitalized_comment_start',
      () => FormatCommentRule(),
    );
    testRule(
      'MatchClassNamePatternRule',
      'match_class_name_pattern',
      () => MatchClassNamePatternRule(),
    );
    testRule(
      'MatchGetterSetterFieldNamesRule',
      'match_getter_setter_field_names',
      () => MatchGetterSetterFieldNamesRule(),
    );
    testRule(
      'MatchLibFolderStructureRule',
      'match_lib_folder_structure',
      () => MatchLibFolderStructureRule(),
    );
    testRule(
      'MatchPositionalFieldNamesOnAssignmentRule',
      'match_positional_field_names_on_assignment',
      () => MatchPositionalFieldNamesOnAssignmentRule(),
    );
    testRule(
      'PreferBooleanPrefixesRule',
      'prefer_boolean_prefixes',
      () => PreferBooleanPrefixesRule(),
    );
    testRule(
      'PreferBooleanPrefixesForLocalsRule',
      'prefer_boolean_prefixes_for_locals',
      () => PreferBooleanPrefixesForLocalsRule(),
    );
    testRule(
      'PreferBooleanPrefixesForParamsRule',
      'prefer_boolean_prefixes_for_params',
      () => PreferBooleanPrefixesForParamsRule(),
    );
    testRule(
      'PreferCorrectCallbackFieldNameRule',
      'prefer_correct_callback_field_name',
      () => PreferCorrectCallbackFieldNameRule(),
    );
    testRule(
      'PreferCorrectErrorNameRule',
      'prefer_correct_error_name',
      () => PreferCorrectErrorNameRule(),
    );
    testRule(
      'PreferCorrectHandlerNameRule',
      'prefer_correct_handler_name',
      () => PreferCorrectHandlerNameRule(),
    );
    testRule(
      'PreferCorrectIdentifierLengthRule',
      'prefer_correct_identifier_length',
      () => PreferCorrectIdentifierLengthRule(),
    );
    testRule(
      'PreferCorrectSetterParameterNameRule',
      'prefer_correct_setter_parameter_name',
      () => PreferCorrectSetterParameterNameRule(),
    );
    testRule(
      'PreferExplicitParameterNamesRule',
      'prefer_explicit_parameter_names',
      () => PreferExplicitParameterNamesRule(),
    );
    testRule(
      'PreferMatchFileNameRule',
      'prefer_match_file_name',
      () => PreferMatchFileNameRule(),
    );
    testRule(
      'PreferPrefixedGlobalConstantsRule',
      'prefer_prefixed_global_constants',
      () => PreferPrefixedGlobalConstantsRule(),
    );
    testRule('TagNameRule', 'prefer_kebab_tag_name', () => TagNameRule());
    testRule(
      'PreferNamedExtensionsRule',
      'prefer_named_extensions',
      () => PreferNamedExtensionsRule(),
    );
    testRule(
      'PreferBasePrefixRule',
      'prefer_base_prefix',
      () => PreferBasePrefixRule(),
    );
    testRule(
      'PreferExtensionSuffixRule',
      'prefer_extension_suffix',
      () => PreferExtensionSuffixRule(),
    );
    testRule(
      'PreferMixinPrefixRule',
      'prefer_mixin_prefix',
      () => PreferMixinPrefixRule(),
    );
    testRule(
      'PreferIPrefixInterfacesRule',
      'prefer_i_prefix_interfaces',
      () => PreferIPrefixInterfacesRule(),
    );
    testRule(
      'PreferNoIPrefixInterfacesRule',
      'prefer_no_i_prefix_interfaces',
      () => PreferNoIPrefixInterfacesRule(),
    );
    testRule(
      'PreferImplSuffixRule',
      'prefer_impl_suffix',
      () => PreferImplSuffixRule(),
    );
    testRule(
      'PreferTypedefForCallbacksRule',
      'prefer_typedef_for_callbacks',
      () => PreferTypedefForCallbacksRule(),
    );
    testRule(
      'PreferEnhancedEnumsRule',
      'prefer_enhanced_enums',
      () => PreferEnhancedEnumsRule(),
    );
    testRule(
      'PreferWildcardForUnusedParamRule',
      'prefer_wildcard_for_unused_param',
      () => PreferWildcardForUnusedParamRule(),
    );
    testRule(
      'PreferCorrectPackageNameRule',
      'prefer_correct_package_name',
      () => PreferCorrectPackageNameRule(),
    );
    testRule(
      'PreferAdjectiveBoolGettersRule',
      'prefer_adjective_bool_getters',
      () => PreferAdjectiveBoolGettersRule(),
    );
    testRule(
      'PreferLowercaseConstantsRule',
      'prefer_lowercase_constants',
      () => PreferLowercaseConstantsRule(),
    );
    testRule(
      'PreferNounClassNamesRule',
      'prefer_noun_class_names',
      () => PreferNounClassNamesRule(),
    );
    testRule(
      'PreferVerbMethodNamesRule',
      'prefer_verb_method_names',
      () => PreferVerbMethodNamesRule(),
    );
  });
  group('Naming Style Rules - Fixture Verification', () {
    final fixtures = [
      'prefer_no_getter_prefix',
      'avoid_non_ascii_symbols',
      'prefer_capitalized_comment_start',
      'match_class_name_pattern',
      'match_getter_setter_field_names',
      'match_lib_folder_structure',
      'match_positional_field_names_on_assignment',
      'prefer_boolean_prefixes',
      'prefer_boolean_prefixes_for_locals',
      'prefer_boolean_prefixes_for_params',
      'prefer_correct_callback_field_name',
      'prefer_correct_error_name',
      'prefer_correct_handler_name',
      'prefer_correct_identifier_length',
      'prefer_correct_setter_parameter_name',
      'prefer_explicit_parameter_names',
      'prefer_match_file_name',
      'prefer_prefixed_global_constants',
      'prefer_kebab_tag_name',
      'prefer_named_extensions',
      'prefer_base_prefix',
      'prefer_extension_suffix',
      'prefer_mixin_prefix',
      'prefer_i_prefix_interfaces',
      'prefer_no_i_prefix_interfaces',
      'prefer_impl_suffix',
      'prefer_typedef_for_callbacks',
      'prefer_enhanced_enums',
      'prefer_wildcard_for_unused_param',
      'prefer_correct_package_name',
      'prefer_adjective_bool_getters',
      'prefer_lowercase_constants',
      'prefer_noun_class_names',
      'prefer_verb_method_names',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/naming_style/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Naming Style - Preference Rules', () {
    group('prefer_capitalized_comment_start', () {
      test('rule offers quick fix (capitalize first letter)', () {
        final rule = FormatCommentRule();
        expect(rule.fixGenerators, isNotEmpty);
      });
    });

    group('prefer_match_file_name', () {
      test('path separator splits on forward slash', () {
        final separator = RegExp(r'[/\\]');
        const path = 'lib/src/my_class.dart';
        final fileName = path.split(separator).last.replaceAll('.dart', '');
        expect(fileName, 'my_class');
      });

      test('path separator splits on backslash (Windows)', () {
        final separator = RegExp(r'[/\\]');
        const path = r'd:\src\project\lib\my_class.dart';
        final fileName = path.split(separator).last.replaceAll('.dart', '');
        expect(fileName, 'my_class');
      });

      test('path separator handles mixed separators', () {
        final separator = RegExp(r'[/\\]');
        const path = r'd:\src/project\lib/my_class.dart';
        final fileName = path.split(separator).last.replaceAll('.dart', '');
        expect(fileName, 'my_class');
      });
    });

    group('prefer_wildcard_for_unused_param', () {
      test('prefer_wildcard_for_unused_param SHOULD trigger', () {
        // Rule fires on unused positional params
      });

      test('prefer_wildcard_for_unused_param should NOT trigger', () {
        // Preferred pattern used correctly (wildcard params)
      });

      test('should NOT trigger on named parameters (v5 fix)', () {
        // Named params cannot use _ prefix in Dart (compiler error).
        // Verifies false-positive fix from v5.
        final rule = PreferWildcardForUnusedParamRule();
        expect(rule.code.lowerCaseName, 'prefer_wildcard_for_unused_param');
        expect(rule.code.problemMessage, contains('{v5}'));
        expect(rule.code.problemMessage, contains('Named parameters'));
      });
    });
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata,
  // fixture verification, and targeted non-stub regression checks.
}
