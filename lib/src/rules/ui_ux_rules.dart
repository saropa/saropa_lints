import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart';

/// Warns when MediaQuery width is compared to magic numbers.
///
/// Responsive breakpoints should be extracted to named constants
/// for clarity and maintainability.
///
/// **BAD:**
/// ```dart
/// if (MediaQuery.of(context).size.width > 600) { ... }
/// ```
///
/// **GOOD:**
/// ```dart
/// const kTabletBreakpoint = 600;
/// if (MediaQuery.of(context).size.width > kTabletBreakpoint) { ... }
/// ```
class RequireResponsiveBreakpointsRule extends SaropaLintRule {
  const RequireResponsiveBreakpointsRule() : super(code: _code);

  /// Minor improvement. Track for later review.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_responsive_breakpoints',
    problemMessage:
        '[require_responsive_breakpoints] Using magic numbers for breakpoints in MediaQuery makes code unclear and hard to maintain. Readers won’t know what the number means.',
    correctionMessage:
        'Extract the number to a named constant (e.g., kTabletBreakpoint) and use that in your MediaQuery comparisons for clarity and maintainability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      // Check for comparison operators
      final String operator = node.operator.lexeme;
      if (operator != '>' &&
          operator != '<' &&
          operator != '>=' &&
          operator != '<=' &&
          operator != '==') {
        return;
      }

      // Check if one side is a numeric literal
      IntegerLiteral? numericLiteral;
      Expression? otherSide;

      if (node.rightOperand is IntegerLiteral) {
        numericLiteral = node.rightOperand as IntegerLiteral;
        otherSide = node.leftOperand;
      } else if (node.leftOperand is IntegerLiteral) {
        numericLiteral = node.leftOperand as IntegerLiteral;
        otherSide = node.rightOperand;
      }

      if (numericLiteral == null || otherSide == null) return;

      // Check if the other side contains MediaQuery.of(context).size.width
      final String otherSource = otherSide.toSource();
      if (!otherSource.contains('MediaQuery') ||
          (!otherSource.contains('.width') && !otherSource.contains('.height'))) {
        return;
      }

      // Check if it's a common breakpoint value
      final int? value = numericLiteral.value;
      if (value == null) return;

      // Only flag common breakpoint ranges (300-1400 for responsive design)
      if (value >= 300 && value <= 1400) {
        reporter.atNode(numericLiteral, code);
      }
    });
  }
}

