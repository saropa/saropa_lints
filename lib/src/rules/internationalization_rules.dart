// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Internationalization lint rules for Flutter/Dart applications.
///
/// These rules help ensure apps are properly internationalized and
/// ready for localization into multiple languages.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

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
class AvoidHardcodedStringsInUiRule extends SaropaLintRule {
  const AvoidHardcodedStringsInUiRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_strings_in_ui',
    problemMessage:
        '[avoid_hardcoded_strings_in_ui] Hardcoded user-facing string. Cannot be translated to other languages. User-facing strings should use localization (l10n) instead of hardcoded text for proper internationalization.',
    correctionMessage:
        'Replace with l10n.yourKey or AppLocalizations.of(context).yourKey. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _textWidgets = <String>{
    'Text',
    'RichText',
    'SelectableText',
    'DefaultTextStyle',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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

  void _checkForHardcodedText(
      Expression expr, SaropaDiagnosticReporter reporter) {
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
class RequireLocaleAwareFormattingRule extends SaropaLintRule {
  const RequireLocaleAwareFormattingRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_locale_aware_formatting',
    problemMessage:
        '[require_locale_aware_formatting] Manual date/number formatting ignores locale. Will display wrong format for users. Dates, numbers, and currencies should use locale-aware formatting.',
    correctionMessage:
        'Use NumberFormat.currency(locale: locale).format(n) or DateFormat.yMd(locale).format(d).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
class RequireDirectionalWidgetsRule extends SaropaLintRule {
  const RequireDirectionalWidgetsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_directional_widgets',
    problemMessage:
        '[require_directional_widgets] Non-directional widget. Layout will be wrong for RTL languages (Arabic, Hebrew). This prevents proper localization, causing text to display incorrectly for users in non-English locales.',
    correctionMessage:
        'Replace left/right with start/end: EdgeInsetsDirectional.only(start: 16). Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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

  @override
  List<Fix> getFixes() => [_RequireDirectionalWidgetsFix()];
}

/// Quick fix for [RequireDirectionalWidgetsRule].
///
/// Converts `EdgeInsets.only(left: x, right: y)` to
/// `EdgeInsetsDirectional.only(start: x, end: y)` for RTL language support.
class _RequireDirectionalWidgetsFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final String constructorSource = node.constructorName.toSource();

      // Fix EdgeInsets.only to EdgeInsetsDirectional.only
      if (constructorSource.contains('EdgeInsets.only')) {
        final changeBuilder = reporter.createChangeBuilder(
          message: 'Convert to EdgeInsetsDirectional with start/end',
          priority: 80,
        );

        changeBuilder.addDartFileEdit((builder) {
          // Replace EdgeInsets with EdgeInsetsDirectional
          final constructorName = node.constructorName;
          builder.addSimpleReplacement(
            constructorName.sourceRange,
            'EdgeInsetsDirectional.only',
          );

          // Replace left/right with start/end in arguments
          for (final arg in node.argumentList.arguments) {
            if (arg is NamedExpression) {
              final paramName = arg.name.label.name;
              if (paramName == 'left') {
                builder.addSimpleReplacement(
                  arg.name.label.sourceRange,
                  'start',
                );
              } else if (paramName == 'right') {
                builder.addSimpleReplacement(
                  arg.name.label.sourceRange,
                  'end',
                );
              }
            }
          }
        });
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
class RequirePluralHandlingRule extends SaropaLintRule {
  const RequirePluralHandlingRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_plural_handling',
    problemMessage:
        '[require_plural_handling] Simple plural logic fails for many languages (Russian, Arabic have complex plural rules). Different languages have different plural rules (e.g., Russian has singular, few, many; Arabic has six forms).',
    correctionMessage:
        "Use Intl.plural(count, zero: '..', one: '..', other: '..'). Verify the change works correctly with existing tests and add coverage for the new behavior.",
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
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
class AvoidHardcodedLocaleRule extends SaropaLintRule {
  const AvoidHardcodedLocaleRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_locale',
    problemMessage:
        "[avoid_hardcoded_locale] Hardcoded locale ignores user's device settings. Apps should respect the user\'s device locale settings.",
    correctionMessage:
        'Use Localizations.localeOf(context).toString() to get device locale. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static final RegExp _localePattern = RegExp(r"'[a-z]{2}_[A-Z]{2}'");

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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

  // Note: No quick fix provided - the correct replacement depends on context
  // (BuildContext availability, variable naming preferences, etc.)
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
class AvoidStringConcatenationInUiRule extends SaropaLintRule {
  const AvoidStringConcatenationInUiRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_string_concatenation_in_ui',
    problemMessage:
        '[avoid_string_concatenation_in_ui] String concatenation breaks internationalization. Word order varies by language, so concatenation breaks i18n.',
    correctionMessage:
        'Use localized strings with placeholders. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
    SaropaDiagnosticReporter reporter,
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
class AvoidTextInImagesRule extends SaropaLintRule {
  const AvoidTextInImagesRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_text_in_images',
    problemMessage:
        '[avoid_text_in_images] Image path suggests embedded text that cannot be localized. Text in images cannot be translated. This prevents proper localization, causing text to display incorrectly for users in non-English locales.',
    correctionMessage:
        'Use locale-specific images or text overlays. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
class AvoidHardcodedAppNameRule extends SaropaLintRule {
  const AvoidHardcodedAppNameRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_app_name',
    problemMessage:
        '[avoid_hardcoded_app_name] App name must not be hardcoded in UI. App names may need to vary by market or locale. App name or branding is hardcoded.',
    correctionMessage:
        'Use a configuration constant or localized string. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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

/// Warns when raw DateTime formatting is used instead of DateFormat.
///
/// DateTime.toString() and manual formatting produce inconsistent results
/// across locales. Use DateFormat from intl package for proper i18n.
///
/// **BAD:**
/// ```dart
/// Text(dateTime.toString())
/// Text('${date.year}-${date.month}-${date.day}')
/// Text(date.toIso8601String()) // In UI
/// ```
///
/// **GOOD:**
/// ```dart
/// Text(DateFormat.yMd(locale).format(dateTime))
/// Text(DateFormat('yyyy-MM-dd').format(date))
/// ```
class PreferDateFormatRule extends SaropaLintRule {
  const PreferDateFormatRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_date_format',
    problemMessage:
        '[prefer_date_format] Raw DateTime formatting ignores user locale. DateTime.toString() and manual formatting produce inconsistent results across locales. Use DateFormat from intl package for proper i18n.',
    correctionMessage:
        'Use DateFormat from intl package for locale-aware formatting. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for DateTime.toString() in UI context
      if (methodName == 'toString' || methodName == 'toIso8601String') {
        final Expression? target = node.realTarget;
        if (target != null) {
          final String? targetType = target.staticType?.toString();
          if (targetType == 'DateTime' || targetType == 'DateTime?') {
            // Check if inside string interpolation or Text widget
            if (_isInUiContext(node)) {
              reporter.atNode(node, code);
            }
          }
        }
      }
    });
  }

  bool _isInUiContext(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is InterpolationExpression ||
          current is StringInterpolation) {
        return true;
      }
      if (current is InstanceCreationExpression) {
        final String? name = current.constructorName.type.element?.name;
        if (name == 'Text' || name == 'RichText') {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when Intl.message lacks the name parameter.
///
/// The name parameter is required for message extraction tools and
/// enables proper identification of messages across the codebase.
///
/// **BAD:**
/// ```dart
/// Intl.message('Welcome back')
/// ```
///
/// **GOOD:**
/// ```dart
/// Intl.message('Welcome back', name: 'welcomeBack')
/// ```
class PreferIntlNameRule extends SaropaLintRule {
  const PreferIntlNameRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_intl_name',
    problemMessage:
        '[prefer_intl_name] Intl.message without name parameter. The name parameter is required for message extraction tools and enables proper identification of messages across the codebase.',
    correctionMessage:
        'Add name parameter for message extraction tools. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!_isIntlMessage(node)) return;

      if (!_hasNamedParameter(node, 'name')) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isIntlMessage(MethodInvocation node) {
    final String methodName = node.methodName.name;
    if (methodName != 'message') return false;

    final Expression? target = node.target;
    if (target is SimpleIdentifier && target.name == 'Intl') {
      return true;
    }
    return false;
  }

  bool _hasNamedParameter(MethodInvocation node, String paramName) {
    for (final Expression arg in node.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == paramName) {
        return true;
      }
    }
    return false;
  }

  @override
  List<Fix> getFixes() => [_PreferIntlNameFix()];
}

/// Quick fix for [PreferIntlNameRule].
///
/// Adds `name: 'messageName'` parameter to `Intl.message()` calls.
/// The user should customize the name to match the message purpose.
class _PreferIntlNameFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      // Check if it's Intl.message
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Intl') return;
      if (node.methodName.name != 'message') return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Add name parameter',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        final args = node.argumentList.arguments;
        if (args.isEmpty) return;

        // Add name parameter after the first argument
        final insertOffset = args.first.end;
        builder.addSimpleInsertion(insertOffset, ", name: 'messageName'");
      });
    });
  }
}

/// Warns when Intl.message lacks a description parameter.
///
/// Descriptions help translators understand context and produce
/// accurate translations.
///
/// **BAD:**
/// ```dart
/// Intl.message('Save', name: 'save')
/// ```
///
/// **GOOD:**
/// ```dart
/// Intl.message(
///   'Save',
///   name: 'save',
///   desc: 'Button label to save current document',
/// )
/// ```
class PreferProvidingIntlDescriptionRule extends SaropaLintRule {
  const PreferProvidingIntlDescriptionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_providing_intl_description',
    problemMessage:
        '[prefer_providing_intl_description] Intl.message without description. Descriptions help translators understand context and produce accurate translations.',
    correctionMessage:
        'Add desc parameter to help translators understand context. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!_isIntlMessage(node)) return;

      if (!_hasNamedParameter(node, 'desc')) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isIntlMessage(MethodInvocation node) {
    final String methodName = node.methodName.name;
    if (methodName != 'message') return false;

    final Expression? target = node.target;
    if (target is SimpleIdentifier && target.name == 'Intl') {
      return true;
    }
    return false;
  }

  bool _hasNamedParameter(MethodInvocation node, String paramName) {
    for (final Expression arg in node.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == paramName) {
        return true;
      }
    }
    return false;
  }

  @override
  List<Fix> getFixes() => [_PreferProvidingIntlDescriptionFix()];
}

/// Quick fix for [PreferProvidingIntlDescriptionRule].
///
/// Adds `desc: 'TODO: Add description for translators'` parameter to
/// `Intl.message()` calls. The TODO reminds developers to provide context.
class _PreferProvidingIntlDescriptionFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      // Check if it's Intl.message
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Intl') return;
      if (node.methodName.name != 'message') return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Add desc parameter',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        final args = node.argumentList.arguments;
        if (args.isEmpty) return;

