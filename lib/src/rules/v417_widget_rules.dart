// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

// =============================================================================
// v4.1.7 Rules - Widget & Layout Best Practices
// =============================================================================

/// Warns when complex positioning uses nested widgets instead of CustomSingleChildLayout.
///
/// For complex single-child positioning logic, CustomSingleChildLayout is more
/// efficient than nested Positioned/Align/Transform widgets.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return Stack(children: [
///     Positioned(
///       top: calculateTop(),
///       left: calculateLeft(),
///       child: Transform.rotate(
///         angle: calculateAngle(),
///         child: Align(
///           alignment: calculateAlignment(),
///           child: MyWidget(),
///         ),
///       ),
///     ),
///   ]);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return CustomSingleChildLayout(
///     delegate: MyLayoutDelegate(),
///     child: MyWidget(),
///   );
/// }
/// ```
class PreferCustomSingleChildLayoutRule extends SaropaLintRule {
  const PreferCustomSingleChildLayoutRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_custom_single_child_layout',
    problemMessage:
        '[prefer_custom_single_child_layout] Deeply nested positioning widgets. Consider CustomSingleChildLayout.',
    correctionMessage:
        'Use CustomSingleChildLayout with a delegate for complex single-child positioning.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _positioningWidgets = {
    'Positioned',
    'Align',
    'Transform',
    'FractionalTranslation',
    'Padding',
  };

  static const int _nestingThreshold = 3;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String widgetName = node.constructorName.type.name2.lexeme;

      if (!_positioningWidgets.contains(widgetName)) return;

      // Count nesting depth of positioning widgets
      int depth = 1;
      AstNode? current = node.parent;
      while (current != null) {
        if (current is InstanceCreationExpression) {
          final String parentName = current.constructorName.type.name2.lexeme;
          if (_positioningWidgets.contains(parentName)) {
            depth++;
          }
        }
        current = current.parent;
      }

      if (depth >= _nestingThreshold) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when text operations are done without explicit Locale.
///
/// Some text operations (date formatting, number formatting, sorting)
/// produce incorrect results without explicit Locale.
///
/// **BAD:**
/// ```dart
/// final formatted = NumberFormat.currency().format(amount); // Uses device locale!
/// final date = DateFormat.yMd().format(now); // May vary by device!
/// names.sort(); // String sorting depends on locale!
/// ```
///
/// **GOOD:**
/// ```dart
/// final formatted = NumberFormat.currency(locale: 'en_US').format(amount);
/// final date = DateFormat.yMd('en_US').format(now);
/// names.sort((a, b) => a.compareTo(b)); // Or use explicit collation
/// ```
class RequireLocaleForTextRule extends SaropaLintRule {
  const RequireLocaleForTextRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_locale_for_text',
    problemMessage:
        '[require_locale_for_text] Text formatting without explicit locale may vary by device.',
    correctionMessage:
        'Provide explicit locale parameter for consistent formatting across devices.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String constructorName = node.constructorName.type.name2.lexeme;

      // Check for NumberFormat, DateFormat
      if (constructorName != 'NumberFormat' &&
          constructorName != 'DateFormat') {
        return;
      }

      // Check if locale is provided
      final String argsSource = node.argumentList.toSource();
      if (!argsSource.contains('locale:') &&
          !argsSource.contains("'en") &&
          !argsSource.contains('"en')) {
        reporter.atNode(node, code);
      }
    });

    // Also check for static constructors like DateFormat.yMd()
    context.registry.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;

      if (target.name != 'NumberFormat' && target.name != 'DateFormat') return;

      // Check if locale is provided in the arguments
      final String argsSource = node.argumentList.toSource();
      if (argsSource == '()' || // No arguments
          (!argsSource.contains('locale:') &&
              !argsSource.contains("'en") &&
              !argsSource.contains('"en'))) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when destructive dialogs can be dismissed by tapping barrier.
///
/// `[HEURISTIC]` - Detects showDialog without explicit barrierDismissible for destructive actions.
///
/// Destructive confirmations shouldn't dismiss on barrier tap.
/// Users might accidentally dismiss important dialogs.
///
/// **BAD:**
/// ```dart
/// showDialog(
///   context: context,
///   builder: (context) => AlertDialog(
///     title: Text('Delete account?'),
///     content: Text('This cannot be undone.'),
///     actions: [
///       TextButton(onPressed: deleteAccount, child: Text('Delete')),
///     ],
///   ),
/// ); // barrierDismissible defaults to true!
/// ```
///
/// **GOOD:**
/// ```dart
/// showDialog(
///   context: context,
///   barrierDismissible: false, // Explicit for destructive action
///   builder: (context) => AlertDialog(
///     title: Text('Delete account?'),
///     // ...
///   ),
/// );
/// ```
class RequireDialogBarrierConsiderationRule extends SaropaLintRule {
  const RequireDialogBarrierConsiderationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_dialog_barrier_consideration',
    problemMessage:
        '[require_dialog_barrier_consideration] Destructive dialog without explicit barrierDismissible.',
    correctionMessage:
        'Set barrierDismissible: false for destructive confirmation dialogs.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static final RegExp _destructivePattern = RegExp(
    r'\b(delete|remove|destroy|cancel|discard|erase|clear|reset|logout|signout|unsubscribe)\b',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'showDialog') return;

      final String argsSource = node.argumentList.toSource();

      // Check if barrierDismissible is set
      if (argsSource.contains('barrierDismissible')) return;

      // Check if dialog content contains destructive keywords
      if (_destructivePattern.hasMatch(argsSource)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when folder structure doesn't follow feature-based organization.
///
/// `[HEURISTIC]` - Checks file path patterns.
///
/// Group files by feature (/auth, /profile) instead of type (/bloc, /ui)
/// for better scalability.
///
/// **BAD:**
/// ```
/// lib/
///   bloc/
///     user_bloc.dart
///     order_bloc.dart
///   ui/
///     user_screen.dart
///     order_screen.dart
///   models/
///     user.dart
///     order.dart
/// ```
///
/// **GOOD:**
/// ```
/// lib/
///   features/
///     user/
///       user_bloc.dart
///       user_screen.dart
///       user_model.dart
///     order/
///       order_bloc.dart
///       order_screen.dart
///       order_model.dart
/// ```
class PreferFeatureFolderStructureRule extends SaropaLintRule {
  const PreferFeatureFolderStructureRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_feature_folder_structure',
    problemMessage:
        '[prefer_feature_folder_structure] File in type-based folder. Consider feature-based organization.',
    correctionMessage:
        'Group files by feature (features/auth/) instead of type (blocs/, models/).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static final RegExp _typeBasedFolderPattern = RegExp(
    r'/(blocs?|cubits?|providers?|models?|widgets?|screens?|pages?|views?)/',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check the file path
    final String filePath = resolver.source.fullName;

    if (_typeBasedFolderPattern.hasMatch(filePath)) {
      // Report on the compilation unit (file level)
      context.registry.addCompilationUnit((CompilationUnit node) {
        // Only report once per file, on the first declaration
        if (node.declarations.isNotEmpty) {
          reporter.atNode(node.declarations.first, code);
        }
      });
    }
  }
}