/// Warns when Paint() is created inside CustomPainter.paint() method.
///
/// Paint objects created in paint() are recreated every frame,
/// causing unnecessary allocations. Move to class fields for better performance.
///
/// **BAD:**
/// ```dart
/// class MyPainter extends CustomPainter {
///   @override
///   void paint(Canvas canvas, Size size) {
///     final paint = Paint()..color = Colors.red; // Recreated every frame!
///     canvas.drawRect(rect, paint);
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyPainter extends CustomPainter {
///   static final _paint = Paint()..color = Colors.red;
///
///   @override
///   void paint(Canvas canvas, Size size) {
///     canvas.drawRect(rect, _paint);
///   }
/// }
/// ```
class PreferCachedPaintObjectsRule extends SaropaLintRule {
  const PreferCachedPaintObjectsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_cached_paint_objects',
    problemMessage:
        '[prefer_cached_paint_objects] Creating Paint objects inside paint() causes new allocations every frame and hurts performance.',
    correctionMessage:
        'Move Paint creation outside paint() and reuse a static or instance field. This reduces allocations and improves performance.',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Paint') return;

      // Check if inside a paint() method
      bool insidePaintMethod = false;
      bool inCustomPainter = false;
      AstNode? current = node.parent;

      while (current != null) {
        if (current is MethodDeclaration && current.name.lexeme == 'paint') {
          insidePaintMethod = true;
        }
        if (current is ClassDeclaration) {
          final ExtendsClause? extendsClause = current.extendsClause;
          if (extendsClause != null) {
            final String? superName = extendsClause.superclass.element?.name;
            if (superName == 'CustomPainter') {
              inCustomPainter = true;
            }
          }
          break;
        }
        current = current.parent;
      }

      if (insidePaintMethod && inCustomPainter) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when CustomPainter.shouldRepaint always returns true.
///
/// Always returning true from shouldRepaint causes unnecessary repaints.
/// Compare relevant fields to determine if repaint is actually needed.
///
/// **BAD:**
/// ```dart
/// class MyPainter extends CustomPainter {
///   @override
///   bool shouldRepaint(covariant MyPainter old) => true; // Always repaints!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyPainter extends CustomPainter {
///   final Color color;
///   MyPainter(this.color);
///
///   @override
///   bool shouldRepaint(covariant MyPainter old) => old.color != color;
/// }
/// ```
class RequireCustomPainterShouldRepaintRule extends SaropaLintRule {
  const RequireCustomPainterShouldRepaintRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_custom_painter_shouldrepaint',
    problemMessage:
        '[require_custom_painter_shouldrepaint] Always returning true from shouldRepaint causes unnecessary repaints and wastes resources.',
    correctionMessage:
        'Compare relevant fields in shouldRepaint and only return true when the painter’s output would change. Avoid always returning true.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'shouldRepaint') return;

      // Check if in CustomPainter subclass
      final AstNode? parent = node.parent;
      if (parent is! ClassDeclaration) return;

      final ExtendsClause? extendsClause = parent.extendsClause;
      if (extendsClause == null) return;

      final String? superName = extendsClause.superclass.element?.name;
      if (superName != 'CustomPainter') return;

      // Check if body is just "=> true" or "{ return true; }"
      final FunctionBody body = node.body;

      if (body is ExpressionFunctionBody) {
        if (body.expression is BooleanLiteral) {
          final BooleanLiteral boolLit = body.expression as BooleanLiteral;
          if (boolLit.value) {
            reporter.atNode(body.expression, code);
          }
        }
      } else if (body is BlockFunctionBody) {
        final List<Statement> statements = body.block.statements;
        if (statements.length == 1 && statements.first is ReturnStatement) {
          final ReturnStatement returnStmt = statements.first as ReturnStatement;
          if (returnStmt.expression is BooleanLiteral) {
            final BooleanLiteral boolLit = returnStmt.expression as BooleanLiteral;
            if (boolLit.value) {
              reporter.atNode(returnStmt.expression!, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when NumberFormat.currency() lacks locale parameter.
///
/// Currency formatting depends heavily on locale. Without explicit locale,
/// the format may not match user expectations.
///
/// **BAD:**
/// ```dart
/// NumberFormat.currency().format(amount);
/// NumberFormat.simpleCurrency().format(amount);
/// ```
///
/// **GOOD:**
/// ```dart
/// NumberFormat.currency(locale: 'en_US').format(amount);
/// NumberFormat.currency(locale: Localizations.localeOf(context).toString()).format(amount);
/// ```
class RequireCurrencyFormattingLocaleRule extends SaropaLintRule {
  const RequireCurrencyFormattingLocaleRule() : super(code: _code);

  /// Minor improvement. Track for later review.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_currency_formatting_locale',
    problemMessage:
        '[require_currency_formatting_locale] NumberFormat.currency() without a locale can format currency inconsistently for users.',
    correctionMessage:
        'Always specify a locale for NumberFormat.currency() to ensure consistent formatting for all users.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _currencyConstructors = <String>{
    'currency',
    'simpleCurrency',
    'compactCurrency',
    'compactSimpleCurrency',
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
      final String typeName = node.constructorName.type.name.lexeme;
      final String? constructorName = node.constructorName.name?.name;

      if (typeName != 'NumberFormat') return;
      if (constructorName == null || !_currencyConstructors.contains(constructorName)) {
        return;
      }

      // Check for locale parameter
      bool hasLocale = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'locale') {
          hasLocale = true;
          break;
        }
      }

      if (!hasLocale) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when NumberFormat lacks locale parameter.
///
/// Number formatting varies by locale (decimal separators, grouping, etc.).
/// Explicit locale ensures consistent formatting across locales.
///
/// **BAD:**
/// ```dart
/// NumberFormat().format(number);
/// NumberFormat.decimal().format(number);
/// ```
///
/// **GOOD:**
/// ```dart
/// NumberFormat(null, 'en_US').format(number);
/// NumberFormat.decimal(locale: 'en_US').format(number);
/// ```
class RequireNumberFormattingLocaleRule extends SaropaLintRule {
  const RequireNumberFormattingLocaleRule() : super(code: _code);

  /// Minor improvement. Track for later review.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_number_formatting_locale',
    problemMessage:
        '[require_number_formatting_locale] Using NumberFormat or its named constructors without an explicit locale can lead to inconsistent number formatting, such as decimal separators and grouping, depending on the user’s device or system settings. This can cause confusion or misinterpretation of numbers.',
    correctionMessage:
        'Provide an explicit locale parameter to NumberFormat or its named constructors to ensure numbers are formatted consistently and as intended for all users.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _numberConstructors = <String>{
    'decimal',
    'decimalPattern',
    'decimalPercentPattern',
    'percent',
    'percentPattern',
    'scientificPattern',
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
      final String typeName = node.constructorName.type.name.lexeme;
      final String? constructorName = node.constructorName.name?.name;

      if (typeName != 'NumberFormat') return;

      // Check default constructor or named constructors
      if (constructorName == null) {
        // Default constructor - check if locale is provided as second positional arg
        if (node.argumentList.arguments.length < 2) {
          reporter.atNode(node.constructorName, code);
        }
        return;
      }

      if (!_numberConstructors.contains(constructorName)) return;

      // Check for locale parameter
      bool hasLocale = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'locale') {
          hasLocale = true;
          break;
        }
      }

      if (!hasLocale) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when GraphQL query/mutation strings lack operation names.
///
/// Anonymous GraphQL operations are harder to debug and don't work
/// with some features like persisted queries.
///
/// **BAD:**
/// ```dart
/// const query = '''
///   query {
///     users { id name }
///   }
/// ''';
/// ```
///
/// **GOOD:**
/// ```dart
/// const query = '''
///   query GetUsers {
///     users { id name }
///   }
/// ''';
/// ```
class RequireGraphqlOperationNamesRule extends SaropaLintRule {
  const RequireGraphqlOperationNamesRule() : super(code: _code);

  /// Minor improvement. Track for later review.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_graphql_operation_names',
    problemMessage:
        '[require_graphql_operation_names] Defining anonymous GraphQL queries, mutations, or subscriptions (without an operation name) makes debugging, error tracking, and persisted queries more difficult. Operation names are essential for identifying and managing GraphQL operations in large codebases and production environments.',
    correctionMessage:
        'Add a descriptive operation name immediately after the query, mutation, or subscription keyword in your GraphQL document. This improves maintainability, debugging, and compatibility with GraphQL tooling.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  // Patterns for anonymous queries/mutations
  static final RegExp _anonymousQuery = RegExp(r'query\s*\{');
  static final RegExp _anonymousMutation = RegExp(r'mutation\s*\{');
  static final RegExp _anonymousSubscription = RegExp(r'subscription\s*\{');

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;

      // Check if this looks like a GraphQL document
      if (!value.contains('{') || !value.contains('}')) return;

      // Check for anonymous operations
      if (_anonymousQuery.hasMatch(value) ||
          _anonymousMutation.hasMatch(value) ||
          _anonymousSubscription.hasMatch(value)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Badge shows count of 0 without hiding label.
///
/// Empty badges confuse users - a badge with "0" usually indicates
/// there's nothing to see. Hide the badge when count is zero.
///
/// **BAD:**
/// ```dart
/// Badge(
///   label: Text('0'), // Why show a badge for 0?
///   child: Icon(Icons.notifications),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Badge(
///   isLabelVisible: count > 0,
///   label: Text('$count'),
///   child: Icon(Icons.notifications),
/// )
/// ```
class AvoidBadgeWithoutMeaningRule extends SaropaLintRule {
  const AvoidBadgeWithoutMeaningRule() : super(code: _code);

  /// Minor UX improvement.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_badge_without_meaning',
    problemMessage:
        '[avoid_badge_without_meaning] Displaying a badge with a count of 0 provides no useful information to users and can create visual noise or confusion. Badges are intended to highlight actionable or noteworthy items, and showing them when empty diminishes their value.',
    correctionMessage:
        'Add isLabelVisible: count > 0 (or equivalent logic) to your Badge widget to hide the badge when the count is zero. This ensures badges only appear when there is something to notify the user about.',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Badge') return;

      // Check for label with literal '0'
      bool hasZeroLabel = false;
      bool hasIsLabelVisible = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String paramName = arg.name.label.name;

          if (paramName == 'isLabelVisible') {
            hasIsLabelVisible = true;
          }

          if (paramName == 'label') {
            final String labelSource = arg.expression.toSource();
            if (labelSource.contains("'0'") || labelSource.contains('"0"')) {
              hasZeroLabel = true;
            }
          }
        }
      }

      if (hasZeroLabel && !hasIsLabelVisible) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when print() is used instead of proper logging.
///
/// print() statements ship to production and appear in device logs.
/// Use dart:developer log() or a logging package for better control
/// over log levels, formatting, and production filtering.
///
/// **BAD:**
/// ```dart
/// print('User logged in: $userId'); // Shows in production logs!
/// ```
///
/// **GOOD:**
/// ```dart
/// import 'dart:developer';
/// log('User logged in: $userId', name: 'Auth');
/// ```
class PreferLoggerOverPrintRule extends SaropaLintRule {
  const PreferLoggerOverPrintRule() : super(code: _code);

  /// Code quality improvement.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_logger_over_print',
    problemMessage:
        '[prefer_logger_over_print] Using print() for logging in production code is discouraged because print statements are not filterable, lack log levels, and may expose sensitive information in release builds. Proper logging allows for better control, filtering, and analysis of application events.',
    correctionMessage:
        'Replace print() statements with calls to dart:developer log() or a structured logging package. This provides better log management, filtering, and security in production environments.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'print') return;

      // Skip if target is specified (e.g., someObject.print())
      if (node.target != null) return;

      reporter.atNode(node.methodName, code);
    });
  }
}

/// Warns when ListView.builder lacks itemExtent for uniform items.
///
/// When all list items have the same height, setting itemExtent
/// allows Flutter to optimize layout calculations, improving
/// scroll performance significantly.
///
/// **BAD:**
/// ```dart
/// ListView.builder(
///   itemCount: 100,
///   itemBuilder: (context, index) => ListTile(...), // All same height
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ListView.builder(
///   itemCount: 100,
///   itemExtent: 72.0, // ListTile standard height
///   itemBuilder: (context, index) => ListTile(...),
/// )
/// ```
class PreferItemExtentWhenKnownRule extends SaropaLintRule {
  const PreferItemExtentWhenKnownRule() : super(code: _code);

  /// Performance optimization suggestion.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_itemextent_when_known',
    problemMessage:
        '[prefer_itemextent_when_known] Consider adding itemExtent for better scroll performance.',
    correctionMessage: 'Set itemExtent when all list items have the same height.',
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
      final String typeName = node.constructorName.type.name.lexeme;
      final String? constructorName = node.constructorName.name?.name;

      if (typeName != 'ListView') return;
      if (constructorName != 'builder' && constructorName != 'separated') {
        return;
      }

      // Check for itemExtent or prototypeItem
      bool hasItemExtent = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String paramName = arg.name.label.name;
          if (paramName == 'itemExtent' || paramName == 'prototypeItem') {
            hasItemExtent = true;
            break;
          }
        }
      }

      if (!hasItemExtent) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when TabBarView children don't preserve state on tab switch.
///
/// By default, tab content is disposed when switching tabs. Use
/// AutomaticKeepAliveClientMixin to preserve state across tab switches.
///
/// **BAD:**
/// ```dart
/// TabBarView(
///   children: [
///     MyFormWidget(), // Form state lost when switching tabs!
///     MyListWidget(),
///   ],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyFormState extends State<MyFormWidget>
///     with AutomaticKeepAliveClientMixin {
///   @override
///   bool get wantKeepAlive => true;
///   // ...
/// }
/// ```
class RequireTabStatePreservationRule extends SaropaLintRule {
  const RequireTabStatePreservationRule() : super(code: _code);

  /// UX issue - form state loss frustrates users.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_tab_state_preservation',
    problemMessage:
        '[require_tab_state_preservation] TabBarView children may lose state on tab switch.',
    correctionMessage: 'Use AutomaticKeepAliveClientMixin to preserve state.',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'TabBarView') return;

      // Check if in a class that has wantKeepAlive
      AstNode? current = node.parent;
      ClassDeclaration? enclosingClass;

      while (current != null) {
        if (current is ClassDeclaration) {
          enclosingClass = current;
          break;
        }
        current = current.parent;
      }

      // Only warn if we're sure there's no state preservation consideration
      // This is a reminder, not a strict error
      if (enclosingClass != null) {
        final String classSource = enclosingClass.toSource();
        if (!classSource.contains('AutomaticKeepAliveClientMixin') &&
            !classSource.contains('wantKeepAlive')) {
          reporter.atNode(node.constructorName, code);
        }
      }
    });
  }
}

