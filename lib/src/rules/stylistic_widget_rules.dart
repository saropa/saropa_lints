// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

// ============================================================================
// STYLISTIC WIDGET & UI RULES - Batch 1
// ============================================================================
//
// These rules are NOT included in any tier by default. They represent team
// preferences for widget construction patterns where there is no objectively
// "correct" answer.
// ============================================================================

/// Warns when Container is used for simple width/height spacing.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of SizedBox:**
/// - More lightweight - SizedBox is const by default
/// - Clearer intent - explicit that it's just for sizing
/// - Better performance - less widget overhead
///
/// **Cons (why some teams prefer Container):**
/// - Container is more versatile for future changes
/// - Familiar from other frameworks
/// - Single widget for all box needs
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// Container(width: 16, height: 16)
/// Container(width: 100)
/// ```
///
/// #### GOOD:
/// ```dart
/// SizedBox(width: 16, height: 16)
/// SizedBox(width: 100)
/// ```
class PreferSizedBoxOverContainerRule extends SaropaLintRule {
  const PreferSizedBoxOverContainerRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_sizedbox_over_container',
    problemMessage:
        'Use SizedBox instead of Container for simple width/height spacing.',
    correctionMessage:
        'SizedBox is more lightweight and clearer for sizing-only needs.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final String? constructorName =
          node.constructorName.type.element?.name;
      if (constructorName != 'Container') return;

      // Check if Container only has width, height, and/or child
      final args = node.argumentList.arguments;
      final argNames = <String>{};

      for (final arg in args) {
        if (arg is NamedExpression) {
          argNames.add(arg.name.label.name);
        }
      }

      // Only flag if ONLY using width/height/child (no decoration, color, etc.)
      final allowedArgs = {'width', 'height', 'child', 'key'};
      if (argNames.isNotEmpty && argNames.every(allowedArgs.contains)) {
        // Must have at least width or height to be a sizing container
        if (argNames.contains('width') || argNames.contains('height')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when SizedBox is used instead of Container (opposite rule).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of Container:**
/// - More versatile for future changes (add decoration, color easily)
/// - Consistent API across the codebase
/// - Single widget type for all box needs
///
/// **Cons (why some teams prefer SizedBox):**
/// - SizedBox is more lightweight
/// - Clearer intent for sizing-only
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// SizedBox(width: 16, height: 16)
/// ```
///
/// #### GOOD:
/// ```dart
/// Container(width: 16, height: 16)
/// ```
class PreferContainerOverSizedBoxRule extends SaropaLintRule {
  const PreferContainerOverSizedBoxRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_container_over_sizedbox',
    problemMessage: 'Use Container instead of SizedBox for consistency.',
    correctionMessage:
        'Container provides a consistent API and is easier to extend.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final String? constructorName =
          node.constructorName.type.element?.name;
      if (constructorName != 'SizedBox') return;

      // Skip SizedBox.shrink() and SizedBox.expand()
      final namedConstructor = node.constructorName.name?.name;
      if (namedConstructor == 'shrink' || namedConstructor == 'expand') return;

      reporter.atNode(node, code);
    });
  }
}

/// Warns when RichText is used instead of Text.rich().
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of Text.rich():**
/// - Inherits DefaultTextStyle automatically
/// - Simpler API for common cases
/// - Consistent with other Text constructors
///
/// **Cons (why some teams prefer RichText):**
/// - RichText offers more control
/// - Explicit about not inheriting styles
/// - Familiar from other frameworks
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// RichText(
///   text: TextSpan(text: 'Hello', children: [...]),
/// )
/// ```
///
/// #### GOOD:
/// ```dart
/// Text.rich(
///   TextSpan(text: 'Hello', children: [...]),
/// )
/// ```
class PreferTextRichOverRichTextRule extends SaropaLintRule {
  const PreferTextRichOverRichTextRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_text_rich_over_richtext',
    problemMessage: 'Use Text.rich() instead of RichText widget.',
    correctionMessage:
        'Text.rich() inherits DefaultTextStyle and has a simpler API.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final String? constructorName =
          node.constructorName.type.element?.name;
      if (constructorName == 'RichText') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Text.rich() is used instead of RichText (opposite rule).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of RichText:**
/// - Explicit control over text styling
/// - No implicit style inheritance
/// - More predictable behavior
///
/// **Cons (why some teams prefer Text.rich()):**
/// - Text.rich() inherits DefaultTextStyle
/// - Simpler API
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// Text.rich(TextSpan(text: 'Hello'))
/// ```
///
/// #### GOOD:
/// ```dart
/// RichText(text: TextSpan(text: 'Hello'))
/// ```
class PreferRichTextOverTextRichRule extends SaropaLintRule {
  const PreferRichTextOverTextRichRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_richtext_over_text_rich',
    problemMessage: 'Use RichText instead of Text.rich() for explicit control.',
    correctionMessage:
        'RichText provides explicit control without implicit style inheritance.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final String? constructorName =
          node.constructorName.type.element?.name;
      final String? namedConstructor = node.constructorName.name?.name;

