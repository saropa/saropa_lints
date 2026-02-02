// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
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
        '[prefer_sizedbox_over_container] Use SizedBox instead of Container for simple width/height spacing.',
    correctionMessage:
        'Replace Container with SizedBox when you only need width and height \u2014 SizedBox skips the decoration/padding layers.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final String? constructorName = node.constructorName.type.element?.name;
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

  @override
  List<Fix> get customFixes => <Fix>[_PreferSizedBoxOverContainerFix()];
}

class _PreferSizedBoxOverContainerFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.constructorName.type.element?.name != 'Container') return;

      final constPrefix = node.keyword?.lexeme == 'const' ? 'const ' : '';
      final args = _extractNamedArgs(node);
      final newArgs = <String>[];
      if (args.containsKey('key')) newArgs.add('key: ${args['key']}');
      if (args.containsKey('width')) newArgs.add('width: ${args['width']}');
      if (args.containsKey('height')) newArgs.add('height: ${args['height']}');
      if (args.containsKey('child')) newArgs.add('child: ${args['child']}');

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with SizedBox',
        priority: 80,
      );
      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          '${constPrefix}SizedBox(${newArgs.join(', ')})',
        );
      });
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
    problemMessage:
        '[prefer_container_over_sizedbox] Use Container instead of SizedBox for consistency.',
    correctionMessage:
        'Replace SizedBox with Container so decoration, padding, or alignment can be added later without a widget swap.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'SizedBox') return;

      // Skip SizedBox.shrink() and SizedBox.expand()
      final namedConstructor = node.constructorName.name?.name;
      if (namedConstructor == 'shrink' || namedConstructor == 'expand') return;

      reporter.atNode(node, code);
    });
  }

  @override
  List<Fix> get customFixes => <Fix>[_PreferContainerOverSizedBoxFix()];
}

class _PreferContainerOverSizedBoxFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.constructorName.type.element?.name != 'SizedBox') return;
      if (node.constructorName.name?.name != null) return;

      final constPrefix = node.keyword?.lexeme == 'const' ? 'const ' : '';
      final args = _extractNamedArgs(node);
      final newArgs = <String>[];
      if (args.containsKey('key')) newArgs.add('key: ${args['key']}');
      if (args.containsKey('width')) newArgs.add('width: ${args['width']}');
      if (args.containsKey('height')) newArgs.add('height: ${args['height']}');
      if (args.containsKey('child')) newArgs.add('child: ${args['child']}');

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with Container',
        priority: 80,
      );
      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          '${constPrefix}Container(${newArgs.join(', ')})',
        );
      });
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
    problemMessage:
        '[prefer_text_rich_over_richtext] Use Text.rich() instead of RichText widget.',
    correctionMessage:
        'Replace RichText with Text.rich() to inherit the DefaultTextStyle and avoid manually setting the base style.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final String? constructorName = node.constructorName.type.element?.name;
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
    problemMessage:
        '[prefer_richtext_over_text_rich] Use RichText instead of Text.rich() for explicit control.',
    correctionMessage:
        'Replace Text.rich() with RichText for full control over the base text style without implicit DefaultTextStyle inheritance.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final String? constructorName = node.constructorName.type.element?.name;
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
        '[prefer_edgeinsets_symmetric] Use EdgeInsets.symmetric() when left/right or top/bottom are equal.',
    correctionMessage:
        'Replace EdgeInsets.only() with EdgeInsets.symmetric() when horizontal or vertical values are equal, for brevity.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final String? constructorName = node.constructorName.type.element?.name;
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

      final horizontalSymmetric =
          left != null && right != null && left == right;
      final verticalSymmetric = top != null && bottom != null && top == bottom;

      if (horizontalSymmetric || verticalSymmetric) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> get customFixes => <Fix>[_PreferEdgeInsetsSymmetricFix()];
}

class _PreferEdgeInsetsSymmetricFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.constructorName.type.element?.name != 'EdgeInsets') return;
      if (node.constructorName.name?.name != 'only') return;

      final args = _extractNamedArgs(node);
      final left = args['left'];
      final right = args['right'];
      final top = args['top'];
      final bottom = args['bottom'];

      // Only offer fix when all present pairs are symmetric
      final hasH = left != null && right != null;
      final hasV = top != null && bottom != null;
      if (hasH && left != right) return;
      if (hasV && top != bottom) return;
      // Reject unpaired sides (e.g., left without right)
      if ((left == null) != (right == null)) return;
      if ((top == null) != (bottom == null)) return;

      final constPrefix = node.keyword?.lexeme == 'const' ? 'const ' : '';
      final newArgs = <String>[];
      if (hasH) newArgs.add('horizontal: $left');
      if (hasV) newArgs.add('vertical: $top');

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with EdgeInsets.symmetric()',
        priority: 80,
      );
      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          '${constPrefix}EdgeInsets.symmetric(${newArgs.join(', ')})',
        );
      });
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
    problemMessage:
        '[prefer_edgeinsets_only] Use EdgeInsets.only() for explicit side values.',
    correctionMessage:
        'Replace EdgeInsets.symmetric() with EdgeInsets.only() for explicit per-side values that are easier to adjust independently.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final String? constructorName = node.constructorName.type.element?.name;
      final String? namedConstructor = node.constructorName.name?.name;

      if (constructorName == 'EdgeInsets' && namedConstructor == 'symmetric') {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> get customFixes => <Fix>[_PreferEdgeInsetsOnlyFix()];
}

class _PreferEdgeInsetsOnlyFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.constructorName.type.element?.name != 'EdgeInsets') return;
      if (node.constructorName.name?.name != 'symmetric') return;

      final args = _extractNamedArgs(node);
      final horizontal = args['horizontal'];
      final vertical = args['vertical'];

      final constPrefix = node.keyword?.lexeme == 'const' ? 'const ' : '';
      final newArgs = <String>[];
      if (horizontal != null) {
        newArgs.add('left: $horizontal');
        newArgs.add('right: $horizontal');
      }
      if (vertical != null) {
        newArgs.add('top: $vertical');
        newArgs.add('bottom: $vertical');
      }

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with EdgeInsets.only()',
        priority: 80,
      );
      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          '${constPrefix}EdgeInsets.only(${newArgs.join(', ')})',
        );
      });
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
        '[prefer_borderradius_circular] Use BorderRadius.circular() instead of BorderRadius.all(Radius.circular()).',
    correctionMessage:
        'Replace BorderRadius.all(Radius.circular(r)) with BorderRadius.circular(r) for a shorter single-call equivalent.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final String? constructorName = node.constructorName.type.element?.name;
      final String? namedConstructor = node.constructorName.name?.name;

      if (constructorName != 'BorderRadius' || namedConstructor != 'all') {
        return;
      }

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

  @override
  List<Fix> get customFixes => <Fix>[_PreferBorderRadiusCircularFix()];
}

class _PreferBorderRadiusCircularFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.constructorName.type.element?.name != 'BorderRadius') return;
      if (node.constructorName.name?.name != 'all') return;

      final args = node.argumentList.arguments;
      if (args.length != 1) return;
      final arg = args.first;
      if (arg is! InstanceCreationExpression) return;
      if (arg.constructorName.type.element?.name != 'Radius') return;
      if (arg.constructorName.name?.name != 'circular') return;

      // Extract the radius value from Radius.circular(X)
      final innerArgs = arg.argumentList.arguments;
      if (innerArgs.length != 1) return;
      final radiusValue = innerArgs.first.toSource();

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with BorderRadius.circular()',
        priority: 80,
      );
      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          'BorderRadius.circular($radiusValue)',
        );
      });
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
        '[prefer_expanded_over_flexible] Use Expanded instead of Flexible(fit: FlexFit.tight).',
    correctionMessage:
        'Replace Flexible(fit: FlexFit.tight) with Expanded, which is the idiomatic shorthand for tight-fit flex children.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final String? constructorName = node.constructorName.type.element?.name;
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

  @override
  List<Fix> get customFixes => <Fix>[_PreferExpandedOverFlexibleFix()];
}

class _PreferExpandedOverFlexibleFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.constructorName.type.element?.name != 'Flexible') return;

      final constPrefix = node.keyword?.lexeme == 'const' ? 'const ' : '';
      final args = _extractNamedArgs(node);
      // Remove 'fit' and keep everything else
      final newArgs = <String>[];
      if (args.containsKey('key')) newArgs.add('key: ${args['key']}');
      if (args.containsKey('flex')) newArgs.add('flex: ${args['flex']}');
      if (args.containsKey('child')) newArgs.add('child: ${args['child']}');

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with Expanded',
        priority: 80,
      );
      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          '${constPrefix}Expanded(${newArgs.join(', ')})',
        );
      });
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
    problemMessage:
        '[prefer_flexible_over_expanded] Use Flexible instead of Expanded for consistency.',
    correctionMessage:
        'Replace Expanded with Flexible(fit: FlexFit.tight) so the fit parameter is always visible and easy to change later.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName == 'Expanded') {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> get customFixes => <Fix>[_PreferFlexibleOverExpandedFix()];
}

class _PreferFlexibleOverExpandedFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.constructorName.type.element?.name != 'Expanded') return;

      final constPrefix = node.keyword?.lexeme == 'const' ? 'const ' : '';
      final args = _extractNamedArgs(node);
      final newArgs = <String>[];
      if (args.containsKey('key')) newArgs.add('key: ${args['key']}');
      newArgs.add('fit: FlexFit.tight');
      if (args.containsKey('flex')) newArgs.add('flex: ${args['flex']}');
      if (args.containsKey('child')) newArgs.add('child: ${args['child']}');

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with Flexible',
        priority: 80,
      );
      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          '${constPrefix}Flexible(${newArgs.join(', ')})',
        );
      });
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
        '[prefer_material_theme_colors] Use Theme.of(context).colorScheme instead of hardcoded Colors.',
    correctionMessage:
        'Replace hardcoded Colors.* with Theme.of(context).colorScheme values to support dark mode and keep colors consistent.',
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
    problemMessage:
        '[prefer_explicit_colors] Use explicit Colors instead of Theme.of(context).colorScheme.',
    correctionMessage:
        'Replace Theme.of(context).colorScheme with explicit Colors.* values for predictable output without runtime context.',
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
      if (parent is PropertyAccess &&
          parent.propertyName.name == 'colorScheme') {
        reporter.atNode(parent, code);
      }
    });
  }
}

// =============================================================================
// CLIP R SUPERELLIPSE RULES - Batch 2
// =============================================================================

/// Suggests using ClipRSuperellipse instead of ClipRRect for rounded corners.
///
/// This is an **opinionated rule** — not included in any tier by default.
///
/// ClipRSuperellipse provides smoother, more aesthetically pleasing rounded
/// corners that match iOS design language (the "squircle" shape). The
/// superellipse curve creates a more natural transition between straight
/// edges and rounded corners than circular arcs.
///
/// This rule only fires when no custom `clipper` is used, so the quick fix
/// is a safe drop-in replacement. For custom clippers, see
/// [PreferClipRSuperellipseClipperRule].
///
/// **Requires Flutter 3.32+.** On platforms other than iOS and Android,
/// ClipRSuperellipse falls back to a standard rounded rectangle.
///
/// **Quick fix available:** Replaces `ClipRRect` with `ClipRSuperellipse`,
/// preserving all arguments (`key`, `borderRadius`, `clipBehavior`, `child`).
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// ClipRRect(
///   borderRadius: BorderRadius.circular(10),
///   child: Image.network('url'),
/// )
/// ```
///
/// #### GOOD:
/// ```dart
/// ClipRSuperellipse(
///   borderRadius: BorderRadius.circular(10),
///   child: Image.network('url'),
/// )
/// ```
class PreferClipRSuperellipseRule extends SaropaLintRule {
  const PreferClipRSuperellipseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_clip_r_superellipse',
    problemMessage:
        '[prefer_clip_r_superellipse] Use ClipRSuperellipse instead of ClipRRect for smoother rounded corners.',
    correctionMessage:
        'ClipRSuperellipse provides smoother corner transitions matching iOS design language. Requires Flutter 3.32+.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'ClipRRect') return;

