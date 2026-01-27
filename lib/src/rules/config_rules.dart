// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../mode_constants_utils.dart';
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
        '[avoid_hardcoded_config] Hardcoded configuration makes code inflexible and deployment-specific.',
    correctionMessage:
        'Use String.fromEnvironment, dotenv, or a config service for environment-specific values.',
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

/// Detects hardcoded configuration values in test files at reduced severity.
///
/// Test files routinely contain hardcoded URLs, ports, and paths as test
/// fixture data. This variant of [AvoidHardcodedConfigRule] surfaces these
/// at INFO level for awareness without blocking, since the advice to
/// externalize configuration does not apply to test inputs.
///
/// `[HEURISTIC]` - Uses pattern matching to detect configuration values.
///
/// **BAD:**
/// ```dart
/// // test/utils_test.dart
/// final url = 'https://api.example.com/v1/users'; // INFO
/// ```
///
/// **GOOD:**
/// ```dart
/// // test/utils_test.dart
/// const testUrl = 'https://api.example.com/v1/users'; // const preferred
/// ```
class AvoidHardcodedConfigTestRule extends SaropaLintRule {
  const AvoidHardcodedConfigTestRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => const <FileType>{FileType.test};

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_config_test',
    problemMessage:
        '[avoid_hardcoded_config_test] Hardcoded configuration detected in test file. '
        'Consider using a const or shared test helper.',
    correctionMessage:
        'Extract to a const or shared test fixture if reused across tests.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      if (_isHardcodedConfig(node)) {
        reporter.atNode(node, code);
      }
    });

    context.registry
        .addTopLevelVariableDeclaration((TopLevelVariableDeclaration node) {
      for (final VariableDeclaration variable in node.variables.variables) {
        if (_isHardcodedConfig(variable)) {
          reporter.atNode(variable, code);
        }
      }
    });
  }

  static bool _isHardcodedConfig(VariableDeclaration node) {
    final Expression? initializer = node.initializer;
    if (initializer is! StringLiteral) return false;

    final String? value = initializer.stringValue;
    if (value == null || value.isEmpty) return false;

    final String varName = node.name.lexeme;
    if (!AvoidHardcodedConfigRule._configNamePattern.hasMatch(varName)) {
      return false;
    }

    return AvoidHardcodedConfigRule._urlPattern.hasMatch(value) ||
        AvoidHardcodedConfigRule._keyPattern.hasMatch(value);
  }
}

/// Warns when production and development config are mixed in the same class.
///
/// `[HEURISTIC]` - Uses pattern matching to detect prod/dev indicators.
///
/// Mixing production URLs/keys with development settings causes
/// accidental production data corruption or security leaks. This rule
/// detects classes with both production indicators (prod, production,
/// live, release) and development indicators (dev, debug, staging, test,
/// local) in field names or values.
///
/// Fields using Flutter's mode constants (`kReleaseMode`, `kDebugMode`,
/// `kProfileMode`) are considered "properly conditional" and excluded
/// from detection, since they intentionally handle both environments.
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
///
/// **GOOD:** (enum with mode-conditional assignment)
/// ```dart
/// enum AppMode { release, profile, debug }
///
/// class AppModeSettings {
///   // Uses kDebugMode - properly conditional, not flagged
///   static const AppMode mode = kDebugMode
///       ? AppMode.debug
///       : (kProfileMode ? AppMode.profile : AppMode.release);
/// }
/// ```
class AvoidMixedEnvironmentsRule extends SaropaLintRule {
  const AvoidMixedEnvironmentsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  // Performance: Only run on files with class declarations
  @override
  bool get requiresClassDeclaration => true;

  static const LintCode _code = LintCode(
    name: 'avoid_mixed_environments',
    problemMessage:
        '[avoid_mixed_environments] Mixing production and development configuration in your codebase creates serious security vulnerabilities. Debug APIs may expose sensitive data, development endpoints can corrupt production databases, and credentials may leak to unauthorized users. This can result in data breaches, compliance violations, and loss of user trust. Environment-specific configuration must be strictly separated and managed.',
    correctionMessage:
        'Use conditional configuration based on kReleaseMode, environment variables, or build flavors to separate production and development settings. Audit your codebase for hardcoded endpoints, credentials, or debug flags and refactor to ensure strict separation. Document environment management practices for your team and enforce them in code reviews.',
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

            // Skip fields that use Flutter's mode constants - these are
            // properly conditional and should not trigger mixed environment
            // warnings even if they contain both prod and dev enum values
            // (e.g., `kDebugMode ? AppModeEnum.debug : AppModeEnum.release`)
            final bool isProperlyConditional = usesFlutterModeConstants(source);

            // Check for production indicators (skip if properly conditional)
            if (!isProperlyConditional &&
                (_prodPattern.hasMatch(source) ||
                    _prodPattern.hasMatch(varName))) {
              if (!hasProdIndicator) {
                hasProdIndicator = true;
                firstProdMember = member;
              }
            }

            // Check for development indicators (skip if properly conditional)
            if (!isProperlyConditional &&
                (_devPattern.hasMatch(source) ||
                    _devPattern.hasMatch(varName))) {
              hasDevIndicator = true;
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