      if (constructorName == 'Text' && namedConstructor == 'rich') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when EdgeInsets.only() could be simplified to EdgeInsets.symmetric().
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of EdgeInsets.symmetric():**
/// - More concise for symmetric padding
/// - Clearer intent when values mirror
/// - Less repetition
///
/// **Cons (why some teams prefer .only()):**
/// - More explicit about each side
/// - Easier to modify individual values later
/// - Consistent API regardless of symmetry
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8)
/// ```
///
/// #### GOOD:
/// ```dart
/// EdgeInsets.symmetric(horizontal: 16, vertical: 8)
/// ```
class PreferEdgeInsetsSymmetricRule extends SaropaLintRule {
  const PreferEdgeInsetsSymmetricRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  //  cspell:ignore edgeinsets
  static const LintCode _code = LintCode(
    name: 'prefer_edgeinsets_symmetric',
    problemMessage:
        'Use EdgeInsets.symmetric() when left/right or top/bottom are equal.',
    correctionMessage:
        'EdgeInsets.symmetric() is more concise for symmetric padding.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final String? constructorName =
          node.constructorName.type.element?.name;
      final String? namedConstructor = node.constructorName.name?.name;

      if (constructorName != 'EdgeInsets') return;
      if (namedConstructor != 'only') return;

      // Extract values
      final args = <String, String>{};
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          args[arg.name.label.name] = arg.expression.toString();
        }
      }

      // Check if symmetric conversion is possible
      final left = args['left'];
      final right = args['right'];
      final top = args['top'];
      final bottom = args['bottom'];

      final horizontalSymmetric = left != null && right != null && left == right;
      final verticalSymmetric = top != null && bottom != null && top == bottom;

      if (horizontalSymmetric || verticalSymmetric) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when EdgeInsets.symmetric() is used instead of .only() (opposite rule).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of EdgeInsets.only():**
/// - More explicit about each side
/// - Easier to modify individual values later
/// - Consistent API across all EdgeInsets usage
///
/// **Cons (why some teams prefer .symmetric()):**
/// - More verbose for symmetric padding
/// - Repetition of values
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// EdgeInsets.symmetric(horizontal: 16, vertical: 8)
/// ```
///
/// #### GOOD:
/// ```dart
/// EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8)
/// ```
class PreferEdgeInsetsOnlyRule extends SaropaLintRule {
  const PreferEdgeInsetsOnlyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_edgeinsets_only',
    problemMessage: 'Use EdgeInsets.only() for explicit side values.',
    correctionMessage:
        'EdgeInsets.only() is more explicit and easier to modify.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final String? constructorName =
          node.constructorName.type.element?.name;
      final String? namedConstructor = node.constructorName.name?.name;