/// Warns when CircularProgressIndicator is used for content loading.
///
/// Skeleton loaders provide better perceived performance than spinners.
/// They give users a preview of content structure while loading.
///
/// **BAD:**
/// ```dart
/// if (isLoading) {
///   return Center(child: CircularProgressIndicator());
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// if (isLoading) {
///   return ShimmerLoading(child: ContentSkeleton());
/// }
/// ```
class PreferSkeletonOverSpinnerRule extends SaropaLintRule {
  const PreferSkeletonOverSpinnerRule() : super(code: _code);

  /// UX improvement, not a bug. Track for later.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_skeleton_over_spinner',
    problemMessage:
        '[prefer_skeleton_over_spinner] CircularProgressIndicator for content loading. Consider skeleton loaders.',
    correctionMessage: 'Use skeleton/shimmer loaders for better perceived performance.',
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

      if (typeName != 'CircularProgressIndicator' && typeName != 'LinearProgressIndicator') {
        return;
      }

      // Check if inside conditional (loading state)
      AstNode? current = node.parent;
      while (current != null) {
        if (current is ConditionalExpression || current is IfStatement || current is IfElement) {
          // Found in conditional - likely a loading state
          reporter.atNode(node.constructorName, code);
          return;
        }
        // Stop at method boundary
        if (current is MethodDeclaration || current is FunctionDeclaration) {
          break;
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when search results view has no empty state handling.
///
/// Search results should show a helpful message when no results are found.
/// Empty ListView/GridView with no indicator confuses users.
///
/// **BAD:**
/// ```dart
/// ListView.builder(
///   itemCount: searchResults.length,
///   itemBuilder: (ctx, i) => ResultTile(searchResults[i]),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// searchResults.isEmpty
///   ? EmptyState(message: 'No results found')
///   : ListView.builder(
///       itemCount: searchResults.length,
///       itemBuilder: (ctx, i) => ResultTile(searchResults[i]),
///     );
/// ```
class RequireEmptyResultsStateRule extends SaropaLintRule {
  const RequireEmptyResultsStateRule() : super(code: _code);

  /// UX issue that confuses users.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_empty_results_state',
    problemMessage:
        '[require_empty_results_state] List with search-related name missing empty state check.',
    correctionMessage: 'Add isEmpty check with empty state UI for better UX.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const _searchTerms = [
    'search',
    'result',
    'filter',
    'query',
    'found',
  ];

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name.lexeme;

      // Check list builders
      if (!typeName.contains('ListView') && !typeName.contains('GridView')) {
        return;
      }

      // Check if itemCount references search-related variable
      final itemCountArg = node.argumentList.arguments
          .whereType<NamedExpression>()
          .where((arg) => arg.name.label.name == 'itemCount')
          .firstOrNull;

      if (itemCountArg == null) {
        return;
      }

      final itemCountSource = itemCountArg.expression.toSource().toLowerCase();

      // Check if it's search-related
      final isSearchRelated = _searchTerms.any((term) => itemCountSource.contains(term));

      if (!isSearchRelated) {
        return;
      }

      // Check if there's an isEmpty check in the parent
      AstNode? current = node.parent;
      while (current != null) {
        final source = current.toSource().toLowerCase();
        if (source.contains('.isempty') || source.contains('.isnotempty')) {
          return; // Has empty check
        }
        if (current is ConditionalExpression || current is IfStatement || current is IfElement) {
          // Check if condition checks for empty
          if (source.contains('length') && source.contains('0')) {
            return;
          }
        }
        if (current is MethodDeclaration) {
          break;
        }
        current = current.parent;
      }

      reporter.atNode(node.constructorName, code);
    });
  }
}