        // Add desc parameter after the last argument
        final lastArg = args.last;
        final insertOffset = lastArg.end;
        builder.addSimpleInsertion(
          insertOffset,
          ", desc: 'TODO: Add description for translators'",
        );
      });
    });
  }
}

/// Warns when Intl.message with placeholders lacks examples.
///
/// Examples help translators see how placeholders are used and
/// produce grammatically correct translations.
///
/// **BAD:**
/// ```dart
/// Intl.message(
///   'Hello $name',
///   name: 'avoid_generic_greeting_text',
///   args: [name],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Intl.message(
///   'Hello $name',
///   name: 'avoid_generic_greeting_text',
///   args: [name],
///   examples: const {'name': 'John'},
/// )
/// ```
class PreferProvidingIntlExamplesRule extends SaropaLintRule {
  const PreferProvidingIntlExamplesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_providing_intl_examples',
    problemMessage:
        '[prefer_providing_intl_examples] Intl.message with args but no examples. Examples help translators see how placeholders are used and produce grammatically correct translations.',
    correctionMessage:
        'Add examples parameter to help translators. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!_isIntlMessage(node)) return;

      // Only check if args parameter is present
      if (!_hasNamedParameter(node, 'args')) return;

      if (!_hasNamedParameter(node, 'examples')) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isIntlMessage(MethodInvocation node) {
    final String methodName = node.methodName.name;
    if (methodName != 'message') return false;

    final Expression? target = node.target;
    if (target is SimpleIdentifier && target.name == 'Intl') {
      return true;
    }
    return false;
  }

