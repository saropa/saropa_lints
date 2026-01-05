// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Internationalization lint rules for Flutter/Dart applications.
///
/// These rules help ensure apps are properly internationalized and
/// ready for localization into multiple languages.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Warns when hardcoded user-facing strings are detected.
///
/// User-facing strings should use localization (l10n) instead of
/// hardcoded text for proper internationalization.
///
/// **BAD:**
/// ```dart
/// Text('Welcome to the app')
/// ElevatedButton(child: Text('Submit'))
/// ```
///
/// **GOOD:**
/// ```dart
/// Text(AppLocalizations.of(context).welcome)
/// ElevatedButton(child: Text(l10n.submit))
/// ```
class AvoidHardcodedStringsInUiRule extends DartLintRule {
  const AvoidHardcodedStringsInUiRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_strings_in_ui',
    problemMessage: 'Hardcoded string in UI should be localized.',
    correctionMessage: 'Use AppLocalizations or your l10n solution instead.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _textWidgets = <String>{
    'Text',
    'RichText',
    'SelectableText',
    'DefaultTextStyle',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Skip test files and generated files
    final String path = resolver.source.fullName;
    if (path.contains('_test.dart') ||
        path.contains('.g.dart') ||
        path.contains('.freezed.dart')) {
      return;
    }

    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName == null) return;

      // Check Text widgets
      if (_textWidgets.contains(constructorName)) {
        final NodeList<Expression> args = node.argumentList.arguments;
        if (args.isNotEmpty) {
          final Expression firstArg = args.first;
          if (firstArg is SimpleStringLiteral) {
            // Skip empty strings and single characters
            if (firstArg.value.length > 1) {
              reporter.atNode(firstArg, code);
            }
          }
        }
      }

      // Check button labels
      if (constructorName.contains('Button')) {
        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression && arg.name.label.name == 'child') {
            _checkForHardcodedText(arg.expression, reporter);
          }
        }
      }
    });
  }

  void _checkForHardcodedText(Expression expr, DiagnosticReporter reporter) {
    if (expr is InstanceCreationExpression) {
      final String? name = expr.constructorName.type.element?.name;
      if (name == 'Text') {
        final NodeList<Expression> args = expr.argumentList.arguments;
        if (args.isNotEmpty && args.first is SimpleStringLiteral) {
          final SimpleStringLiteral literal = args.first as SimpleStringLiteral;
          if (literal.value.length > 1) {
            reporter.atNode(literal, code);
          }
        }
      }
    }
  }
}