/// Warns when search triggers without loading indicator.
///
/// When triggering a search (API call), users need feedback that
/// something is happening. Missing loading state causes confusion.
///
/// **BAD:**
/// ```dart
/// TextField(
///   onSubmitted: (query) => searchApi(query),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// TextField(
///   onSubmitted: (query) {
///     setState(() => isLoading = true);
///     searchApi(query).whenComplete(() {
///       setState(() => isLoading = false);
///     });
///   },
/// );
/// ```
class RequireSearchLoadingIndicatorRule extends SaropaLintRule {
  const RequireSearchLoadingIndicatorRule() : super(code: _code);

  /// UX issue that confuses users.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_search_loading_indicator',
    problemMessage:
        '[require_search_loading_indicator] Search callback without loading state management.',
    correctionMessage: 'Set loading state before search and clear it on completion.',
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

      // Check text fields
      if (typeName != 'TextField' && typeName != 'TextFormField') {
        return;
      }

      // Find onSubmitted or controller.addListener
      for (final arg in node.argumentList.arguments) {
        if (arg is! NamedExpression) continue;

        final paramName = arg.name.label.name;
        if (paramName != 'onSubmitted' && paramName != 'onEditingComplete') {
          continue;
        }

        // Check if callback contains search-related terms
        final callbackSource = arg.expression.toSource().toLowerCase();
        if (!callbackSource.contains('search') &&
            !callbackSource.contains('query') &&
            !callbackSource.contains('find') &&
            !callbackSource.contains('fetch')) {
          continue;
        }

        // Check if it sets loading state
        if (!callbackSource.contains('loading') &&
            !callbackSource.contains('isloading') &&
            !callbackSource.contains('isSearching')) {
          reporter.atNode(arg, code);
        }
      }
    });
  }
}

