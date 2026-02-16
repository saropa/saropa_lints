// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Theming rules for Flutter applications.
///
/// These rules enforce consistent theming practices including dark mode
/// support, elevation handling, and proper use of ThemeExtensions.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../saropa_lint_rule.dart';

/// Warns when MaterialApp is created without a darkTheme parameter.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v2
///
/// Apps should support dark mode for accessibility and user preference.
/// Without darkTheme, the app won't adapt when the user enables dark mode.
///
/// **BAD:**
/// ```dart
/// MaterialApp(
///   theme: lightTheme,
///   home: MyHomePage(),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// MaterialApp(
///   theme: lightTheme,
///   darkTheme: darkTheme,
///   home: MyHomePage(),
/// );
/// ```
class RequireDarkModeTestingRule extends SaropaLintRule {
  RequireDarkModeTestingRule() : super(code: _code);

  /// Dark mode support is an accessibility requirement.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_dark_mode_testing',
    '[require_dark_mode_testing] MaterialApp missing darkTheme. App won\'t adapt to dark mode. Apps should support dark mode for accessibility and user preference. Without darkTheme, the app won\'t adapt when the user enables dark mode. {v2}',
    correctionMessage:
        'Add darkTheme parameter to support dark mode. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name.lexeme;

      // Check MaterialApp and CupertinoApp
      if (typeName != 'MaterialApp' && typeName != 'CupertinoApp') {
        return;
      }

      final hasTheme = node.argumentList.arguments.any(
        (arg) => arg is NamedExpression && arg.name.label.name == 'theme',
      );

      // Only warn if theme is set but darkTheme is missing
      if (!hasTheme) {
        return;
      }

      final hasDarkTheme = node.argumentList.arguments.any(
        (arg) => arg is NamedExpression && arg.name.label.name == 'darkTheme',
      );

      if (!hasDarkTheme) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when Card or Material uses elevation without checking brightness.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v2
///
/// Elevation shadows appear differently in dark mode. Material Design
/// recommends using surface overlays instead of shadows in dark themes.
///
/// **BAD:**
/// ```dart
/// Card(
///   elevation: 8,
///   child: content,
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// Card(
///   elevation: Theme.of(context).brightness == Brightness.light ? 8 : 2,
///   child: content,
/// );
/// ```
///
/// **ALSO GOOD:**
/// ```dart
/// Card(
///   elevation: 0,  // Use surface tint instead
///   surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
///   child: content,
/// );
/// ```
class AvoidElevationOpacityInDarkRule extends SaropaLintRule {
  AvoidElevationOpacityInDarkRule() : super(code: _code);

  /// Visual issues in dark mode affect user experience.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_elevation_opacity_in_dark',
    '[avoid_elevation_opacity_in_dark] High elevation (>4) without brightness check. Shadows look poor in dark mode. Elevation shadows appear differently in dark mode. Material Design recommends using surface overlays instead of shadows in dark themes. {v2}',
    correctionMessage:
        'Check Theme.of(context).brightness or use lower elevation in dark mode. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name.lexeme;

      // Check widgets that support elevation
      if (typeName != 'Card' &&
          typeName != 'Material' &&
          typeName != 'ElevatedButton' &&
          typeName != 'FloatingActionButton') {
        return;
      }

      // Find elevation argument
      NamedExpression? elevationArg;
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'elevation') {
          elevationArg = arg;
          break;
        }
      }

      if (elevationArg == null) {
        return;
      }

      // Check if elevation is a literal > 4
      final expr = elevationArg.expression;
      if (expr is IntegerLiteral && expr.value != null && expr.value! > 4) {
        reporter.atNode(elevationArg);
      } else if (expr is DoubleLiteral && expr.value > 4) {
        reporter.atNode(elevationArg);
      }
    });
  }
}

/// Warns when ThemeData uses ad-hoc color fields instead of ThemeExtension.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v2
///
/// ThemeExtension provides type-safe, documented custom theme properties.
/// Ad-hoc fields on ThemeData are not standardized and harder to maintain.
///
/// **BAD:**
/// ```dart
/// ThemeData(
///   primaryColor: Colors.blue,
///   extensions: [],
/// ).copyWith(
///   // Using copyWith to add custom "fields"
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// ThemeData(
///   primaryColor: Colors.blue,
///   extensions: [
///     MyAppColors(
///       brandPrimary: Colors.blue,
///       brandSecondary: Colors.green,
///     ),
///   ],
/// );
/// ```
class PreferThemeExtensionsRule extends SaropaLintRule {
  PreferThemeExtensionsRule() : super(code: _code);

  /// Maintainability issue for theming architecture.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'prefer_theme_extensions',
    '[prefer_theme_extensions] ThemeData.copyWith used for custom colors. Prefer ThemeExtension. ThemeExtension provides type-safe, documented custom theme properties. Ad-hoc fields on ThemeData are not standardized and harder to maintain. {v2}',
    correctionMessage:
        'Create a ThemeExtension subclass for type-safe custom theme properties. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((node) {
      // Check for ThemeData().copyWith() pattern
      if (node.methodName.name != 'copyWith') {
        return;
      }

