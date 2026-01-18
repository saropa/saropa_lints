// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

// =============================================================================
// v4.1.7 Rules - WebSocket, Currency, and Dependency Injection
// =============================================================================

/// Warns when WebSocket connections lack reconnection logic.
///
/// `[HEURISTIC]` - Detects WebSocketChannel without reconnection handling.
///
/// WebSocket connections drop unexpectedly. Implement automatic reconnection
/// with exponential backoff.
///
/// **BAD:**
/// ```dart
/// class ChatService {
///   late WebSocketChannel _channel;
///
///   void connect() {
///     _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
///     // No reconnection logic - connection lost forever on disconnect!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class ChatService {
///   WebSocketChannel? _channel;
///   int _retryCount = 0;
///
///   void connect() {
///     _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
///     _channel!.stream.listen(
///       onMessage,
///       onDone: _reconnect, // Handle disconnection
///       onError: (e) => _reconnect(),
///     );
///   }
///
///   void _reconnect() {
///     final delay = Duration(seconds: pow(2, _retryCount++).toInt());
///     Future.delayed(delay, connect);
///   }
/// }
/// ```
class RequireWebsocketReconnectionRule extends SaropaLintRule {
  const RequireWebsocketReconnectionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_websocket_reconnection',
    problemMessage:
        '[require_websocket_reconnection] WebSocket without reconnection logic.',
    correctionMessage:
        'Implement automatic reconnection with exponential backoff for WebSocket connections.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String classSource = node.toSource();

      // Check if class uses WebSocket
      if (!classSource.contains('WebSocketChannel') &&
          !classSource.contains('WebSocket')) {
        return;
      }

      // Check for reconnection logic indicators
      final bool hasReconnection = classSource.contains('reconnect') ||
          classSource.contains('retry') ||
          classSource.contains('onDone:') ||
          classSource.contains('onError:') ||
          classSource.contains('backoff');

      if (!hasReconnection) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when money amounts are stored without currency information.
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
        '[require_currency_code_with_amount] Money amount without currency information.',
    correctionMessage:
        'Add currency field (String currency or CurrencyCode enum) alongside amount.',
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

/// Warns when eager singleton registration is used for expensive objects.
///
/// `[HEURISTIC]` - Detects registerSingleton with expensive constructors.
///
/// Eager registration creates all singletons at startup.
/// Use registerLazySingleton for expensive objects.
///
/// **BAD:**
/// ```dart
/// void setupDI() {
///   GetIt.I.registerSingleton(DatabaseService()); // Created immediately!
///   GetIt.I.registerSingleton(AnalyticsService()); // Created immediately!
///   GetIt.I.registerSingleton(CacheService()); // All at startup!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void setupDI() {
///   GetIt.I.registerLazySingleton(() => DatabaseService()); // Created on first use
///   GetIt.I.registerLazySingleton(() => AnalyticsService());
///   GetIt.I.registerLazySingleton(() => CacheService());
/// }
/// ```
class PreferLazySingletonRegistrationRule extends SaropaLintRule {
  const PreferLazySingletonRegistrationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_lazy_singleton_registration',
    problemMessage:
        '[prefer_lazy_singleton_registration] Eager singleton registration. Consider lazy registration.',
    correctionMessage:
        'Use registerLazySingleton(() => Service()) for deferred initialization.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static final RegExp _expensiveServicePattern = RegExp(
    r'(Database|Analytics|Cache|Logger|Http|Api|Network|Storage|Auth)',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'registerSingleton') return;

      // Check arguments for potentially expensive services
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final String argSource = args.first.toSource();

      // Check if registering a potentially expensive service
      if (_expensiveServicePattern.hasMatch(argSource)) {
        reporter.atNode(node, code);
      }
    });
  }
}
