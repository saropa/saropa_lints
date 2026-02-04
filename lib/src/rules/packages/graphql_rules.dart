import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart';

/// Warns when GraphQL queries are written as raw string literals.
///
/// Raw GraphQL string queries are error-prone, lack type safety, and
/// cannot be validated at compile time. Use code generation tools like
/// graphql_codegen or artemis to generate type-safe query objects.
///
/// **BAD:**
/// ```dart
/// final query = gql('''
///   query GetUsers {
///     users {
///       id
///       name
///     }
///   }
/// ''');
///
/// // Or using graphql_flutter
/// final result = await client.query(QueryOptions(
///   document: gql('{ users { id name } }'),
/// ));
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use generated query classes from graphql_codegen
/// final result = await client.query(GetUsersQuery().options);
///
/// // Or use .graphql files with code generation
/// import 'get_users.graphql.dart';
/// final result = await client.query(Options$Query$GetUsers());
/// ```
class AvoidGraphqlStringQueriesRule extends SaropaLintRule {
  const AvoidGraphqlStringQueriesRule() : super(code: _code);

  /// Medium impact - maintainability and type safety issue.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_graphql_string_queries',
    problemMessage:
        '[avoid_graphql_string_queries] Raw GraphQL string queries lack type safety and compile-time validation.',
    correctionMessage:
        'Use graphql_codegen or artemis to generate type-safe query classes from .graphql files.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check for gql() function calls with string literals
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for gql() or parseString() calls (common GraphQL parsing functions)
      if (methodName != 'gql' && methodName != 'parseString') return;

      // Check if the argument is a string literal
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression firstArg = args.first;
      if (firstArg is NamedExpression) {
        // Skip named arguments
        return;
      }

      // Check if it's a string literal (simple, multiline, or adjacent)
      if (_isStringLiteral(firstArg)) {
        reporter.atNode(node, code);
      }
    });

    // Also check for InstanceCreationExpression with document parameter
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;

      // Check for common GraphQL options classes
      if (typeName != 'QueryOptions' &&
          typeName != 'MutationOptions' &&
          typeName != 'SubscriptionOptions' &&
          typeName != 'WatchQueryOptions') {
        return;
      }

      // Check for document parameter with gql() call
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'document') {
          final Expression value = arg.expression;
          if (value is MethodInvocation) {
            final String methodName = value.methodName.name;
            if (methodName == 'gql' || methodName == 'parseString') {
              // Check if gql() has a string literal
              final NodeList<Expression> gqlArgs = value.argumentList.arguments;
              if (gqlArgs.isNotEmpty && _isStringLiteral(gqlArgs.first)) {
                reporter.atNode(arg, code);
              }
            }
          }
        }
      }
    });
  }

  /// Check if an expression is a string literal.
  bool _isStringLiteral(Expression expr) {
    if (expr is SimpleStringLiteral) return true;
    if (expr is AdjacentStrings) return true;
    if (expr is StringInterpolation) return true;
    return false;
  }
}
