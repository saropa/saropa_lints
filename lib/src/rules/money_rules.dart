// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Money and currency rules for Flutter/Dart applications.
///
/// These rules detect common mistakes when handling monetary values
/// that can cause precision issues and incorrect calculations.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when double is used for money/currency values.
///
/// Alias: no_double_for_currency, money_type_safety, decimal_for_money
///
/// Floating point arithmetic has precision issues (0.1 + 0.2 != 0.3).
/// Use int cents or a Decimal package for monetary calculations.
///
/// **BAD:**
/// ```dart
/// double price = 19.99;
/// double total = price * quantity;
/// ```
///
/// **GOOD:**
/// ```dart
/// int priceInCents = 1999;
/// int totalInCents = priceInCents * quantity;
///
/// // Or use a Decimal package:
/// Decimal price = Decimal.parse('19.99');
/// ```
///
/// **Quick fix available:** Adds a review comment for manual attention.
class AvoidDoubleForMoneyRule extends SaropaLintRule {
  const AvoidDoubleForMoneyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_double_for_money',
    problemMessage:
        '[avoid_double_for_money] double has precision issues for money. Use int cents or Decimal.',
    correctionMessage: 'Store money as int cents or use a Decimal package.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// Only unambiguous money-related terms, matched as complete words.
  /// Short currency codes (usd, eur, etc.) removed - too ambiguous even
  /// as words (e.g., "cad" could be CAD file format, "aud" in audio-related).
  /// Generic terms (cost, fee, payment, etc.) removed - too many false
  /// positives (computational cost, service fee, payment callback, etc.)
  static const Set<String> _moneyIndicators = <String>{
    'price', // itemPrice, unitPrice
    'prices',
    'money', // explicit
    'currency', // explicit
    'currencies',
    'dollar',
    'dollars',
    'euro',
    'euros',
    'salary', // definitely money
    'salaries',
    'wage', // definitely money
    'wages',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      // Check type
      final VariableDeclarationList? parent =
          node.parent is VariableDeclarationList
              ? node.parent as VariableDeclarationList
              : null;
      if (parent == null) return;

      final String? typeName = parent.type?.toSource();
      if (typeName != 'double' && typeName != 'double?') return;

      // Check variable name for money indicators
      final String varName = node.name.lexeme;
      if (_containsMoneyIndicator(varName)) {
        reporter.atNode(node, code);
      }
    });

    context.registry.addFieldDeclaration((FieldDeclaration node) {
      final String? typeName = node.fields.type?.toSource();
      if (typeName != 'double' && typeName != 'double?') return;

      for (final VariableDeclaration variable in node.fields.variables) {
        final String varName = variable.name.lexeme;
        if (_containsMoneyIndicator(varName)) {
          reporter.atNode(variable, code);
        }
      }
    });
  }

  /// Regex to split camelCase and snake_case into words.
  /// Matches: lowercase followed by uppercase, or underscores.
  static final RegExp _wordSplitPattern = RegExp(r'(?<=[a-z])(?=[A-Z])|_');

  /// Extracts individual words from a variable name.
  /// Supports camelCase, PascalCase, and snake_case.
  ///
  /// Examples:
  /// - 'itemPrice' -> ['item', 'price']
  /// - 'totalPriceInCents' -> ['total', 'price', 'in', 'cents']
  /// - 'audio_volume' -> ['audio', 'volume']
  static List<String> _extractWords(String varName) {
    return varName
        .split(_wordSplitPattern)
        .where((word) => word.isNotEmpty)
        .map((word) => word.toLowerCase())
        .toList();
  }

  /// Checks if a variable name contains a money indicator as a complete word.
  /// Uses word-boundary matching to avoid false positives like:
  /// - 'audioVolume' matching 'aud' (Australian dollar)
  /// - 'cadence' matching 'cad' (Canadian dollar)
  static bool _containsMoneyIndicator(String varName) {
    final List<String> words = _extractWords(varName);

    for (final String word in words) {
      if (_moneyIndicators.contains(word)) {
        return true;
      }
    }

    return false;
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddMoneyHackCommentFix()];
}

class _AddMoneyHackCommentFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment for manual review',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '/* HACK: Use int cents or Decimal for money */ ',
        );
      });
    });

    context.registry.addFieldDeclaration((FieldDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment for manual review',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Use int cents or Decimal for money\n  ',
        );
      });
    });
  }
}