  bool _hasNamedParameter(MethodInvocation node, String paramName) {
    for (final Expression arg in node.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == paramName) {
        return true;
      }
    }
    return false;
  }

  @override
  List<Fix> getFixes() => [_PreferProvidingIntlExamplesFix()];
}

/// Quick fix for [PreferProvidingIntlExamplesRule].
///
/// Adds `examples: const {}` parameter to `Intl.message()` calls.
/// The user should populate the map with placeholder examples.
class _PreferProvidingIntlExamplesFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      // Check if it's Intl.message
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Intl') return;
      if (node.methodName.name != 'message') return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Add examples parameter',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        final args = node.argumentList.arguments;
        if (args.isEmpty) return;

        // Add examples parameter after the last argument
        final lastArg = args.last;
        final insertOffset = lastArg.end;
        builder.addSimpleInsertion(
          insertOffset,
          ", examples: const {}",
        );
      });
    });
  }
}

/// Warns when intl package is used without initializing Intl.defaultLocale.
///
/// The intl package requires Intl.defaultLocale to be set for proper locale
/// handling. Without initialization, date/number formatting and pluralization
/// may use unexpected system defaults, causing inconsistent behavior across
/// platforms and devices.
///
/// **BAD:**
/// ```dart
/// // Using intl without initialization
/// void main() {
///   runApp(MyApp());
/// }
///
/// // Later in the code
/// final formatted = DateFormat.yMd().format(date); // Uses unpredictable default
/// final message = Intl.message('Hello'); // Locale unknown
/// ```
///
/// **GOOD:**
/// ```dart
/// import 'package:intl/intl.dart';
/// import 'package:intl/date_symbol_data_local.dart';
///
/// void main() async {
///   Intl.defaultLocale = 'en_US';
///   await initializeDateFormatting('en_US');
///   runApp(MyApp());
/// }
///
/// // Or with locale from device
/// void main() async {
///   final deviceLocale = Platform.localeName;
///   Intl.defaultLocale = deviceLocale;
///   await initializeDateFormatting(deviceLocale);
///   runApp(MyApp());
/// }
/// ```
class RequireIntlLocaleInitializationRule extends SaropaLintRule {
  const RequireIntlLocaleInitializationRule() : super(code: _code);

  /// Medium impact - affects formatting but not crashes.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_intl_locale_initialization',
    problemMessage:
        '[require_intl_locale_initialization] Intl package used without Intl.defaultLocale initialization. The intl package requires Intl.defaultLocale to be set for proper locale handling. Without initialization, date/number formatting and pluralization may use unexpected system defaults, causing inconsistent behavior across platforms and devices.',
    correctionMessage:
        'Initialize Intl.defaultLocale in main() before using DateFormat, NumberFormat, or Intl.message.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Intl APIs that require locale initialization.
  static const Set<String> _intlTypes = <String>{
    'DateFormat',
    'NumberFormat',
    'Intl',
  };

  /// Methods on Intl that require locale.
  static const Set<String> _intlMethods = <String>{
    'message',
    'plural',
    'select',
    'gender',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Track if we've seen Intl.defaultLocale assignment in this file
    bool hasLocaleInit = false;
    final List<AstNode> intlUsages = <AstNode>[];

    // First pass: check for Intl.defaultLocale assignment
    context.registry.addAssignmentExpression((AssignmentExpression node) {
      final String leftSource = node.leftHandSide.toSource();
      if (leftSource == 'Intl.defaultLocale' ||
          leftSource.endsWith('.defaultLocale')) {
        hasLocaleInit = true;
      }
    });

    // Check for initializeDateFormatting call (also indicates proper setup)
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName == 'initializeDateFormatting') {
        hasLocaleInit = true;
        return;
      }

      // Track Intl.message, Intl.plural, etc. usage
      final Expression? target = node.target;
      if (target is SimpleIdentifier && target.name == 'Intl') {
        if (_intlMethods.contains(methodName)) {
          intlUsages.add(node);
        }
      }
    });

    // Check for DateFormat, NumberFormat constructor usage
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (_intlTypes.contains(typeName)) {
        intlUsages.add(node);
      }
    });

    // Check for DateFormat.xxx() or NumberFormat.xxx() factory constructors
    context.registry.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target is SimpleIdentifier) {
        final String targetName = target.name;
        if (targetName == 'DateFormat' || targetName == 'NumberFormat') {
          intlUsages.add(node);
        }
      }
    });

    // Report at the end of file processing if intl is used without init
    context.addPostRunCallback(() {
      if (!hasLocaleInit && intlUsages.isNotEmpty) {
        // Report only the first usage to avoid noise
        reporter.atNode(intlUsages.first, code);
      }
    });
  }
}