/// Warns when search TextField triggers API calls without debounce.
///
/// Typing in search fields should be debounced to avoid excessive
/// API calls. Each keystroke triggering a request wastes resources.
///
/// **BAD:**
/// ```dart
/// TextField(
///   onChanged: (text) => searchApi(text),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// TextField(
///   onChanged: (text) => _debouncer.run(() => searchApi(text)),
/// );
/// ```
///
/// **ALSO GOOD:**
/// ```dart
/// // Using onSubmitted instead of onChanged
/// TextField(
///   onSubmitted: (text) => searchApi(text),
/// );
/// ```
class RequireSearchDebounceRule extends SaropaLintRule {
  const RequireSearchDebounceRule() : super(code: _code);

  /// Performance and cost issue from excessive API calls.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_search_debounce',
    problemMessage:
        '[require_search_debounce] Calling a search API on every keystroke can overwhelm your backend, degrade performance, and create a poor user experience. Without debouncing, users may see lag, rate limits, or unnecessary network traffic.',
    correctionMessage:
        'Wrap your search trigger in a Debouncer or Timer so the API is only called after the user stops typing for a short period (e.g., 300ms). This reduces load and improves responsiveness.',
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

      if (typeName != 'TextField' && typeName != 'TextFormField') {
        return;
      }

