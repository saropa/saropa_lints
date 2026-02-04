// ignore_for_file: depend_on_referenced_packages

/// Theming rules for Flutter applications.
///
/// These rules enforce consistent theming practices including dark mode
/// support, elevation handling, and proper use of ThemeExtensions.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when MaterialApp is created without a darkTheme parameter.
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
  const RequireDarkModeTestingRule() : super(code: _code);

  /// Dark mode support is an accessibility requirement.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_dark_mode_testing',
    problemMessage:
        '[require_dark_mode_testing] MaterialApp missing darkTheme. App won\'t adapt to dark mode. Apps should support dark mode for accessibility and user preference. Without darkTheme, the app won\'t adapt when the user enables dark mode.',
    correctionMessage:
        'Add darkTheme parameter to support dark mode. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
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
  const AvoidElevationOpacityInDarkRule() : super(code: _code);

  /// Visual issues in dark mode affect user experience.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_elevation_opacity_in_dark',
    problemMessage:
        '[avoid_elevation_opacity_in_dark] High elevation (>4) without brightness check. Shadows look poor in dark mode. Elevation shadows appear differently in dark mode. Material Design recommends using surface overlays instead of shadows in dark themes.',
    correctionMessage:
        'Check Theme.of(context).brightness or use lower elevation in dark mode. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
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
        reporter.atNode(elevationArg, code);
      } else if (expr is DoubleLiteral && expr.value > 4) {
        reporter.atNode(elevationArg, code);
      }
    });
  }
}

/// Warns when ThemeData uses ad-hoc color fields instead of ThemeExtension.
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
  const PreferThemeExtensionsRule() : super(code: _code);

  /// Maintainability issue for theming architecture.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    name: 'prefer_theme_extensions',
    problemMessage:
        '[prefer_theme_extensions] ThemeData.copyWith used for custom colors. Prefer ThemeExtension. ThemeExtension provides type-safe, documented custom theme properties. Ad-hoc fields on ThemeData are not standardized and harder to maintain.',
    correctionMessage:
        'Create a ThemeExtension subclass for type-safe custom theme properties. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
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
            reporter.atNode(node, code);
            return;
          }
        }
      }
    });
  }
}
