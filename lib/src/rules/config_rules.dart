// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

// =============================================================================
// Configuration & Environment Rules (v4.1.6)
// =============================================================================

/// Warns when hardcoded configuration values are detected.
///
/// Hardcoded URLs, API keys, and configuration values make code
/// difficult to maintain and deploy to different environments.
///
/// `[HEURISTIC]` - Uses pattern matching to detect configuration values.
///
/// **BAD:**
/// ```dart
/// const apiUrl = 'https://api.example.com/v1';
/// const apiKey = 'sk_live_abc123';
/// final baseUrl = 'http://localhost:3000';
/// ```
///
/// **GOOD:**
/// ```dart
/// final apiUrl = const String.fromEnvironment('API_URL');
/// final apiKey = dotenv.env['API_KEY'];
/// final baseUrl = AppConfig.instance.baseUrl;
/// ```
class AvoidHardcodedConfigRule extends SaropaLintRule {
  const AvoidHardcodedConfigRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_config',
    problemMessage:
        '[avoid_hardcoded_config] Hardcoded configuration detected. Use environment variables.',
    correctionMessage:
        'Move to String.fromEnvironment, dotenv, or a config service.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  // Patterns that suggest hardcoded config
  static final RegExp _urlPattern = RegExp(
    r'^https?://[a-z0-9]',
    caseSensitive: false,
  );

  static final RegExp _keyPattern = RegExp(
    r'^(sk_|pk_|api_|key_|secret_|token_)[a-zA-Z0-9]+$',
    caseSensitive: false,
  );

  // Variable name patterns that suggest config
  static final RegExp _configNamePattern = RegExp(
    r'(api|base|host|server|endpoint|url|key|secret|token|password|credential)',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      final Expression? initializer = node.initializer;
      if (initializer is! StringLiteral) return;

      final String? value = initializer.stringValue;
      if (value == null || value.isEmpty) return;

      final String varName = node.name.lexeme;

      // Check if variable name suggests config
      if (!_configNamePattern.hasMatch(varName)) return;

      // Check if value looks like a hardcoded config
      if (_urlPattern.hasMatch(value) || _keyPattern.hasMatch(value)) {
        reporter.atNode(node, code);
      }
    });

    // Also check top-level constants
    context.registry
        .addTopLevelVariableDeclaration((TopLevelVariableDeclaration node) {
      for (final VariableDeclaration variable in node.variables.variables) {
        final Expression? initializer = variable.initializer;
        if (initializer is! StringLiteral) continue;

        final String? value = initializer.stringValue;
        if (value == null || value.isEmpty) continue;

        final String varName = variable.name.lexeme;

        // Check for URL or key patterns in config-named variables
        if (_configNamePattern.hasMatch(varName)) {
          if (_urlPattern.hasMatch(value) || _keyPattern.hasMatch(value)) {
            reporter.atNode(variable, code);
          }
        }
      }
    });
  }
}

/// Warns when production and development config are mixed.
///
/// Mixing production URLs/keys with development settings causes
/// accidental production data corruption or security leaks.
///
/// **BAD:**
/// ```dart
/// class Config {
///   static const apiUrl = 'https://api.prod.example.com'; // Production!
///   static const debug = true; // But debug mode!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class Config {
///   static const apiUrl = kReleaseMode
///       ? 'https://api.prod.example.com'
///       : 'https://api.dev.example.com';
///   static const debug = !kReleaseMode;
/// }
/// ```
class AvoidMixedEnvironmentsRule extends SaropaLintRule {
  const AvoidMixedEnvironmentsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_mixed_environments',
    problemMessage:
        '[avoid_mixed_environments] Mixed production/development configuration detected.',
    correctionMessage:
        'Use conditional config based on kReleaseMode or environment.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static final RegExp _prodPattern = RegExp(
    r'(prod|production|live|release)',
    caseSensitive: false,
  );

  static final RegExp _devPattern = RegExp(
    r'(dev|development|debug|staging|test|local|localhost)',
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

      // Only check config-related classes
      if (!className.contains('config') &&
          !className.contains('environment') &&
          !className.contains('settings')) {
        return;
      }

      bool hasProdIndicator = false;
      bool hasDevIndicator = false;
      ClassMember? firstProdMember;

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            final Expression? init = variable.initializer;
            if (init == null) continue;

            final String source = init.toSource();
            final String varName = variable.name.lexeme;

            // Check for production indicators
            if (_prodPattern.hasMatch(source) ||
                _prodPattern.hasMatch(varName)) {
              if (!hasProdIndicator) {
                hasProdIndicator = true;
                firstProdMember = member;
              }
            }

            // Check for development indicators
            if (_devPattern.hasMatch(source) || _devPattern.hasMatch(varName)) {
              // Exclude kReleaseMode/kDebugMode usage (proper conditional)
              if (!source.contains('kReleaseMode') &&
                  !source.contains('kDebugMode') &&
                  !source.contains('kProfileMode')) {
                hasDevIndicator = true;
              }
            }
          }
        }
      }

      // If both prod and dev indicators found, report
      if (hasProdIndicator && hasDevIndicator && firstProdMember != null) {
        reporter.atNode(firstProdMember, code);
      }
    });
  }
}