/// Warns when DateFormat is used without explicit locale parameter.
///
/// Alias: dateformat_locale, date_format_locale_required
///
/// DateFormat without locale uses the system default, which varies across
/// devices and can produce unexpected results for users.
///
/// **BAD:**
/// ```dart
/// DateFormat('yyyy-MM-dd').format(date)
/// DateFormat.yMd().format(date)
/// ```
///
/// **GOOD:**
/// ```dart
/// DateFormat('yyyy-MM-dd', 'en_US').format(date)
/// DateFormat.yMd(locale).format(date)
/// ```
class RequireIntlDateFormatLocaleRule extends SaropaLintRule {
  const RequireIntlDateFormatLocaleRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_intl_date_format_locale',
    problemMessage:
        '[require_intl_date_format_locale] DateFormat created without an explicit locale parameter. The format output varies unpredictably across devices and platforms because each uses a different system default locale. Users in different regions see dates in unexpected formats (e.g., MM/DD/YYYY vs DD/MM/YYYY), leading to confusion about whether 01/02 means January 2nd or February 1st.',
    correctionMessage:
        'Always provide a locale to DateFormat (e.g., DateFormat.yMd(locale)) to ensure dates are formatted consistently for all users.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check DateFormat constructor: DateFormat('pattern')
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'DateFormat') return;

      // DateFormat constructor takes pattern as first arg, locale as second
      // If only one arg, locale is missing
      final args = node.argumentList.arguments;
      if (args.length < 2) {
        reporter.atNode(node, code);
      }
    });

    // Check DateFormat factory constructors: DateFormat.yMd()
    context.registry.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'DateFormat') return;

      // Factory constructors like yMd, yMMM, etc. take locale as first arg
      final String methodName = node.methodName.name;
      // Skip the main constructor (handled above)
      if (methodName == 'DateFormat') return;

      // cspell:ignore MMMMEEE
      // Common factory constructors that need locale
      const Set<String> factoryMethods = <String>{
        'yMd',
        'yMMMd',
        'yMMMMd',
        'yMMMM',
        'yMMM',
        'yM',
        'y',
        'Hm',
        'Hms',
        'jm',
        'jms',
        'E',
        'EEEE',
        'MMMd',
        'MMMMd',
        'Md',
        'MEd',
        'MMMEd',
        'MMMMEEEEd',
      };

      if (factoryMethods.contains(methodName)) {
        // Factory methods take optional locale as first argument
        if (node.argumentList.arguments.isEmpty) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when NumberFormat is used without explicit locale parameter.
///
/// Alias: numberformat_locale, number_format_locale_required
///
/// NumberFormat without locale uses system defaults which vary by device.
/// Decimal separators and grouping differ by locale (1,234.56 vs 1.234,56).
///
/// **BAD:**
/// ```dart
/// NumberFormat('#,###').format(number)
/// NumberFormat.compact().format(number)
/// NumberFormat.decimalPattern().format(number)
/// ```
///
/// **GOOD:**
/// ```dart
/// NumberFormat('#,###', 'en_US').format(number)
/// NumberFormat.compact(locale: locale).format(number)
/// NumberFormat.decimalPattern(locale).format(number)
/// ```
class RequireNumberFormatLocaleRule extends SaropaLintRule {
  const RequireNumberFormatLocaleRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_number_format_locale',
    problemMessage:
        '[require_number_format_locale] NumberFormat without explicit locale. 1,234.56 vs 1.234,56 varies by device. Consequence: Numbers may be formatted incorrectly for users in different locales, leading to misinterpretation.',
    correctionMessage:
        'Pass a locale to NumberFormat (e.g., NumberFormat.decimalPattern(locale)) so numbers display correctly for every user.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check NumberFormat constructor
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'NumberFormat') return;

      // NumberFormat constructor takes pattern as first arg, locale as second
      final args = node.argumentList.arguments;
      if (args.length < 2) {
        reporter.atNode(node, code);
      }
    });

    // Check NumberFormat factory constructors
    context.registry.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'NumberFormat') return;

      // Factory constructors that need locale
      const Set<String> factoryMethods = <String>{
        'compact',
        'compactLong',
        'compactSimpleCurrency',
        'compactCurrency',
        'currency',
        'decimalPattern',
        'decimalPercentPattern',
        'percentPattern',
        'scientificPattern',
        'simpleCurrency',
      };

      final String methodName = node.methodName.name;
      if (!factoryMethods.contains(methodName)) return;

      // Check if locale is provided (as first positional or named 'locale')
      bool hasLocale = false;
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'locale') {
          hasLocale = true;
          break;
        }
        // First positional argument for methods that take locale positionally
        if (arg is! NamedExpression &&
            node.argumentList.arguments.first == arg) {
          // Some methods like decimalPattern take locale as first positional
          if (methodName == 'decimalPattern' ||
              methodName == 'percentPattern' ||
              methodName == 'scientificPattern') {
            hasLocale = true;
            break;
          }
        }
      }

      if (!hasLocale) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when dates are formatted manually instead of using DateFormat.
///
/// Alias: no_manual_date_format, use_dateformat
///
/// Manual date formatting produces inconsistent results across locales
/// and is error-prone. Use DateFormat from intl package instead.
///
/// **BAD:**
/// ```dart
/// '${date.day}/${date.month}/${date.year}'
/// '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day}'
/// date.toIso8601String().substring(0, 10)
/// ```
///
/// **GOOD:**
/// ```dart
/// DateFormat.yMd(locale).format(date)
/// DateFormat('yyyy-MM-dd', locale).format(date)
/// ```
class AvoidManualDateFormattingRule extends SaropaLintRule {
  const AvoidManualDateFormattingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_manual_date_formatting',
    problemMessage:
        '[avoid_manual_date_formatting] Manual date formatting is error-prone, ignores locale, and can produce incorrect or confusing output for international users. This can break compliance, cause user confusion, and lead to support issues in global apps.',
    correctionMessage:
        'Use DateFormat from intl: DateFormat.yMd(locale).format(date). Audit all date formatting for locale coverage and add tests for internationalization. Document formatting logic for maintainability.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// DateTime properties that indicate manual formatting.
  static const Set<String> _dateProperties = <String>{
    'day',
    'month',
    'year',
    'hour',
    'minute',
    'second',
    'weekday',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addStringInterpolation((StringInterpolation node) {
      final int datePropertyCount = _countDateTimeProperties(node);

      if (datePropertyCount >= 2 && !_isNonDisplayContext(node)) {
        reporter.atNode(node, code);
      }
    });

    // Check for toIso8601String with substring (common manual pattern)
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'substring') return;