      // Find onChanged callback
      NamedExpression? onChangedArg;
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'onChanged') {
          onChangedArg = arg;
          break;
        }
      }

      if (onChangedArg == null) {
        return;
      }

      final callbackSource = onChangedArg.expression.toSource().toLowerCase();

      // Check if it's search-related
      final isSearchRelated = callbackSource.contains('search') ||
          callbackSource.contains('query') ||
          callbackSource.contains('find') ||
          callbackSource.contains('fetch') ||
          callbackSource.contains('api');

      if (!isSearchRelated) {
        return;
      }

      // Check for debounce mechanisms
      final hasDebounce = callbackSource.contains('debounce') ||
          callbackSource.contains('throttle') ||
          callbackSource.contains('timer') ||
          callbackSource.contains('delay') ||
          callbackSource.contains('cancellable');

      if (!hasDebounce) {
        reporter.atNode(onChangedArg, code);
      }
    });
  }
}

/// Warns when paginated list has no loading state for next page.
///
/// Infinite scroll lists should show a loading indicator when
/// fetching the next page of results.
///
/// **BAD:**
/// ```dart
/// ListView.builder(
///   itemCount: items.length,
///   itemBuilder: (ctx, i) {
///     if (i == items.length - 1) loadMore();
///     return ItemTile(items[i]);
///   },
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// ListView.builder(
///   itemCount: items.length + (isLoadingMore ? 1 : 0),
///   itemBuilder: (ctx, i) {
///     if (i == items.length) return LoadingIndicator();
///     if (i == items.length - 1) loadMore();
///     return ItemTile(items[i]);
///   },
/// );
/// ```
class RequirePaginationLoadingStateRule extends SaropaLintRule {
  const RequirePaginationLoadingStateRule() : super(code: _code);