      // Check if target is ThemeData
      final target = node.target;
      if (target == null) {
        return;
      }

      // Check if it's ThemeData instance or ThemeData() constructor
      String? targetTypeName;
      if (target is InstanceCreationExpression) {
        targetTypeName = target.constructorName.type.name.lexeme;
      } else if (target is MethodInvocation) {
        // Could be ThemeData.light().copyWith()
        final staticType = target.staticType;
        if (staticType != null) {
          targetTypeName = staticType.getDisplayString();
        }
      } else {
        final staticType = target.staticType;
        if (staticType != null) {
          targetTypeName = staticType.getDisplayString();
        }
      }

      if (targetTypeName != 'ThemeData') {
        return;
      }

      // Check if copyWith contains color-related parameters
      final colorParams = [
        'primaryColor',
        'accentColor',
        'backgroundColor',
        'canvasColor',
        'cardColor',
        'dialogBackgroundColor',
        'disabledColor',
        'dividerColor',
        'errorColor',
        'focusColor',
        'highlightColor',
        'hintColor',
        'hoverColor',
        'indicatorColor',
        'scaffoldBackgroundColor',
        'secondaryHeaderColor',
        'shadowColor',
        'splashColor',
        'unselectedWidgetColor',
      ];

      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final paramName = arg.name.label.name;
          if (colorParams.contains(paramName)) {
            reporter.atNode(node);
            return;
          }
        }
      }
    });
  }
}

// =============================================================================
// Semantic Color Naming Rules
// =============================================================================

/// Warns when Color variables are named by their appearance (redColor,
///
/// Since: v4.12.0 | Updated: v4.13.0 | Rule version: v2
///
/// blueBackground) instead of their semantic purpose (errorColor,
/// primaryBackground).
///
/// Appearance-based names break when themes change. A "redColor" used for
/// errors becomes misleading when the error color changes to orange.
/// Semantic names describe intent and remain valid across theme variants.
///
/// **BAD:**
/// ```dart
/// final redColor = Color(0xFFFF0000);
/// final blueBackground = Color(0xFF0000FF);
/// ```
///
/// **GOOD:**
/// ```dart
/// final errorColor = Color(0xFFFF0000);
/// final primaryBackground = Color(0xFF0000FF);
/// ```
class RequireSemanticColorsRule extends SaropaLintRule {
  RequireSemanticColorsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_semantic_colors',
    '[require_semantic_colors] Color variable is named by its visual appearance (e.g., redColor, blueBackground) rather than its semantic purpose (e.g., errorColor, primaryBackground). Appearance-based color names become misleading when themes change, dark mode inverts colors, or branding updates alter the palette. Developers reading the code assume the color is literally red, leading to confusion when it is actually orange after a theme update, and making it impossible to safely refactor theme colors without auditing every usage site. {v2}',
    correctionMessage:
        'Rename the variable to describe its purpose (errorColor, successColor, primaryBackground, surfaceColor) rather than its appearance (redColor, blueText).',
    severity: DiagnosticSeverity.INFO,
  );

  /// Color words that indicate appearance-based naming.
  static const Set<String> _colorAppearanceWords = <String>{
    'red',
    'blue',
    'green',
    'yellow',
    'orange',
    'purple',
    'pink',
    'cyan',
    'magenta',
    'teal',
    'indigo',
    'amber',
    'lime',
    'brown',
    'grey',
    'gray',
    'violet',
    'maroon',
    'navy',
    'coral',
    'salmon',
    'turquoise',
    'crimson',
    'scarlet',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addVariableDeclaration((VariableDeclaration node) {
      // Check if the type is Color-related
      final AstNode? parent = node.parent;
      if (parent is! VariableDeclarationList) return;

      final String? typeStr = parent.type?.toSource();
      final bool isColorType =
          typeStr != null &&
          (typeStr == 'Color' ||
              typeStr == 'Color?' ||
              typeStr == 'MaterialColor' ||
              typeStr == 'MaterialAccentColor');

      // Also check initializer for Color constructor
      final Expression? initializer = node.initializer;
      final bool hasColorInit =
          initializer != null &&
          (initializer.toSource().startsWith('Color(') ||
              initializer.toSource().startsWith('const Color(') ||
              initializer.toSource().startsWith('Colors.'));

      if (!isColorType && !hasColorInit) return;

      // Check if the variable name contains a raw color word
      final String name = node.name.lexeme.toLowerCase();
      for (final String colorWord in _colorAppearanceWords) {
        if (name.contains(colorWord)) {
          // Skip if it's a well-known framework name like Colors.red
          if (name == colorWord) return;

          reporter.atNode(node);
          return;
        }
      }
    });
  }
}