      if (constructorName == 'EdgeInsets' && namedConstructor == 'symmetric') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when BorderRadius.all(Radius.circular()) is used instead of
/// BorderRadius.circular().
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of BorderRadius.circular():**
/// - More concise syntax
/// - Clearer intent for uniform corners
/// - Less nesting
///
/// **Cons:**
/// - BorderRadius.all() is more explicit
/// - Consistent with other BorderRadius constructors
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// BorderRadius.all(Radius.circular(8))
/// ```
///
/// #### GOOD:
/// ```dart
/// BorderRadius.circular(8)
/// ```
class PreferBorderRadiusCircularRule extends SaropaLintRule {
  const PreferBorderRadiusCircularRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  // cspell:ignore borderradius
  static const LintCode _code = LintCode(
    name: 'prefer_borderradius_circular',
    problemMessage:
        'Use BorderRadius.circular() instead of BorderRadius.all(Radius.circular()).',
    correctionMessage: 'BorderRadius.circular() is more concise.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final String? constructorName =
          node.constructorName.type.element?.name;
      final String? namedConstructor = node.constructorName.name?.name;

      if (constructorName != 'BorderRadius' || namedConstructor != 'all') return;

      // Check if the argument is Radius.circular()
      final args = node.argumentList.arguments;
      if (args.length != 1) return;

      final arg = args.first;
      if (arg is InstanceCreationExpression) {
        final argName = arg.constructorName.type.element?.name;
        final argConstructor = arg.constructorName.name?.name;
        if (argName == 'Radius' && argConstructor == 'circular') {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when Flexible(fit: FlexFit.tight) is used instead of Expanded.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of Expanded:**
/// - More concise for the common case
/// - Clearer intent - "expand to fill"
/// - Idiomatic Flutter
///
/// **Cons (why some teams prefer Flexible):**
/// - Flexible is more general
/// - Consistent API regardless of fit
/// - Can easily switch between tight/loose
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// Flexible(fit: FlexFit.tight, child: widget)
/// ```
///
/// #### GOOD:
/// ```dart
/// Expanded(child: widget)
/// ```
class PreferExpandedOverFlexibleRule extends SaropaLintRule {
  const PreferExpandedOverFlexibleRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_expanded_over_flexible',
    problemMessage:
        'Use Expanded instead of Flexible(fit: FlexFit.tight).',
    correctionMessage: 'Expanded is more concise and idiomatic.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final String? constructorName =
          node.constructorName.type.element?.name;
      if (constructorName != 'Flexible') return;

      // Check for fit: FlexFit.tight
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'fit') {
          final expr = arg.expression;
          if (expr is PrefixedIdentifier) {
            if (expr.prefix.name == 'FlexFit' &&
                expr.identifier.name == 'tight') {
              reporter.atNode(node, code);
              return;
            }
          }
        }
      }
    });
  }
}

/// Warns when Expanded is used instead of Flexible (opposite rule).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of Flexible:**
/// - More general and explicit
/// - Consistent API for all flex scenarios
/// - Easy to switch between tight/loose
///
/// **Cons (why some teams prefer Expanded):**
/// - Expanded is more concise
/// - Clearer intent for "fill available space"
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// Expanded(child: widget)
/// ```
///
/// #### GOOD:
/// ```dart
/// Flexible(fit: FlexFit.tight, child: widget)
/// ```
class PreferFlexibleOverExpandedRule extends SaropaLintRule {
  const PreferFlexibleOverExpandedRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_flexible_over_expanded',
    problemMessage: 'Use Flexible instead of Expanded for consistency.',
    correctionMessage:
        'Flexible provides a consistent API and explicit fit parameter.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final String? constructorName =
          node.constructorName.type.element?.name;
      if (constructorName == 'Expanded') {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when hardcoded colors are used instead of Theme.of(context).colorScheme.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of theme colors:**
/// - Automatic dark/light mode support
/// - Consistent theming across the app
/// - Easier to change colors globally
///
/// **Cons (why some teams prefer explicit colors):**
/// - More predictable - no context dependency
/// - Simpler for one-off colors
/// - Faster (no Theme lookup)
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// Container(color: Colors.blue)
/// Text('Hi', style: TextStyle(color: Colors.red))
/// ```
///
/// #### GOOD:
/// ```dart
/// Container(color: Theme.of(context).colorScheme.primary)
/// Text('Hi', style: TextStyle(color: Theme.of(context).colorScheme.error))
/// ```
class PreferMaterialThemeColorsRule extends SaropaLintRule {
  const PreferMaterialThemeColorsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_material_theme_colors',
    problemMessage:
        'Use Theme.of(context).colorScheme instead of hardcoded Colors.',
    correctionMessage:
        'Theme colors support dark mode and maintain consistency.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPrefixedIdentifier((node) {
      if (node.prefix.name == 'Colors') {
        // Check if this is a color assignment in a widget context
        // We look for common color parameter names
        final parent = node.parent;
        if (parent is NamedExpression) {
          final paramName = parent.name.label.name;
          if (_isColorParam(paramName)) {
            reporter.atNode(node, code);
          }
        } else if (parent is ArgumentList) {
          // Positional color argument (less common but possible)
          reporter.atNode(node, code);
        }
      }
    });
  }

  bool _isColorParam(String name) {
    return name == 'color' ||
        name == 'backgroundColor' ||
        name == 'foregroundColor' ||
        name == 'fillColor' ||
        name == 'splashColor' ||
        name == 'hoverColor' ||
        name == 'focusColor' ||
        name == 'highlightColor' ||
        name == 'shadowColor' ||
        name == 'surfaceTintColor';
  }
}

/// Warns when Theme.of(context).colorScheme is used instead of explicit Colors
/// (opposite rule).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of explicit colors:**
/// - More predictable - no context dependency
/// - No Theme lookup overhead
/// - Clearer about exact color being used
///
/// **Cons (why some teams prefer theme colors):**
/// - No automatic dark/light mode
/// - Harder to maintain consistency
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// Container(color: Theme.of(context).colorScheme.primary)
/// ```
///
/// #### GOOD:
/// ```dart
/// Container(color: Colors.blue)
/// ```
class PreferExplicitColorsRule extends SaropaLintRule {
  const PreferExplicitColorsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_explicit_colors',
    problemMessage: 'Use explicit Colors instead of Theme.of(context).colorScheme.',
    correctionMessage:
        'Explicit colors are more predictable and have no context dependency.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      // Look for Theme.of(context)
      if (node.methodName.name != 'of') return;
      final target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'Theme') return;

      // Check if it's followed by .colorScheme
      final parent = node.parent;
      if (parent is PropertyAccess && parent.propertyName.name == 'colorScheme') {
        reporter.atNode(parent, code);
      }
    });
  }
}