/// Warns when locale-dependent formatting is not used.
///
/// Dates, numbers, and currencies should use locale-aware formatting.
///
/// **BAD:**
/// ```dart
/// Text('\$${price.toStringAsFixed(2)}')
/// Text('${date.day}/${date.month}/${date.year}')
/// ```
///
/// **GOOD:**
/// ```dart
/// Text(NumberFormat.currency(locale: locale).format(price))
/// Text(DateFormat.yMd(locale).format(date))
/// ```
class RequireLocaleAwareFormattingRule extends DartLintRule {
  const RequireLocaleAwareFormattingRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_locale_aware_formatting',
    problemMessage: 'Use locale-aware formatting for dates and numbers.',
    correctionMessage: 'Use DateFormat, NumberFormat, or intl package.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for manual number formatting
      if (methodName == 'toStringAsFixed' ||
          methodName == 'toStringAsPrecision') {
        // Check if inside a Text widget or string interpolation
        AstNode? current = node.parent;
        while (current != null) {
          if (current is InterpolationExpression ||
              current is StringInterpolation) {
            reporter.atNode(node, code);
            return;
          }
          current = current.parent;
        }
      }
    });

    // Check for manual date formatting in interpolations
    context.registry.addStringInterpolation((StringInterpolation node) {
      final String source = node.toSource().toLowerCase();
      if (source.contains('.day') ||
          source.contains('.month') ||
          source.contains('.year') ||
          source.contains('.hour') ||
          source.contains('.minute')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when text direction is not considered.
///
/// Apps should support RTL (right-to-left) languages properly.
///
/// **BAD:**
/// ```dart
/// Padding(padding: EdgeInsets.only(left: 16))
/// Row(children: [icon, Text(label)]) // Icon always on left
/// ```
///
/// **GOOD:**
/// ```dart
/// Padding(padding: EdgeInsetsDirectional.only(start: 16))
/// Row(children: [icon, Text(label)], textDirection: TextDirection.ltr)
/// ```
class RequireDirectionalWidgetsRule extends DartLintRule {
  const RequireDirectionalWidgetsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_directional_widgets',
    problemMessage: 'Use directional widgets for RTL language support.',
    correctionMessage: 'Use EdgeInsetsDirectional, AlignmentDirectional, etc.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String constructorSource = node.constructorName.toSource();

      // Check for non-directional EdgeInsets.only with left/right
      if (constructorSource.contains('EdgeInsets.only')) {
        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression) {
            final String name = arg.name.label.name;
            if (name == 'left' || name == 'right') {
              reporter.atNode(node, code);
              return;
            }
          }
        }
      }

      // Check for Alignment with left/right
      if (constructorSource == 'Alignment') {
        final String source = node.toSource().toLowerCase();
        if (source.contains('left') || source.contains('right')) {
          reporter.atNode(node, code);
        }
      }
    });

    // Check for Positioned.left/right
    context.registry.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target is Identifier && target.name == 'Positioned') {
        final String methodName = node.methodName.name;
        if (methodName == 'left' || methodName == 'right') {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when plural forms are not handled correctly.
///
/// Different languages have different plural rules (e.g., Russian has
/// singular, few, many; Arabic has six forms).
///
/// **BAD:**
/// ```dart
/// Text('$count items')
/// Text(count == 1 ? '1 item' : '$count items')
/// ```
///
/// **GOOD:**
/// ```dart
/// Text(Intl.plural(count,
///   zero: 'No items',
///   one: '1 item',
///   other: '$count items',
/// ))
/// ```
class RequirePluralHandlingRule extends DartLintRule {
  const RequirePluralHandlingRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_plural_handling',
    problemMessage: 'Plural forms should use Intl.plural or similar.',
    correctionMessage: 'Use Intl.plural() for proper pluralization.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _pluralIndicators = <String>{
    'items',
    'files',
    'messages',
    'users',
    'comments',
    'results',
    'days',
    'hours',
    'minutes',
    'seconds',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addStringInterpolation((StringInterpolation node) {
      final String source = node.toSource().toLowerCase();

      // Check if interpolation contains count-like variable and plural word
      bool hasCountVariable = false;
      for (final InterpolationElement element in node.elements) {
        if (element is InterpolationExpression) {
          final String exprSource = element.expression.toSource().toLowerCase();
          if (exprSource.contains('count') ||
              exprSource.contains('length') ||
              exprSource.contains('size') ||
              exprSource.contains('total')) {
            hasCountVariable = true;
            break;
          }
        }
      }

      if (hasCountVariable) {
        for (final String plural in _pluralIndicators) {
          if (source.contains(plural)) {
            reporter.atNode(node, code);
            return;
          }
        }
      }
    });

    // Check for simple ternary plural handling
    context.registry.addConditionalExpression((ConditionalExpression node) {
      final String condSource = node.condition.toSource().toLowerCase();
      if (condSource.contains('== 1') || condSource.contains('!= 1')) {
        final String thenSource = node.thenExpression.toSource().toLowerCase();
        final String elseSource = node.elseExpression.toSource().toLowerCase();

        for (final String plural in _pluralIndicators) {
          final String singular = plural.substring(0, plural.length - 1);
          if ((thenSource.contains(singular) && elseSource.contains(plural)) ||
              (elseSource.contains(singular) && thenSource.contains(plural))) {
            reporter.atNode(node, code);
            return;
          }
        }
      }
    });
  }
}

/// Warns when locale is hardcoded instead of using device locale.
///
/// Apps should respect the user's device locale settings.
///
/// **BAD:**
/// ```dart
/// DateFormat('yyyy-MM-dd', 'en_US').format(date)
/// NumberFormat.currency(locale: 'en_US').format(price)
/// ```
///
/// **GOOD:**
/// ```dart
/// DateFormat('yyyy-MM-dd', Localizations.localeOf(context).toString())
/// NumberFormat.currency(locale: locale).format(price)
/// ```
class AvoidHardcodedLocaleRule extends DartLintRule {
  const AvoidHardcodedLocaleRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_locale',
    problemMessage: 'Locale should not be hardcoded.',
    correctionMessage: 'Use Localizations.localeOf(context) or similar.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static final RegExp _localePattern = RegExp(r"'[a-z]{2}_[A-Z]{2}'");

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      // Check for locale patterns like 'en_US', 'de_DE', etc.
      if (_localePattern.hasMatch("'$value'")) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when string concatenation is used for sentences.
///
/// Word order varies by language, so concatenation breaks i18n.
///
/// **BAD:**
/// ```dart
/// Text('Hello ' + userName + '!')
/// Text('You have $count new ' + (count == 1 ? 'message' : 'messages'))
/// ```
///
/// **GOOD:**
/// ```dart
/// Text(l10n.greeting(userName))
/// Text(l10n.newMessages(count))
/// ```
class AvoidStringConcatenationInUiRule extends DartLintRule {
  const AvoidStringConcatenationInUiRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_string_concatenation_in_ui',
    problemMessage: 'String concatenation breaks internationalization.',
    correctionMessage: 'Use localized strings with placeholders.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'Text') return;

      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression firstArg = args.first;

      // Check for string concatenation with +
      if (firstArg is BinaryExpression && firstArg.operator.lexeme == '+') {
        _checkBinaryForStringConcat(firstArg, reporter);
      }
    });
  }

  void _checkBinaryForStringConcat(
    BinaryExpression expr,
    DiagnosticReporter reporter,
  ) {
    // Check if either operand is a string literal
    if (expr.leftOperand is SimpleStringLiteral ||
        expr.rightOperand is SimpleStringLiteral) {
      reporter.atNode(expr, code);
    }
  }
}