      final target = node.target;
      if (target is MethodInvocation &&
          target.methodName.name == 'toIso8601String') {
        reporter.atNode(node, code);
      }
    });
  }

  /// Counts interpolation expressions that access DateTime properties.
  static int _countDateTimeProperties(StringInterpolation node) {
    int count = 0;

    for (final element in node.elements) {
      if (element is InterpolationExpression) {
        final expr = element.expression;
        String? propertyName;
        String? targetTypeName;

        if (expr is PropertyAccess) {
          propertyName = expr.propertyName.name;
          targetTypeName = expr.target?.staticType?.getDisplayString();
        } else if (expr is PrefixedIdentifier) {
          propertyName = expr.identifier.name;
          targetTypeName = expr.prefix.staticType?.getDisplayString();
        }

        if (propertyName != null &&
            _dateProperties.contains(propertyName) &&
            _isDateTimeName(targetTypeName)) {
          count++;
        }
      }
    }

    return count;
  }

  /// Returns true if [typeName] is DateTime (or unknown).
  ///
  /// Unknown types (null) are treated as potentially DateTime to avoid
  /// false negatives when static type information is unavailable.
  static bool _isDateTimeName(String? typeName) {
    if (typeName == null) return true;
    return typeName == 'DateTime' || typeName == 'DateTime?';
  }

  /// Returns true if the string is used in a non-display context such as
  /// a map key, cache key, or internal identifier.
  static bool _isNonDisplayContext(StringInterpolation node) {
    final parent = node.parent;

    // Used as a map subscript: map['${d.year}-${d.month}']
    if (parent is IndexExpression && parent.index == node) return true;

    // Assigned to a variable with an internal-use name
    if (parent is VariableDeclaration) {
      final varName = parent.name.lexeme.toLowerCase();
      if (varName.contains('key') ||
          varName.contains('cache') ||
          varName.contains('tag') ||
          varName.contains('hash') ||
          varName.contains('bucket') ||
          varName.contains('identifier')) {
        return true;
      }
    }

    // Passed as argument to map lookup/mutation methods
    if (parent is ArgumentList) {
      final grandparent = parent.parent;
      if (grandparent is MethodInvocation) {
        const Set<String> mapMethods = <String>{
          'putIfAbsent',
          'containsKey',
          'containsValue',
          'remove',
        };
        if (mapMethods.contains(grandparent.methodName.name)) return true;
      }
    }

    return false;
  }
}

