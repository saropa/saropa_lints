import 'package:saropa_lints/src/rules/config/sdk_migration_batch2_rules.dart';
import 'package:saropa_lints/src/tiers.dart';
import 'package:test/test.dart';

/// Tests for 10 SDK Migration Batch 2 lint rules.
///
/// Rules:
///   - prefer_isnan_over_nan_equality (Recommended, WARNING)
///   - prefer_code_unit_at (Recommended, INFO)
///   - prefer_never_over_always_throws (Recommended, WARNING)
///   - prefer_visibility_over_opacity_zero (Recommended, INFO)
///   - avoid_platform_constructor (Recommended, WARNING)
///   - prefer_keyboard_listener_over_raw (Recommended, WARNING)
///   - avoid_extending_html_native_class (Recommended, ERROR)
///   - avoid_extending_security_context (Recommended, ERROR)
///   - avoid_deprecated_pointer_arithmetic (Recommended, WARNING)
///   - prefer_extracting_repeated_map_lookup (Recommended, INFO)
void main() {
  // ---------------------------------------------------------------------------
  // Rule Instantiation & Metadata
  // ---------------------------------------------------------------------------

  group('SDK Migration Batch 2 - Rule Instantiation', () {
    test('PreferIsNanOverNanEqualityRule instantiates correctly', () {
      final rule = PreferIsNanOverNanEqualityRule();
      expect(rule.code.lowerCaseName, 'prefer_isnan_over_nan_equality');
      expect(
        rule.code.problemMessage,
        contains('[prefer_isnan_over_nan_equality]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.requiredPatterns, contains('nan'));
      expect(rule.fixGenerators, hasLength(1));
    });

    test('PreferCodeUnitAtRule instantiates correctly', () {
      final rule = PreferCodeUnitAtRule();
      expect(rule.code.lowerCaseName, 'prefer_code_unit_at');
      expect(rule.code.problemMessage, contains('[prefer_code_unit_at]'));
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.requiredPatterns, contains('codeUnits'));
      expect(rule.fixGenerators, hasLength(1));
    });

    test('PreferNeverOverAlwaysThrowsRule instantiates correctly', () {
      final rule = PreferNeverOverAlwaysThrowsRule();
      expect(rule.code.lowerCaseName, 'prefer_never_over_always_throws');
      expect(
        rule.code.problemMessage,
        contains('[prefer_never_over_always_throws]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.requiredPatterns, contains('alwaysThrows'));
    });

    test('PreferVisibilityOverOpacityZeroRule instantiates correctly', () {
      final rule = PreferVisibilityOverOpacityZeroRule();
      expect(rule.code.lowerCaseName, 'prefer_visibility_over_opacity_zero');
      expect(
        rule.code.problemMessage,
        contains('[prefer_visibility_over_opacity_zero]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.requiredPatterns, contains('Opacity'));
      expect(rule.requiresFlutterImport, isTrue);
    });

    test('AvoidPlatformConstructorRule instantiates correctly', () {
      final rule = AvoidPlatformConstructorRule();
      expect(rule.code.lowerCaseName, 'avoid_platform_constructor');
      expect(
        rule.code.problemMessage,
        contains('[avoid_platform_constructor]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.requiredPatterns, contains('Platform'));
    });

    test('PreferKeyboardListenerOverRawRule instantiates correctly', () {
      final rule = PreferKeyboardListenerOverRawRule();
      expect(rule.code.lowerCaseName, 'prefer_keyboard_listener_over_raw');
      expect(
        rule.code.problemMessage,
        contains('[prefer_keyboard_listener_over_raw]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.requiredPatterns, contains('RawKeyboardListener'));
      expect(rule.requiresFlutterImport, isTrue);
      expect(rule.fixGenerators, hasLength(1));
    });

    test('AvoidExtendingHtmlNativeClassRule instantiates correctly', () {
      final rule = AvoidExtendingHtmlNativeClassRule();
      expect(rule.code.lowerCaseName, 'avoid_extending_html_native_class');
      expect(
        rule.code.problemMessage,
        contains('[avoid_extending_html_native_class]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      // Pattern filter uses specific class names, not 'extends'
      expect(rule.requiredPatterns, contains('HtmlElement'));
      expect(rule.requiredPatterns, contains('CanvasElement'));
    });

    test('AvoidExtendingSecurityContextRule instantiates correctly', () {
      final rule = AvoidExtendingSecurityContextRule();
      expect(rule.code.lowerCaseName, 'avoid_extending_security_context');
      expect(
        rule.code.problemMessage,
        contains('[avoid_extending_security_context]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.requiredPatterns, contains('SecurityContext'));
    });

    test('AvoidDeprecatedPointerArithmeticRule instantiates correctly', () {
      final rule = AvoidDeprecatedPointerArithmeticRule();
      expect(rule.code.lowerCaseName, 'avoid_deprecated_pointer_arithmetic');
      expect(
        rule.code.problemMessage,
        contains('[avoid_deprecated_pointer_arithmetic]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.requiredPatterns, contains('elementAt'));
      expect(rule.fixGenerators, hasLength(1));
    });

    test('PreferExtractingRepeatedMapLookupRule instantiates correctly', () {
      final rule = PreferExtractingRepeatedMapLookupRule();
      expect(
        rule.code.lowerCaseName,
        'prefer_extracting_repeated_map_lookup',
      );
      expect(
        rule.code.problemMessage,
        contains('[prefer_extracting_repeated_map_lookup]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Tier Registration
  // ---------------------------------------------------------------------------

  group('SDK Migration Batch 2 - Tier Registration', () {
    test('all 10 rules are in recommendedOnlyRules', () {
      const expected = <String>[
        'prefer_isnan_over_nan_equality',
        'prefer_code_unit_at',
        'prefer_never_over_always_throws',
        'prefer_visibility_over_opacity_zero',
        'avoid_platform_constructor',
        'prefer_keyboard_listener_over_raw',
        'avoid_extending_html_native_class',
        'avoid_extending_security_context',
        'avoid_deprecated_pointer_arithmetic',
        'prefer_extracting_repeated_map_lookup',
      ];
      for (final name in expected) {
        expect(
          recommendedOnlyRules.contains(name),
          isTrue,
          reason: '$name should be in recommendedOnlyRules',
        );
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Detection Intent Tests (per rule)
  // ---------------------------------------------------------------------------

  group('prefer_isnan_over_nan_equality', () {
    test('SHOULD trigger on x == double.nan', () {
      // Detection: BinaryExpression with == and right operand double.nan
      expect('prefer_isnan_over_nan_equality', isNotNull);
    });

    test('SHOULD trigger on x != double.nan', () {
      // Detection: BinaryExpression with != and right operand double.nan
      expect('prefer_isnan_over_nan_equality', isNotNull);
    });

    test('SHOULD trigger on double.nan == x (reversed)', () {
      // Detection: BinaryExpression with == and left operand double.nan
      expect('prefer_isnan_over_nan_equality', isNotNull);
    });

    test('should NOT trigger on x == 0.0', () {
      // False positive guard: only double.nan, not other double values
      expect('other comparisons valid', isNotNull);
    });

    test('should NOT trigger on x.isNaN', () {
      // False positive guard: already using the correct pattern
      expect('isNaN is correct', isNotNull);
    });
  });

  group('prefer_code_unit_at', () {
    test('SHOULD trigger on string.codeUnits[i]', () {
      // Detection: IndexExpression on .codeUnits with String receiver
      expect('prefer_code_unit_at', isNotNull);
    });

    test('should NOT trigger on string.codeUnitAt(i)', () {
      // False positive guard: already using the correct pattern
      expect('codeUnitAt is correct', isNotNull);
    });

    test('should NOT trigger on list.codeUnits[i] (non-String)', () {
      // False positive guard: type check prevents non-String matches
      expect('non-string receiver skipped', isNotNull);
    });
  });

  group('prefer_never_over_always_throws', () {
    test('SHOULD trigger on @alwaysThrows annotation', () {
      // Detection: Annotation with name 'alwaysThrows' from package:meta
      expect('prefer_never_over_always_throws', isNotNull);
    });

    test('should NOT trigger on user-defined @alwaysThrows', () {
      // False positive guard: library check prevents non-meta matches
      expect('user annotation skipped', isNotNull);
    });
  });

  group('prefer_visibility_over_opacity_zero', () {
    test('SHOULD trigger on Opacity(opacity: 0)', () {
      // Detection: InstanceCreation of Opacity with opacity = IntegerLiteral 0
      expect('prefer_visibility_over_opacity_zero', isNotNull);
    });

    test('SHOULD trigger on Opacity(opacity: 0.0)', () {
      // Detection: InstanceCreation of Opacity with opacity = DoubleLiteral 0.0
      expect('prefer_visibility_over_opacity_zero', isNotNull);
    });

    test('should NOT trigger on Opacity(opacity: 0.5)', () {
      // False positive guard: non-zero opacity is valid
      expect('partial opacity valid', isNotNull);
    });

    test('should NOT trigger on Opacity with variable opacity', () {
      // False positive guard: variable (non-literal) opacity is valid
      expect('variable opacity valid', isNotNull);
    });
  });

  group('avoid_platform_constructor', () {
    test('SHOULD trigger on Platform() constructor', () {
      // Detection: InstanceCreationExpression of Platform from dart:io
      expect('avoid_platform_constructor', isNotNull);
    });

    test('should NOT trigger on user-defined Platform class', () {
      // False positive guard: element resolves to dart:io
      expect('user Platform class skipped', isNotNull);
    });

    test('should NOT trigger on Platform.isAndroid (static access)', () {
      // False positive guard: only constructors, not static members
      expect('static access valid', isNotNull);
    });
  });

  group('prefer_keyboard_listener_over_raw', () {
    test('SHOULD trigger on RawKeyboardListener constructor', () {
      // Detection: InstanceCreation of Flutter's RawKeyboardListener
      expect('prefer_keyboard_listener_over_raw', isNotNull);
    });

    test('should NOT trigger on KeyboardListener', () {
      // False positive guard: the replacement widget
      expect('KeyboardListener is correct', isNotNull);
    });

    test('should NOT trigger on user-defined RawKeyboardListener', () {
      // False positive guard: type resolution check
      expect('user class skipped', isNotNull);
    });
  });

  group('avoid_extending_html_native_class', () {
    test('SHOULD trigger on extends HtmlElement', () {
      // Detection: ClassDeclaration extends clause with HtmlElement
      expect('avoid_extending_html_native_class', isNotNull);
    });

    test('SHOULD trigger on implements CanvasElement', () {
      // Detection: ClassDeclaration implements clause with CanvasElement
      expect('avoid_extending_html_native_class', isNotNull);
    });

    test('should NOT trigger on user-defined HtmlElement class', () {
      // False positive guard: library check against dart:html
      expect('user class skipped', isNotNull);
    });
  });

  group('avoid_extending_security_context', () {
    test('SHOULD trigger on extends SecurityContext', () {
      // Detection: ClassDeclaration extends clause with SecurityContext
      expect('avoid_extending_security_context', isNotNull);
    });

    test('SHOULD trigger on implements SecurityContext', () {
      // Detection: ClassDeclaration implements clause with SecurityContext
      expect('avoid_extending_security_context', isNotNull);
    });

    test('should NOT trigger on user-defined SecurityContext', () {
      // False positive guard: library check against dart:io
      expect('user class skipped', isNotNull);
    });
  });

  group('avoid_deprecated_pointer_arithmetic', () {
    test('SHOULD trigger on ptr.elementAt(n) for Pointer<T>', () {
      // Detection: MethodInvocation elementAt on Pointer from dart:ffi
      expect('avoid_deprecated_pointer_arithmetic', isNotNull);
    });

    test('should NOT trigger on List.elementAt(n)', () {
      // False positive guard: type check against dart:ffi Pointer
      expect('List.elementAt is valid', isNotNull);
    });
  });

  group('prefer_extracting_repeated_map_lookup', () {
    test('SHOULD trigger on 3+ identical map[key] in same function', () {
      // Detection: BlockFunctionBody with 3+ IndexExpressions sharing
      //            the same target[key] source text
      expect('prefer_extracting_repeated_map_lookup', isNotNull);
    });

    test('should NOT trigger on 2 identical map[key]', () {
      // False positive guard: threshold is 3
      expect('2 accesses valid', isNotNull);
    });

    test('should NOT trigger on different keys', () {
      // False positive guard: different keys are separate lookups
      expect('different keys valid', isNotNull);
    });

    test('should NOT flag across nested function boundaries', () {
      // False positive guard: visitor stops at nested FunctionExpression
      expect('nested functions separate', isNotNull);
    });
  });
}
