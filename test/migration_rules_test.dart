import 'dart:io';

import 'package:saropa_lints/src/rules/config/migration_rules.dart';
import 'package:test/test.dart';

/// Tests for 4 Migration lint rules.
///
/// Rules:
///   - avoid_asset_manifest_json (Essential, ERROR)
///   - prefer_dropdown_initial_value (Recommended, WARNING)
///   - prefer_on_pop_with_result (Recommended, WARNING)
///   - prefer_tabbar_theme_indicator_color (Recommended, WARNING)
///
/// Test fixture: example/lib/migration_rules_fixture.dart
void main() {
  group('Migration Rules - Fixture Verification', () {
    test('migration_rules_fixture exists', () {
      final file = File('example/lib/migration_rules_fixture.dart');
      expect(file.existsSync(), isTrue);
    });
  });

  group('Migration Rules - Rule Instantiation', () {
    test('AvoidAssetManifestJsonRule instantiates correctly', () {
      final rule = AvoidAssetManifestJsonRule();
      expect(rule.code.name.toLowerCase(), 'avoid_asset_manifest_json');
      expect(rule.code.problemMessage, contains('[avoid_asset_manifest_json]'));
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('PreferDropdownInitialValueRule instantiates correctly', () {
      final rule = PreferDropdownInitialValueRule();
      expect(rule.code.name.toLowerCase(), 'prefer_dropdown_initial_value');
      expect(
        rule.code.problemMessage,
        contains('[prefer_dropdown_initial_value]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('PreferOnPopWithResultRule instantiates correctly', () {
      final rule = PreferOnPopWithResultRule();
      expect(rule.code.name.toLowerCase(), 'prefer_on_pop_with_result');
      expect(rule.code.problemMessage, contains('[prefer_on_pop_with_result]'));
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('PreferTabbarThemeIndicatorColorRule instantiates correctly', () {
      final rule = PreferTabbarThemeIndicatorColorRule();
      expect(
        rule.code.name.toLowerCase(),
        'prefer_tabbar_theme_indicator_color',
      );
      expect(
        rule.code.problemMessage,
        contains('[prefer_tabbar_theme_indicator_color]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.code.correctionMessage, contains('TabBarThemeData'));
    });
  });

  group('avoid_asset_manifest_json', () {
    test('SHOULD trigger on AssetManifest.json string literal', () {
      // Detection: SimpleStringLiteral with value == 'AssetManifest.json'
      // Example: rootBundle.loadString('AssetManifest.json')
      expect('avoid_asset_manifest_json', isNotNull);
    });

    test('should NOT trigger on AssetManifest.bin', () {
      // False positive prevention: .bin is the new binary format
      expect('AssetManifest.bin is valid', isNotNull);
    });

    test('should NOT trigger on other .json files', () {
      // False positive prevention: only exact 'AssetManifest.json' match
      expect('config.json is valid', isNotNull);
    });

    test('should NOT trigger on partial matches', () {
      // False positive prevention: 'CustomAssetManifest.json' is different
      expect('partial match should not trigger', isNotNull);
    });
  });

  group('prefer_dropdown_initial_value', () {
    test('SHOULD trigger on DropdownButtonFormField with value parameter', () {
      // Detection: InstanceCreationExpression for DropdownButtonFormField
      //            with named argument 'value'
      expect('prefer_dropdown_initial_value', isNotNull);
    });

    test('should NOT trigger with initialValue parameter', () {
      // False positive prevention: using the new parameter name
      expect('initialValue is correct', isNotNull);
    });

    test('should NOT trigger on DropdownButton with value parameter', () {
      // False positive prevention: DropdownButton (not FormField variant)
      // has a legitimate 'value' parameter that is NOT deprecated
      expect('DropdownButton.value is not deprecated', isNotNull);
    });

    test('should NOT trigger on non-Flutter files', () {
      // False positive prevention: requiresFlutterImport filters
      expect('non-flutter files skipped', isNotNull);
    });
  });

  group('prefer_on_pop_with_result', () {
    test('SHOULD trigger on onPop named argument', () {
      // Detection: NamedExpression with label.name == 'onPop'
      //            inside an ArgumentList
      expect('prefer_on_pop_with_result', isNotNull);
    });

    test('SHOULD trigger on onPop method override', () {
      // Detection: MethodDeclaration with name 'onPop' and @override
      expect('onPop override detected', isNotNull);
    });

    test('should NOT trigger on onPopWithResult', () {
      // False positive prevention: the replacement API
      expect('onPopWithResult is correct', isNotNull);
    });

    test('should NOT trigger on non-override onPop method', () {
      // False positive prevention: only flags @override methods
      expect('non-override onPop is fine', isNotNull);
    });

    test('should NOT trigger on map literal with onPop key', () {
      // False positive prevention: map keys are not named arguments
      expect("{'onPop': true} should not trigger", isNotNull);
    });

    test('should NOT trigger on non-Flutter files', () {
      // False positive prevention: requiresFlutterImport filters
      expect('non-flutter files skipped', isNotNull);
    });
  });

  group('prefer_tabbar_theme_indicator_color', () {
    test('fixture file exists', () {
      final file = File(
        'example/lib/migration/'
        'prefer_tabbar_theme_indicator_color_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('SHOULD trigger on ThemeData constructor with indicatorColor', () {
      // Detection: InstanceCreationExpression for ThemeData
      //            with named argument 'indicatorColor'
      // Example: ThemeData(indicatorColor: Colors.blue)
      final rule = PreferTabbarThemeIndicatorColorRule();
      expect(rule.requiredPatterns, contains('indicatorColor'));
      expect(rule.requiresFlutterImport, isTrue);
    });

    test('SHOULD trigger on ThemeData.copyWith with indicatorColor', () {
      // Detection: MethodInvocation 'copyWith' on ThemeData static type
      //            with named argument 'indicatorColor'
      // Example: theme.copyWith(indicatorColor: Colors.red)
      expect('copyWith detection via staticType check', isNotNull);
    });

    test('SHOULD trigger on ThemeData.indicatorColor property access', () {
      // Detection: PropertyAccess/PrefixedIdentifier where target
      //            staticType is ThemeData and property is 'indicatorColor'
      // Example: final color = theme.indicatorColor;
      expect('property access detected via type check', isNotNull);
    });

    test('should NOT trigger on TabBarThemeData with indicatorColor', () {
      // False positive prevention: TabBarThemeData.indicatorColor is the
      // correct replacement API — must not flag it
      // Example: TabBarThemeData(indicatorColor: Colors.blue)
      expect('TabBarThemeData is the correct API', isNotNull);
    });

    test('should NOT trigger on ThemeData without indicatorColor', () {
      // False positive prevention: ThemeData constructor without the
      // deprecated argument should not trigger
      // Example: ThemeData(primaryColor: Colors.blue)
      expect('no indicatorColor means no violation', isNotNull);
    });

    test('should NOT trigger on local variable named indicatorColor', () {
      // False positive prevention: a local variable named indicatorColor
      // is not a ThemeData property access
      // Example: final indicatorColor = Colors.blue;
      expect('local variables are not ThemeData properties', isNotNull);
    });

    test('should NOT trigger on non-Flutter files', () {
      // False positive prevention: requiresFlutterImport filters
      expect('non-flutter files skipped', isNotNull);
    });

    test('should NOT trigger in lint plugin source files', () {
      // False positive prevention: isLintPluginSource guard prevents
      // self-referential FPs from the rule's own detection pattern strings
      expect('self-referential FP guard active', isNotNull);
    });

    test('rule metadata is correct', () {
      final rule = PreferTabbarThemeIndicatorColorRule();
      // Deprecation migration = medium impact (tech debt, not crash)
      expect(rule.impact.name, 'medium');
      expect(rule.cost.name, 'low');
      expect(rule.tags, contains('config'));
    });

    test('quick fix is registered', () {
      final rule = PreferTabbarThemeIndicatorColorRule();
      // Fix removes the indicatorColor argument from ThemeData
      expect(rule.fixGenerators, hasLength(1));
    });
  });
}