/// Warns when currency/money values are formatted manually.
///
/// Alias: use_currency_format, no_manual_currency
///
/// Currency formatting requires proper symbol placement, decimal handling,
/// and grouping which varies by locale. Use NumberFormat.currency instead.
///
/// **BAD:**
/// ```dart
/// '\$${price.toStringAsFixed(2)}'
/// '${price} USD'
/// 'USD ' + price.toString()
/// '\$' + amount.toStringAsFixed(2)
/// ```
///
/// **GOOD:**
/// ```dart
/// NumberFormat.currency(locale: locale, symbol: '\$').format(price)
/// NumberFormat.simpleCurrency(locale: locale).format(price)
/// ```
class RequireIntlCurrencyFormatRule extends SaropaLintRule {
  const RequireIntlCurrencyFormatRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_intl_currency_format',
    problemMessage:
        '[require_intl_currency_format] Currency value formatted manually using string interpolation with currency symbols. Symbol placement (prefix vs suffix), decimal separator (period vs comma), and digit grouping vary by locale. Manual formatting produces incorrect output for international users, causing financial confusion and misread amounts that undermine trust.',
    correctionMessage:
        'Use NumberFormat.currency(locale: locale, symbol: s) to format currency values, ensuring correct symbols and decimal placement for every locale.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Currency symbols that indicate manual currency formatting.
  static const Set<String> _currencySymbols = <String>{
    r'$',
    '€',
    '£',
    '¥',
    '₹',
    '₽',
    '₩',
    'USD',
    'EUR',
    'GBP',
    'JPY',
    'INR',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addStringInterpolation((StringInterpolation node) {
      // Check only literal string segments for currency symbols.
      // Using node.toSource() would match '$' from Dart interpolation
      // syntax, causing false positives on every interpolated string.
      bool hasCurrencySymbol = false;
      for (final element in node.elements) {
        if (element is InterpolationString) {
          final literal = element.value;
          for (final symbol in _currencySymbols) {
            if (literal.contains(symbol)) {
              hasCurrencySymbol = true;
              break;
            }
          }
          if (hasCurrencySymbol) break;
        }
      }

      if (!hasCurrencySymbol) return;

      // Check if contains number interpolation (likely price)
      for (final element in node.elements) {
        if (element is InterpolationExpression) {
          final expr = element.expression;
          // Check for toStringAsFixed which is common for prices
          if (expr is MethodInvocation &&
              expr.methodName.name == 'toStringAsFixed') {
            reporter.atNode(node, code);
            return;
          }
          // Check for simple variable that might be a price
          if (expr is SimpleIdentifier) {
            final name = expr.name.toLowerCase();
            if (name.contains('price') ||
                name.contains('amount') ||
                name.contains('cost') ||
                name.contains('total') ||
                name.contains('money')) {
              reporter.atNode(node, code);
              return;
            }
          }
        }
      }
    });

    // Check for string concatenation with currency symbols
    context.registry.addBinaryExpression((BinaryExpression node) {
      if (node.operator.lexeme != '+') return;

      final left = node.leftOperand;
      final right = node.rightOperand;

      // Check if either side is a currency symbol string
      bool hasCurrencyString = false;
      if (left is SimpleStringLiteral) {
        for (final symbol in _currencySymbols) {
          if (left.value.contains(symbol)) {
            hasCurrencyString = true;
            break;
          }
        }
      }
      if (right is SimpleStringLiteral) {
        for (final symbol in _currencySymbols) {
          if (right.value.contains(symbol)) {
            hasCurrencyString = true;
            break;
          }
        }
      }

      if (hasCurrencyString) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when manual count-based string selection is used instead of Intl.plural.
///
/// Alias: use_intl_plural, manual_plural
///
/// Different languages have different plural rules. Using Intl.plural ensures
/// correct pluralization across all supported languages.
///
/// **BAD:**
/// ```dart
/// String getMessage(int count) {
///   if (count == 0) return 'No items';
///   if (count == 1) return '1 item';
///   return '$count items';
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// String getMessage(int count) {
///   return Intl.plural(
///     count,
///     zero: 'No items',
///     one: 'One item',
///     other: '$count items',
///   );
/// }
/// ```
class RequireIntlPluralRulesRule extends SaropaLintRule {
  const RequireIntlPluralRulesRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_intl_plural_rules',
    problemMessage:
        '[require_intl_plural_rules] Manual pluralization logic using if/else or ternary expressions on count values. Languages such as Russian, Arabic, and Polish have complex plural categories (zero, one, two, few, many, other) that simple singular/plural branching cannot handle. This produces grammatically incorrect text for international users and breaks translation workflows.',
    correctionMessage:
        'Replace manual plural logic with Intl.plural() to handle pluralization correctly in every supported language.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  // Cached regex patterns for performance
  static final RegExp _returnStringPattern = RegExp(r'''return\s*['"]''');
  static final RegExp _pluralWordPattern = RegExp(
    r'''['"][^'"]*\b(items?|files?|messages?|users?|days?|hours?|minutes?|'''
    r'''seconds?|photos?|videos?|comments?|posts?|results?|records?|'''
    r'''entries?|elements?|objects?|things?)\b[^'"]*['"]''',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      // Method must return String
      final TypeAnnotation? returnType = node.returnType;
      if (returnType == null) return;
      if (returnType.toSource() != 'String') return;

      // Method must have an int parameter (the count)
      final FormalParameterList? paramList = node.parameters;
      if (paramList == null) return;

      String? countParamName;
      for (final FormalParameter param in paramList.parameters) {
        String? typeName;
        String? paramName;

        if (param is SimpleFormalParameter) {
          typeName = param.type?.toSource();
          paramName = param.name?.lexeme;
        } else if (param is DefaultFormalParameter) {
          final NormalFormalParameter normalParam = param.parameter;
          if (normalParam is SimpleFormalParameter) {
            typeName = normalParam.type?.toSource();
            paramName = normalParam.name?.lexeme;
          }
        }

        if (typeName == 'int' && paramName != null) {
          countParamName = paramName;
          break;
        }
      }

      if (countParamName == null) return;

      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Already using Intl.plural - good!
      if (bodySource.contains('Intl.plural')) return;

      // Check that the int parameter is compared to 1 (typical pluralization)
      // Only == 1 or != 1 patterns indicate pluralization logic.
      // Comparisons like <= 0 or > 2 are validation checks, not pluralization.
      final RegExp countComparisonPattern = RegExp(
        '${RegExp.escape(countParamName)}\\s*[=!]=\\s*1|'
        '1\\s*[=!]=\\s*${RegExp.escape(countParamName)}',
      );

      if (!countComparisonPattern.hasMatch(bodySource)) return;

      // Must have multiple return statements with strings (different plurals)
      final int returnCount =
          _returnStringPattern.allMatches(bodySource).length;

      // Need at least 2 different string returns (singular/plural)
      if (returnCount < 2) return;

      // Look for explicit plural patterns in strings:
      // - Words ending in 's' that likely represent plurals
      // - Explicit singular/plural word pairs
      if (_pluralWordPattern.hasMatch(bodySource)) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// NEW RULES v2.3.11
// =============================================================================

/// Warns when Intl.message args don't match placeholders in the message.
///
/// Alias: intl_args_placeholders, intl_message_args
///
/// Intl.message placeholders must have matching args. Mismatched args cause
/// runtime errors or missing translations.
///
/// **BAD:**
/// ```dart
/// Intl.message(
///   'Hello $name, you have $count items',
///   args: [name], // Missing count!
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// Intl.message(
///   'Hello $name, you have $count items',
///   args: [name, count],
/// );
/// ```
class RequireIntlArgsMatchRule extends SaropaLintRule {
  const RequireIntlArgsMatchRule() : super(code: _code);

  /// Mismatched args cause runtime errors in translations.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_intl_args_match',
    problemMessage:
        '[require_intl_args_match] The placeholders in your Intl.message string do not match the arguments provided in the args list. Missing, extra, or mismatched arguments cause runtime errors, broken translations, and can result in untranslated or incorrect messages in production. This is a common source of i18n bugs and can break localization workflows.',
    correctionMessage:
        'Update your Intl.message so every placeholder in the string has a matching argument in the args list, and vice versa. Example: args: [name, count] for "Hello {name}, you have {count} messages". Audit your codebase for mismatches and add tests to catch i18n errors before release.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'message') return;

      // Check if it's Intl.message
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Intl') return;

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      // Get the message string
      final Expression messageArg = args.arguments.first;
      String? messageText;

      if (messageArg is SimpleStringLiteral) {
        messageText = messageArg.value;
      } else if (messageArg is StringInterpolation) {
        // For interpolated strings, get the full source
        messageText = messageArg.toSource();
      }

      if (messageText == null) return;

      // Count placeholders in message ($ followed by word characters)
      final RegExp placeholderPattern = RegExp(r'\$(\w+)');
      final Iterable<RegExpMatch> placeholders =
          placeholderPattern.allMatches(messageText);
      final int placeholderCount = placeholders.length;

      if (placeholderCount == 0) return;

      // Find args parameter
      int argsCount = 0;
      for (final Expression arg in args.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'args') {
          final Expression argsValue = arg.expression;
          if (argsValue is ListLiteral) {
            argsCount = argsValue.elements.length;
          }
          break;
        }
      }

      // Warn if counts don't match
      if (argsCount != placeholderCount) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when string concatenation is used for localized text.
///
/// Alias: no_concat_l10n, string_plus_l10n, l10n_concatenation
///
/// HEURISTIC: String concatenation breaks word order in RTL languages
/// and languages with different grammatical structures.
///
/// **BAD:**
/// ```dart
/// Text('Hello, ' + userName + '!'); // Word order varies by language
/// ```
///
/// **GOOD:**
/// ```dart
/// Text(l10n.greeting(userName)); // Translation handles word order
/// ```
class AvoidStringConcatenationForL10nRule extends SaropaLintRule {
  const AvoidStringConcatenationForL10nRule() : super(code: _code);

  /// Concatenation breaks translations in RTL and complex languages.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_string_concatenation_for_l10n',
    problemMessage:
        '[avoid_string_concatenation_for_l10n] String concatenation may break word order in other languages. HEURISTIC: String concatenation breaks word order in RTL languages and languages with different grammatical structures.',
    correctionMessage:
        'Use parameterized translations: l10n.greeting(name) instead of concatenation. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      // Check for string + variable pattern
      if (node.operator.lexeme != '+') return;

      // Check if either side is a string literal
      final bool hasStringLiteral = node.leftOperand is SimpleStringLiteral ||
          node.rightOperand is SimpleStringLiteral;

      if (!hasStringLiteral) return;

      // Check if inside a Text widget or similar UI context
      AstNode? current = node.parent;
      while (current != null) {
        if (current is InstanceCreationExpression) {
          final String typeName = current.constructorName.type.name2.lexeme;
          if (typeName == 'Text' ||
              typeName == 'RichText' ||
              typeName == 'SelectableText') {
            reporter.atNode(node, code);
            return;
          }
        }
        current = current.parent;
      }
    });
  }
}

// =============================================================================
// NEW ROADMAP STAR RULES - Internationalization Rules
// =============================================================================

/// Warns when numbers are displayed without proper formatting.
///
/// Use NumberFormat for locale-aware number display. Raw numbers
/// don't respect locale-specific decimal separators and grouping.
///
/// **BAD:**
/// ```dart
/// Text('${price.toStringAsFixed(2)}'); // 1234.56 in all locales
/// Text('$count items'); // No thousand separators
/// ```
///
/// **GOOD:**
/// ```dart
/// Text(NumberFormat.currency(locale: locale).format(price)); // $1,234.56
/// Text(NumberFormat.decimalPattern(locale).format(count)); // 1,234
/// ```
class PreferNumberFormatRule extends SaropaLintRule {
  const PreferNumberFormatRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_number_format',
    problemMessage:
        '[prefer_number_format] Number displayed without locale formatting. '
        'Different locales use different decimal/grouping separators.',
    correctionMessage:
        'Use NumberFormat.decimalPattern(locale).format(number) for i18n.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for toStringAsFixed, toString on numbers in UI context
      final String methodName = node.methodName.name;
      if (methodName != 'toStringAsFixed' && methodName != 'toString') return;

      // Check if target is a numeric type
      final targetType = node.target?.staticType;
      if (targetType == null) return;

      final typeName = targetType.getDisplayString();
      if (typeName != 'double' && typeName != 'int' && typeName != 'num') {
        return;
      }

      // Check if inside a Text widget
      if (_isInsideTextWidget(node)) {
        reporter.atNode(node, code);
      }
    });

    // Also check for string interpolation of numbers
    context.registry.addInterpolationExpression((InterpolationExpression node) {
      final Expression expr = node.expression;
      final exprType = expr.staticType;
      if (exprType == null) return;

      final typeName = exprType.getDisplayString();
      if (typeName == 'double' || typeName == 'int' || typeName == 'num') {
        if (_isInsideTextWidget(node)) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  bool _isInsideTextWidget(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is InstanceCreationExpression) {
        final String typeName = current.constructorName.type.name2.lexeme;
        if (typeName == 'Text' ||
            typeName == 'RichText' ||
            typeName == 'SelectableText') {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when Intl.message arguments don't match placeholders.
///
/// Intl.message placeholders like {name} must have matching args.
/// Mismatched arguments cause runtime errors.
///
/// **BAD:**
/// ```dart
/// Intl.message(
///   'Hello {name}, you have {count} messages',
///   args: [name], // Missing 'count' argument!
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Intl.message(
///   'Hello {name}, you have {count} messages',
///   args: [name, count],
/// )
/// ```
class ProvideCorrectIntlArgsRule extends SaropaLintRule {
  const ProvideCorrectIntlArgsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'provide_correct_intl_args',
    problemMessage:
        '[provide_correct_intl_args] Intl.message args count does not match '
        'placeholders. This will cause runtime errors.',
    correctionMessage:
        'Ensure args list matches all {placeholder} names in the message.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for Intl.message or Intl.plural
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Intl') return;

      final String methodName = node.methodName.name;
      if (methodName != 'message' && methodName != 'plural') return;

      // Get the message string
      final args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final firstArg = args.first;
      String? messageText;
      if (firstArg is SimpleStringLiteral) {
        messageText = firstArg.value;
      } else if (firstArg is AdjacentStrings) {
        messageText = firstArg.strings
            .whereType<SimpleStringLiteral>()
            .map((s) => s.value)
            .join();
      }

      if (messageText == null) return;

      // Count placeholders in message
      final placeholderPattern = RegExp(r'\{(\w+)\}');
      final placeholders = placeholderPattern
          .allMatches(messageText)
          .map((m) => m.group(1)!)
          .toSet();

      // Find args parameter
      for (final arg in args) {
        if (arg is NamedExpression && arg.name.label.name == 'args') {
          final argsExpr = arg.expression;
          if (argsExpr is ListLiteral) {
            final argsCount = argsExpr.elements.length;
            if (argsCount != placeholders.length) {
              reporter.atNode(arg, code);
            }
          }
          break;
        }
      }
    });
  }
}

// =============================================================================
// avoid_string_concatenation_l10n
// =============================================================================

/// String concatenation breaks word order in translations.
///
/// Different languages have different word orders. Concatenating strings
/// makes proper translation impossible.
///
/// **BAD:**
/// ```dart
/// Text('Hello ' + userName + '!');  // Word order is fixed
/// Text('$greeting $name');  // Same problem with interpolation
/// ```
///
/// **GOOD:**
/// ```dart
/// Text(AppLocalizations.of(context).greeting(name));  // Proper l10n
/// Text(Intl.message('Hello {name}!', args: [name]));
/// ```
class AvoidStringConcatenationL10nRule extends SaropaLintRule {
  const AvoidStringConcatenationL10nRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_string_concatenation_l10n',
    problemMessage:
        '[avoid_string_concatenation_l10n] String concatenation in UI breaks '
        'word order for translations.',
    correctionMessage:
        'Use Intl.message with placeholders or a localization solution that '
        'supports proper word order.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name2.lexeme;
      if (typeName != 'Text') return;

      final args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final firstArg = args.first;

      // Check for binary expression (string concatenation)
      if (firstArg is BinaryExpression) {
        if (firstArg.operator.lexeme == '+') {
          reporter.atNode(firstArg, code);
        }
      }

      // Check for string interpolation with variables
      if (firstArg is StringInterpolation) {
        // Count interpolation elements
        int interpolationCount = 0;
        for (final element in firstArg.elements) {
          if (element is InterpolationExpression) {
            interpolationCount++;
          }
        }
        // If there are multiple interpolations, likely needs l10n
        if (interpolationCount >= 2) {
          reporter.atNode(firstArg, code);
        }
      }
    });
  }
}

// =============================================================================
// prefer_intl_message_description
// =============================================================================

/// Intl.message should include description for translators.
///
/// Translators need context to translate correctly. The desc parameter
/// explains when and how the string is used.
///
/// **BAD:**
/// ```dart
/// Intl.message('Submit');  // No context for translator
/// ```
///
/// **GOOD:**
/// ```dart
/// Intl.message(
///   'Submit',
///   desc: 'Button text to submit the registration form',
/// );
/// ```
class PreferIntlMessageDescriptionRule extends SaropaLintRule {
  const PreferIntlMessageDescriptionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_intl_message_description',
    problemMessage:
        '[prefer_intl_message_description] Intl.message missing description (desc). Translators lack context, leading to poor or incorrect translations.',
    correctionMessage:
        'Add a desc parameter to Intl.message explaining when and where this text is shown. Example: desc: "Shown on login screen after failed attempt."',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for Intl.message
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Intl') return;

      if (node.methodName.name != 'message') return;

      // Check for desc parameter
      bool hasDesc = false;
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'desc') {
          hasDesc = true;
          break;
        }
      }

