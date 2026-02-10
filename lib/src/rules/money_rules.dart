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
/// Since: v1.7.9 | Updated: v4.13.0 | Rule version: v4
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
        '[avoid_double_for_money] Floating point causes rounding errors in '
        r'money calculations. $0.1 + $0.2 != $0.3, causing financial loss. {v4}',
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

// =============================================================================
// Currency Rules (from v4.1.7)
// =============================================================================

/// Warns when money amounts are stored without currency information.
///
/// Since: v4.1.8 | Updated: v4.13.0 | Rule version: v2
///
/// `[HEURISTIC]` - Detects money-related classes without currency field.
///
/// Amounts without currency are ambiguous. Always pair amounts with
/// currency codes.
///
/// **BAD:**
/// ```dart
/// class Price {
///   final double amount; // USD? EUR? BTC?
///
///   Price(this.amount);
/// }
///
/// class Order {
///   final double total; // What currency?
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class Price {
///   final double amount;
///   final String currency; // 'USD', 'EUR', etc.
///
///   Price(this.amount, this.currency);
/// }
///
/// class Order {
///   final Money total; // Money class includes currency
/// }
/// ```
class RequireCurrencyCodeWithAmountRule extends SaropaLintRule {
  const RequireCurrencyCodeWithAmountRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_currency_code_with_amount',
    problemMessage:
        '[require_currency_code_with_amount] Money amount without currency information. Amounts without currency are ambiguous. Always pair amounts with currency codes. This monetary calculation can produce rounding errors that accumulate, causing financial discrepancies. {v2}',
    correctionMessage:
        'Add currency field (String currency or CurrencyCode enum) alongside amount. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static final RegExp _moneyFieldPattern = RegExp(
    r'\b(price|amount|cost|total|balance|fee|charge|payment|salary|wage|rate)\b',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String className = node.name.lexeme.toLowerCase();

      // Skip if class name suggests it already handles currency
      if (className.contains('money') || className.contains('currency')) {
        return;
      }

      // Check for money-related fields
      bool hasMoneyField = false;
      bool hasCurrencyField = false;

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            final String fieldName = variable.name.lexeme.toLowerCase();

            if (_moneyFieldPattern.hasMatch(fieldName)) {
              // Check if it's a numeric type
              final TypeAnnotation? type = member.fields.type;
              if (type != null) {
                final String typeStr = type.toSource().toLowerCase();
                if (typeStr.contains('double') ||
                    typeStr.contains('int') ||
                    typeStr.contains('num') ||
                    typeStr.contains('decimal')) {
                  hasMoneyField = true;
                }
              }
            }

            if (fieldName.contains('currency') || fieldName.contains('code')) {
              hasCurrencyField = true;
            }
          }
        }
      }

      if (hasMoneyField && !hasCurrencyField) {
        reporter.atNode(node, code);
      }
    });
  }
}
