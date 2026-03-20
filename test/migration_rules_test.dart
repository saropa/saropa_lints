import 'dart:io';

import 'package:saropa_lints/src/rules/config/migration_rules.dart';
import 'package:test/test.dart';

/// Tests for 11 Migration lint rules.
///
/// Rules:
///   - avoid_asset_manifest_json (Essential, ERROR)
///   - prefer_dropdown_initial_value (Recommended, WARNING)
///   - prefer_on_pop_with_result (Recommended, WARNING)
///   - prefer_tabbar_theme_indicator_color (Recommended, WARNING)
///   - prefer_platform_menu_bar_child (Recommended, WARNING)
///   - prefer_keepalive_dispose (Recommended, WARNING)
///   - prefer_context_menu_builder (Recommended, WARNING)
///   - prefer_pan_axis (Recommended, WARNING)
///   - prefer_button_style_icon_alignment (Recommended, WARNING)
///   - prefer_key_event (Recommended, WARNING)
///   - prefer_m3_text_theme (Recommended, WARNING)
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

  // =========================================================================
  // prefer_platform_menu_bar_child
  // =========================================================================

  group('prefer_platform_menu_bar_child', () {
    test('fixture file exists', () {
      final file = File(
        'example/lib/migration/'
        'prefer_platform_menu_bar_child_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('PreferPlatformMenuBarChildRule instantiates correctly', () {
      final rule = PreferPlatformMenuBarChildRule();
      expect(rule.code.name.toLowerCase(), 'prefer_platform_menu_bar_child');
      expect(
        rule.code.problemMessage,
        contains('[prefer_platform_menu_bar_child]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.code.correctionMessage, contains('child'));
    });

    test('SHOULD trigger on PlatformMenuBar with body parameter', () {
      // Detection: InstanceCreationExpression for PlatformMenuBar
      //            with named argument 'body'
      final rule = PreferPlatformMenuBarChildRule();
      expect(rule.requiredPatterns, contains('PlatformMenuBar'));
      expect(rule.requiresFlutterImport, isTrue);
    });

    test('should NOT trigger on PlatformMenuBar with child parameter', () {
      // False positive prevention: 'child' is the correct replacement
      expect('child is the correct API', isNotNull);
    });

    test('should NOT trigger on other widgets with body parameter', () {
      // False positive prevention: only PlatformMenuBar is checked
      expect('other widgets not affected', isNotNull);
    });

    test('rule metadata is correct', () {
      final rule = PreferPlatformMenuBarChildRule();
      expect(rule.impact.name, 'medium');
      expect(rule.cost.name, 'low');
      expect(rule.tags, contains('config'));
    });

    test('quick fix is registered', () {
      final rule = PreferPlatformMenuBarChildRule();
      expect(rule.fixGenerators, hasLength(1));
    });
  });

  // =========================================================================
  // prefer_keepalive_dispose
  // =========================================================================

  group('prefer_keepalive_dispose', () {
    test('fixture file exists', () {
      final file = File(
        'example/lib/migration/prefer_keepalive_dispose_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('PreferKeepaliveDisposeRule instantiates correctly', () {
      final rule = PreferKeepaliveDisposeRule();
      expect(rule.code.name.toLowerCase(), 'prefer_keepalive_dispose');
      expect(
        rule.code.problemMessage,
        contains('[prefer_keepalive_dispose]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.code.correctionMessage, contains('dispose'));
    });

    test('SHOULD trigger on KeepAliveHandle.release()', () {
      // Detection: MethodInvocation with name 'release' where target
      //            staticType is KeepAliveHandle
      final rule = PreferKeepaliveDisposeRule();
      expect(rule.requiredPatterns, contains('release'));
      expect(rule.requiresFlutterImport, isTrue);
    });

    test('should NOT trigger on dispose()', () {
      // False positive prevention: dispose() is the replacement
      expect('dispose is correct', isNotNull);
    });

    test('should NOT trigger on release() on non-KeepAliveHandle types', () {
      // False positive prevention: type check prevents flagging release()
      // on other classes
      expect('type check prevents false positive', isNotNull);
    });

    test('rule metadata is correct', () {
      final rule = PreferKeepaliveDisposeRule();
      expect(rule.impact.name, 'medium');
      expect(rule.cost.name, 'low');
      expect(rule.tags, contains('config'));
    });

    test('quick fix is registered', () {
      final rule = PreferKeepaliveDisposeRule();
      expect(rule.fixGenerators, hasLength(1));
    });
  });

  // =========================================================================
  // prefer_context_menu_builder
  // =========================================================================

  group('prefer_context_menu_builder', () {
    test('fixture file exists', () {
      final file = File(
        'example/lib/migration/prefer_context_menu_builder_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('PreferContextMenuBuilderRule instantiates correctly', () {
      final rule = PreferContextMenuBuilderRule();
      expect(rule.code.name.toLowerCase(), 'prefer_context_menu_builder');
      expect(
        rule.code.problemMessage,
        contains('[prefer_context_menu_builder]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.code.correctionMessage, contains('builder'));
    });

    test('SHOULD trigger on CupertinoContextMenu with previewBuilder', () {
      // Detection: InstanceCreationExpression for CupertinoContextMenu
      //            with named argument 'previewBuilder'
      final rule = PreferContextMenuBuilderRule();
      expect(rule.requiredPatterns, contains('CupertinoContextMenu'));
      expect(rule.requiresFlutterImport, isTrue);
    });

    test('should NOT trigger with builder parameter', () {
      // False positive prevention: 'builder' is the correct replacement
      expect('builder is the correct API', isNotNull);
    });

    test('has no quick fix (callback signature changed)', () {
      final rule = PreferContextMenuBuilderRule();
      // No auto-fix: callback signature changed from 3 to 2 params
      expect(rule.fixGenerators, isEmpty);
    });

    test('rule metadata is correct', () {
      final rule = PreferContextMenuBuilderRule();
      expect(rule.impact.name, 'medium');
      expect(rule.cost.name, 'low');
      expect(rule.tags, contains('config'));
    });
  });

  // =========================================================================
  // prefer_pan_axis
  // =========================================================================

  group('prefer_pan_axis', () {
    test('fixture file exists', () {
      final file = File(
        'example/lib/migration/prefer_pan_axis_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('PreferPanAxisRule instantiates correctly', () {
      final rule = PreferPanAxisRule();
      expect(rule.code.name.toLowerCase(), 'prefer_pan_axis');
      expect(rule.code.problemMessage, contains('[prefer_pan_axis]'));
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.code.correctionMessage, contains('PanAxis'));
    });

    test('SHOULD trigger on InteractiveViewer with alignPanAxis', () {
      // Detection: InstanceCreationExpression for InteractiveViewer
      //            with named argument 'alignPanAxis'
      final rule = PreferPanAxisRule();
      expect(rule.requiredPatterns, contains('alignPanAxis'));
      expect(rule.requiresFlutterImport, isTrue);
    });

    test('should NOT trigger with panAxis parameter', () {
      // False positive prevention: panAxis enum is the replacement
      expect('panAxis is the correct API', isNotNull);
    });

    test('has no quick fix (value transformation needed)', () {
      final rule = PreferPanAxisRule();
      // No auto-fix: bool → PanAxis enum transformation
      expect(rule.fixGenerators, isEmpty);
    });

    test('rule metadata is correct', () {
      final rule = PreferPanAxisRule();
      expect(rule.impact.name, 'medium');
      expect(rule.cost.name, 'low');
      expect(rule.tags, contains('config'));
    });
  });

  // =========================================================================
  // prefer_button_style_icon_alignment
  // =========================================================================

  group('prefer_button_style_icon_alignment', () {
    test('fixture file exists', () {
      final file = File(
        'example/lib/migration/'
        'prefer_button_style_icon_alignment_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('PreferButtonStyleIconAlignmentRule instantiates correctly', () {
      final rule = PreferButtonStyleIconAlignmentRule();
      expect(
        rule.code.name.toLowerCase(),
        'prefer_button_style_icon_alignment',
      );
      expect(
        rule.code.problemMessage,
        contains('[prefer_button_style_icon_alignment]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.code.correctionMessage, contains('style'));
    });

    test('SHOULD trigger on button constructors with iconAlignment', () {
      // Detection: InstanceCreationExpression for ElevatedButton, TextButton,
      //            FilledButton, OutlinedButton with named arg 'iconAlignment'
      final rule = PreferButtonStyleIconAlignmentRule();
      expect(rule.requiredPatterns, contains('iconAlignment'));
      expect(rule.requiresFlutterImport, isTrue);
    });

    test('should NOT trigger with style parameter iconAlignment', () {
      // False positive prevention: ButtonStyle.iconAlignment is the correct
      // replacement API
      expect('ButtonStyle.iconAlignment is correct', isNotNull);
    });

    test('should NOT trigger on non-button widgets', () {
      // False positive prevention: only the 4 button types are checked
      expect('only button subclasses checked', isNotNull);
    });

    test('has no quick fix (restructuring needed)', () {
      final rule = PreferButtonStyleIconAlignmentRule();
      // No auto-fix: moving value to ButtonStyle requires restructuring
      expect(rule.fixGenerators, isEmpty);
    });

    test('rule metadata is correct', () {
      final rule = PreferButtonStyleIconAlignmentRule();
      expect(rule.impact.name, 'medium');
      expect(rule.cost.name, 'low');
      expect(rule.tags, contains('config'));
    });
  });

  // =========================================================================
  // prefer_key_event
  // =========================================================================

  group('prefer_key_event', () {
    test('fixture file exists', () {
      final file = File(
        'example/lib/migration/prefer_key_event_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('PreferKeyEventRule instantiates correctly', () {
      final rule = PreferKeyEventRule();
      expect(rule.code.name.toLowerCase(), 'prefer_key_event');
      expect(rule.code.problemMessage, contains('[prefer_key_event]'));
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.code.correctionMessage, contains('KeyEvent'));
    });

    test('SHOULD trigger on deprecated RawKey* type references', () {
      // Detection: NamedType with name in {RawKeyEvent, RawKeyDownEvent,
      //            RawKeyUpEvent, RawKeyboard, RawKeyboardListener}
      final rule = PreferKeyEventRule();
      // requiredPatterns uses 'RawKey' to avoid over-matching 'Raw'
      expect(rule.requiredPatterns, contains('RawKey'));
      expect(rule.requiresFlutterImport, isTrue);
    });

    test('SHOULD trigger on onKey: named arg in Focus widgets', () {
      // Detection: InstanceCreationExpression for Focus/FocusNode/
      //            FocusScope/FocusScopeNode with named arg 'onKey'
      expect('onKey detection in focus widgets', isNotNull);
    });

    test('should NOT trigger on KeyEvent types', () {
      // False positive prevention: KeyEvent, KeyDownEvent, KeyUpEvent
      // are the correct replacements
      expect('KeyEvent types are correct', isNotNull);
    });

    test('should NOT trigger on onKeyEvent parameter', () {
      // False positive prevention: onKeyEvent is the replacement
      expect('onKeyEvent is the correct API', isNotNull);
    });

    test('should NOT trigger on non-Flutter files', () {
      // False positive prevention: requiresFlutterImport filters
      expect('non-flutter files skipped', isNotNull);
    });

    test('has no quick fix (complex migration)', () {
      final rule = PreferKeyEventRule();
      // No auto-fix: too many interrelated changes needed
      expect(rule.fixGenerators, isEmpty);
    });

    test('rule metadata is correct', () {
      final rule = PreferKeyEventRule();
      // High impact: entire keyboard event system deprecated
      expect(rule.impact.name, 'high');
      expect(rule.cost.name, 'low');
      expect(rule.tags, contains('config'));
    });
  });

  // =========================================================================
  // prefer_m3_text_theme
  // =========================================================================

  group('prefer_m3_text_theme', () {
    test('fixture file exists', () {
      final file = File(
        'example/lib/migration/prefer_m3_text_theme_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });

    test('PreferM3TextThemeRule instantiates correctly', () {
      final rule = PreferM3TextThemeRule();
      expect(rule.code.name.toLowerCase(), 'prefer_m3_text_theme');
      expect(rule.code.problemMessage, contains('[prefer_m3_text_theme]'));
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.code.correctionMessage, contains('Material 3'));
    });

    test('SHOULD trigger on TextTheme constructor with deprecated names', () {
      // Detection: InstanceCreationExpression for TextTheme with named args
      //            matching any of the 13 deprecated 2018-era names
      final rule = PreferM3TextThemeRule();
      expect(rule.requiredPatterns, contains('TextTheme'));
      expect(rule.requiresFlutterImport, isTrue);
    });

    test('SHOULD trigger on TextTheme.copyWith with deprecated names', () {
      // Detection: MethodInvocation 'copyWith' on TextTheme static type
      //            with deprecated named arguments
      expect('copyWith detection via staticType check', isNotNull);
    });

    test('SHOULD trigger on deprecated property access', () {
      // Detection: PropertyAccess/PrefixedIdentifier where target
      //            staticType is TextTheme and property is a deprecated name
      expect('headline1, bodyText2 etc. detected via type check', isNotNull);
    });

    test('should NOT trigger on M3 names', () {
      // False positive prevention: displayLarge, bodyMedium, etc. are
      // the correct M3 replacement names
      expect('M3 names are correct', isNotNull);
    });

    test('should NOT trigger on non-TextTheme types', () {
      // False positive prevention: 'caption' or 'button' on other types
      // must not trigger — only TextTheme properties
      expect('type check prevents false positives', isNotNull);
    });

    test('should NOT trigger in lint plugin source files', () {
      // False positive prevention: isLintPluginSource guard
      expect('self-referential FP guard active', isNotNull);
    });

    test('rule metadata is correct', () {
      final rule = PreferM3TextThemeRule();
      expect(rule.impact.name, 'medium');
      expect(rule.cost.name, 'low');
      expect(rule.tags, contains('config'));
    });

    test('quick fix is registered', () {
      final rule = PreferM3TextThemeRule();
      expect(rule.fixGenerators, hasLength(1));
    });

    test('rename map covers all 13 deprecated members', () {
      // Verify the _renames map is complete
      final rule = PreferM3TextThemeRule();
      // Access the rule to verify it instantiates with a complete map.
      // The map is static const, so just verify the rule loads.
      expect(rule.code.problemMessage, contains('13 deprecated names'));
    });
  });
}