      // Only flag when no custom clipper is used (safe drop-in replacement)
      final args = node.argumentList.arguments;
      for (final arg in args) {
        if (arg is NamedExpression && arg.name.label.name == 'clipper') {
          return;
        }
      }

      reporter.atNode(node, code);
    });
  }

  @override
  List<Fix> get customFixes => <Fix>[_PreferClipRSuperellipseFix()];
}

class _PreferClipRSuperellipseFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.constructorName.type.element?.name != 'ClipRRect') return;

      final constPrefix = node.keyword?.lexeme == 'const' ? 'const ' : '';
      final args = _extractNamedArgs(node);
      final newArgs = <String>[];
      if (args.containsKey('key')) newArgs.add('key: ${args['key']}');
      if (args.containsKey('borderRadius')) {
        newArgs.add('borderRadius: ${args['borderRadius']}');
      }
      if (args.containsKey('clipBehavior')) {
        newArgs.add('clipBehavior: ${args['clipBehavior']}');
      }
      if (args.containsKey('child')) {
        newArgs.add('child: ${args['child']}');
      }

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with ClipRSuperellipse',
        priority: 80,
      );
      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          '${constPrefix}ClipRSuperellipse(${newArgs.join(', ')})',
        );
      });
    });
  }
}

/// Suggests using ClipRSuperellipse instead of ClipRRect when a custom
/// clipper is used.
///
/// This is an **opinionated rule** — not included in any tier by default.
///
/// Unlike [PreferClipRSuperellipseRule], this rule fires when a custom
/// `clipper` parameter is present. Because the clipper type differs
/// (`CustomClipper<RRect>` vs `CustomClipper<RSuperellipse>`), automatic
/// replacement is not possible — the clipper must be manually rewritten.
///
/// No quick fix is provided.
///
/// **Requires Flutter 3.32+.**
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// ClipRRect(
///   clipper: MyCustomClipper(),
///   child: Image.network('url'),
/// )
/// ```
///
/// #### GOOD:
/// ```dart
/// ClipRSuperellipse(
///   clipper: MyCustomSuperellipseClipper(),
///   child: Image.network('url'),
/// )
/// ```
class PreferClipRSuperellipseClipperRule extends SaropaLintRule {
  const PreferClipRSuperellipseClipperRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_clip_r_superellipse_clipper',
    problemMessage:
        '[prefer_clip_r_superellipse_clipper] Use ClipRSuperellipse instead of ClipRRect for smoother continuous corners.',
    correctionMessage:
        'The custom clipper must be rewritten as CustomClipper<RSuperellipse>. Requires Flutter 3.32+.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'ClipRRect') return;

      // Only flag when a custom clipper IS used (no auto-fix possible)
      final hasClipper = node.argumentList.arguments.any(
        (arg) => arg is NamedExpression && arg.name.label.name == 'clipper',
      );
      if (!hasClipper) return;

      reporter.atNode(node, code);
    });
  }
}

// =============================================================================
// Shared helpers for quick fixes
// =============================================================================

/// Extracts named arguments from an [InstanceCreationExpression] as a map
/// of argument name to source text.
Map<String, String> _extractNamedArgs(InstanceCreationExpression node) {
  final args = <String, String>{};
  for (final arg in node.argumentList.arguments) {
    if (arg is NamedExpression) {
      args[arg.name.label.name] = arg.expression.toSource();
    }
  }
  return args;
}