  /// UX issue affecting user experience during loading.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_pagination_loading_state',
    problemMessage:
        '[require_pagination_loading_state] Paginated list triggers loadMore but shows no loading indicator.',
    correctionMessage: 'Add +1 to itemCount when loading and show indicator at the end.',
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

      if (!typeName.contains('ListView') && !typeName.contains('GridView')) {
        return;
      }

      // Check if it's a builder pattern
      final constructorName = node.constructorName.name?.name ?? '';
      if (constructorName != 'builder' && constructorName != 'separated') {
        return;
      }

      // Find itemBuilder
      final itemBuilderArg = node.argumentList.arguments
          .whereType<NamedExpression>()
          .where((arg) => arg.name.label.name == 'itemBuilder')
          .firstOrNull;

      if (itemBuilderArg == null) {
        return;
      }

      final builderSource = itemBuilderArg.expression.toSource().toLowerCase();

      // Check for pagination pattern (loadMore, fetchMore, nextPage)
      final hasPagination = builderSource.contains('loadmore') ||
          builderSource.contains('fetchmore') ||
          builderSource.contains('nextpage') ||
          builderSource.contains('loadnext');

      if (!hasPagination) {
        return;
      }

      // Check itemCount for loading indicator
      final itemCountArg = node.argumentList.arguments
          .whereType<NamedExpression>()
          .where((arg) => arg.name.label.name == 'itemCount')
          .firstOrNull;

      if (itemCountArg == null) {
        return;
      }

      final itemCountSource = itemCountArg.expression.toSource().toLowerCase();

      // Check if itemCount includes loading state
      final hasLoadingInCount = itemCountSource.contains('loading') ||
          itemCountSource.contains('+ 1') ||
          itemCountSource.contains('+1');

      if (!hasLoadingInCount) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when WebView lacks a progress indicator for page loading.
///
/// WebView page loads can take significant time. Without a progress indicator,
/// users may think the app is frozen or broken. Show loading state while
/// content loads.
///
/// **BAD:**
/// ```dart
/// WebView(
///   initialUrl: 'https://example.com',
/// ) // No loading feedback!
///
/// InAppWebView(
///   initialUrlRequest: URLRequest(url: Uri.parse(url)),
/// ) // User sees blank page during load
/// ```
///
/// **GOOD:**
/// ```dart
/// Stack(
///   children: [
///     WebView(
///       initialUrl: 'https://example.com',
///       onProgress: (progress) => setState(() => _progress = progress),
///       onPageFinished: (_) => setState(() => _isLoading = false),
///     ),
///     if (_isLoading)
///       LinearProgressIndicator(value: _progress / 100),
///   ],
/// )
///
/// InAppWebView(
///   initialUrlRequest: URLRequest(url: Uri.parse(url)),
///   onProgressChanged: (controller, progress) {
///     setState(() => _progress = progress / 100);
///   },
///   onLoadStop: (controller, url) {
///     setState(() => _isLoading = false);
///   },
/// )
/// ```
class RequireWebViewProgressIndicatorRule extends SaropaLintRule {
  const RequireWebViewProgressIndicatorRule() : super(code: _code);