/// Warns when images contain text that should be localized.
///
/// Text in images cannot be translated.
///
/// **BAD:**
/// ```dart
/// Image.asset('assets/welcome_banner_en.png')
/// ```
///
/// **GOOD:**
/// ```dart
/// Image.asset('assets/welcome_banner_${locale.languageCode}.png')
/// // Or use separate text overlay
/// Stack(children: [
///   Image.asset('assets/welcome_banner.png'),
///   Text(l10n.welcomeMessage),
/// ])
/// ```
class AvoidTextInImagesRule extends DartLintRule {
  const AvoidTextInImagesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_text_in_images',
    problemMessage:
        'Image path suggests embedded text that cannot be localized.',
    correctionMessage: 'Use locale-specific images or text overlays.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _textIndicators = <String>{
    '_en',
    '_english',
    '_text',
    '_label',
    '_title',
    '_button',
    '_banner',
    '_header',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target is! Identifier) return;

      if (target.name != 'Image') return;

      final String methodName = node.methodName.name;
      if (methodName != 'asset' && methodName != 'network') return;

      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression firstArg = args.first;
      if (firstArg is SimpleStringLiteral) {
        final String path = firstArg.value.toLowerCase();
        for (final String indicator in _textIndicators) {
          if (path.contains(indicator)) {
            reporter.atNode(firstArg, code);
            return;
          }
        }
      }
    });
  }
}

/// Warns when app name or branding is hardcoded.
///
/// App names may need to vary by market or locale.
///
/// **BAD:**
/// ```dart
/// AppBar(title: Text('MyApp'))
/// Text('Welcome to MyApp!')
/// ```
///
/// **GOOD:**
/// ```dart
/// AppBar(title: Text(AppConfig.appName))
/// Text(l10n.welcomeToApp(AppConfig.appName))
/// ```
class AvoidHardcodedAppNameRule extends DartLintRule {
  const AvoidHardcodedAppNameRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_app_name',
    problemMessage: 'App name should not be hardcoded in UI.',
    correctionMessage: 'Use a configuration constant or localized string.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'AppBar') return;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'title') {
          if (arg.expression is InstanceCreationExpression) {
            final InstanceCreationExpression textWidget =
                arg.expression as InstanceCreationExpression;
            final String? textName =
                textWidget.constructorName.type.element?.name;

            if (textName == 'Text') {
              final NodeList<Expression> textArgs =
                  textWidget.argumentList.arguments;
              if (textArgs.isNotEmpty &&
                  textArgs.first is SimpleStringLiteral) {
                // AppBar title with hardcoded string
                reporter.atNode(textArgs.first, code);
              }
            }
          }
        }
      }
    });
  }
}