      if (!hasDesc) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// avoid_hardcoded_locale_strings
// =============================================================================

/// User-visible strings should use localization.
///
/// Hardcoded strings in Text widgets can't be translated.
///
/// **BAD:**
/// ```dart
/// Text('Welcome back!');  // Hardcoded English
/// ```
///
/// **GOOD:**
/// ```dart
/// Text(AppLocalizations.of(context).welcomeBack);
/// ```
class AvoidHardcodedLocaleStringsRule extends SaropaLintRule {
  const AvoidHardcodedLocaleStringsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_locale_strings',
    problemMessage:
        '[avoid_hardcoded_locale_strings] `[HEURISTIC]` Hardcoded string in '
        'Text widget. Use localization for user-visible text.',
    correctionMessage:
        'Replace with AppLocalizations.of(context).yourString or Intl.message.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Strings that are likely not user-visible or don't need translation
  static const Set<String> _ignoredPatterns = <String>{
    'http',
    'https',
    'mailto:',
    'tel:',
    '.com',
    '.org',
    '.net',
    '@',
    '©',
    '®',
    '™',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name2.lexeme;
      if (typeName != 'Text') return;

      final args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final firstArg = args.first;

      // Check for string literal
      String? stringValue;
      if (firstArg is SimpleStringLiteral) {
        stringValue = firstArg.value;
      } else if (firstArg is AdjacentStrings) {
        stringValue = firstArg.strings
            .whereType<SimpleStringLiteral>()
            .map((s) => s.value)
            .join();
      }

      if (stringValue == null) return;

      // Ignore empty strings and single characters
      if (stringValue.length <= 1) return;

      // Ignore strings that look like URLs, emails, etc.
      for (final pattern in _ignoredPatterns) {
        if (stringValue.toLowerCase().contains(pattern)) return;
      }

      // Ignore strings that are just numbers or punctuation
      if (RegExp(r'^[\d\s\.,!?]+$').hasMatch(stringValue)) return;

      // Ignore strings that look like identifiers
      if (RegExp(r'^[a-z_][a-z0-9_]*$').hasMatch(stringValue)) return;

      reporter.atNode(firstArg, code);
    });
  }
}