  /// Missing loading indicator creates poor UX.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_webview_progress_indicator',
    problemMessage:
        '[require_webview_progress_indicator] WebView without progress indicator. Users see no loading feedback.',
    correctionMessage: 'Add onProgress/onProgressChanged callback to show loading state.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _webViewTypes = <String>{
    'WebView',
    'WebViewWidget',
    'InAppWebView',
    'WebViewX',
  };

  static const Set<String> _progressParams = <String>{
    'onprogress',
    'onprogresschanged',
    'onloadprogress',
    'progressindicator',
    'loadingbuilder',
    'onpagestarted',
    'onloadstart',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_webViewTypes.contains(typeName)) return;

      // Check for progress-related callbacks
      bool hasProgressIndicator = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String paramName = arg.name.label.name.toLowerCase();
          if (_progressParams.contains(paramName)) {
            hasProgressIndicator = true;
            break;
          }
        }
      }

      // Also check if the WebView is wrapped in a Stack (common pattern)
      AstNode? parent = node.parent;
      while (parent != null) {
        if (parent is InstanceCreationExpression) {
          final String parentType = parent.constructorName.type.name.lexeme;
          if (parentType == 'Stack') {
            // Assume Stack contains loading indicator
            hasProgressIndicator = true;
            break;
          }
        }
        if (parent is MethodDeclaration || parent is FunctionDeclaration) {
          break;
        }
        parent = parent.parent;
      }

      if (!hasProgressIndicator) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

// =============================================================================
// avoid_loading_flash
// =============================================================================

/// Warns when loading states may cause a visible flash.
///
/// Alias: loading_flash, shimmer_delay
///
/// Immediate loading indicator flash is jarring. Show content immediately for
/// fast loads, or delay showing spinner/shimmer by ~200ms.
///
/// **BAD:**
/// ```dart
/// FutureBuilder<Data>(
///   future: fetchData(),
///   builder: (context, snapshot) {
///     if (snapshot.connectionState == ConnectionState.waiting) {
///       return CircularProgressIndicator(); // Flashes for fast loads!
///     }
///     return DataWidget(snapshot.data!);
///   },
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// // Option 1: Use shimmer with minimum display time
/// Shimmer.fromColors(
///   baseColor: Colors.grey[300]!,
///   highlightColor: Colors.grey[100]!,
///   child: PlaceholderWidget(),
/// )
///
/// // Option 2: Delay showing loading indicator
/// FutureBuilder<Data>(
///   future: fetchData(),
///   builder: (context, snapshot) {
///     if (snapshot.connectionState == ConnectionState.waiting) {
///       return DelayedLoader(delay: Duration(milliseconds: 200));
///     }
///     return DataWidget(snapshot.data!);
///   },
/// )
/// ```
class AvoidLoadingFlashRule extends SaropaLintRule {
  const AvoidLoadingFlashRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_loading_flash',
    problemMessage: '[avoid_loading_flash] Loading indicator shown without delay. Fast '
        'responses will cause jarring visual flash.',
    correctionMessage: 'Add a small delay (~200ms) before showing loading indicator, '
        'or use skeleton/shimmer placeholders.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for FutureBuilder or StreamBuilder
      final Expression? target = node.target;
      if (target != null) return; // Method on object, not constructor

      // Look for builder pattern that immediately shows loading
      if (node.methodName.name != 'builder') return;
    });

    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;

      // Check for FutureBuilder or StreamBuilder
      if (typeName != 'FutureBuilder' && typeName != 'StreamBuilder') return;

      // Check if the builder immediately shows loading indicator
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'builder') {
          final String builderSource = arg.expression.toSource();

          // Check for immediate loading indicator without delay
          if (builderSource.contains('CircularProgressIndicator') ||
              builderSource.contains('LinearProgressIndicator')) {
            // Check if there's a delay mechanism
            if (!builderSource.contains('delay') &&
                !builderSource.contains('Future.delayed') &&
                !builderSource.contains('Timer') &&
                !builderSource.contains('Shimmer') &&
                !builderSource.contains('Skeleton')) {
              reporter.atNode(node.constructorName, code);
            }
          }
        }
      }
    });
  }
}
