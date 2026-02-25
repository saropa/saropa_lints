// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';

import '../mode_constants_utils.dart';
import '../saropa_lint_rule.dart';

// =============================================================================
// Configuration & Environment Rules (v4.1.6)
// =============================================================================

/// Warns when hardcoded configuration values are detected.
///
/// Since: v4.1.6 | Updated: v4.13.0 | Rule version: v4
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
  AvoidHardcodedConfigRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_hardcoded_config',
    '[avoid_hardcoded_config] Hardcoded configuration value detected. Embedding URLs, ports, API keys, or feature flags directly in source code makes the app inflexible across environments (dev, staging, production) and forces a rebuild for every configuration change, increasing deployment risk. {v4}',
    correctionMessage:
        'Use String.fromEnvironment, dotenv, or a config service for environment-specific values.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addVariableDeclaration((VariableDeclaration node) {
      final Expression? initializer = node.initializer;
      if (initializer is! StringLiteral) return;

      final String? value = initializer.stringValue;
      if (value == null || value.isEmpty) return;

      final String varName = node.name.lexeme;

      // Check if variable name suggests config
      if (!_configNamePattern.hasMatch(varName)) return;

      // Check if value looks like a hardcoded config
      if (_urlPattern.hasMatch(value) || _keyPattern.hasMatch(value)) {
        reporter.atNode(node);
      }
    });

    // Also check top-level constants
    context.addTopLevelVariableDeclaration((TopLevelVariableDeclaration node) {
      for (final VariableDeclaration variable in node.variables.variables) {
        final Expression? initializer = variable.initializer;
        if (initializer is! StringLiteral) continue;

        final String? value = initializer.stringValue;
        if (value == null || value.isEmpty) continue;

        final String varName = variable.name.lexeme;

        // Check for URL or key patterns in config-named variables
        if (_configNamePattern.hasMatch(varName)) {
          if (_urlPattern.hasMatch(value) || _keyPattern.hasMatch(value)) {
            reporter.atNode(variable);
          }
        }
      }
    });
  }
}

/// Detects hardcoded configuration values in test files at reduced severity.
///
/// Since: v4.8.2 | Updated: v4.13.0 | Rule version: v2
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
  AvoidHardcodedConfigTestRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => const <FileType>{FileType.test};

  static const LintCode _code = LintCode(
    'avoid_hardcoded_config_test',
    '[avoid_hardcoded_config_test] Hardcoded configuration detected in test file. '
        'Consider using a const or shared test helper. {v2}',
    correctionMessage:
        'Extract to a const or shared test fixture if reused across tests.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addVariableDeclaration((VariableDeclaration node) {
      if (_isHardcodedConfig(node)) {
        reporter.atNode(node);
      }
    });

    context.addTopLevelVariableDeclaration((TopLevelVariableDeclaration node) {
      for (final VariableDeclaration variable in node.variables.variables) {
        if (_isHardcodedConfig(variable)) {
          reporter.atNode(variable);
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
/// Since: v4.1.6 | Updated: v4.13.0 | Rule version: v4
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
  AvoidMixedEnvironmentsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  // Performance: Only run on files with class declarations
  @override
  bool get requiresClassDeclaration => true;

  static const LintCode _code = LintCode(
    'avoid_mixed_environments',
    '[avoid_mixed_environments] Mixing production and development configuration in your codebase creates serious security vulnerabilities. Debug APIs may expose sensitive data, development endpoints can corrupt production databases, and credentials may leak to unauthorized users. This can result in data breaches, compliance violations, and loss of user trust. Environment-specific configuration must be strictly separated and managed. {v4}',
    correctionMessage:
        'Use conditional configuration based on kReleaseMode, environment variables, or build flavors to separate production and development settings. Audit your codebase for hardcoded endpoints, credentials, or debug flags and refactor to ensure strict separation. Document environment management practices for your team and enforce them in code reviews.',
    severity: DiagnosticSeverity.ERROR,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
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
        reporter.atNode(firstProdMember);
      }
    });
  }
}

/// Warns when feature flags are accessed with raw string literal keys.
///
/// Since: v4.14.0 | Rule version: v1
///
/// GitHub: https://github.com/saropa/saropa_lints/issues/21
///
/// `[HEURISTIC]` - Uses a two-tier matching approach:
/// 1. Flag-specific methods always trigger with string literal args.
/// 2. Generic accessors only trigger on flag-related targets.
///
/// **BAD:**
/// ```dart
/// final enabled = featureFlags.isEnabled('new_checkout_flow');
/// ```
///
/// **GOOD:**
/// ```dart
/// final enabled = featureFlags.isEnabled(FeatureFlag.newCheckoutFlow);
/// ```
class RequireFeatureFlagTypeSafetyRule extends SaropaLintRule {
  RequireFeatureFlagTypeSafetyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_feature_flag_type_safety',
    '[require_feature_flag_type_safety] Feature flag accessed with a '
        'raw string literal key. String-based lookups are error-prone: '
        'typos compile successfully but fail silently at runtime, renames '
        'require a fragile codebase-wide search-and-replace, and there '
        'is no compile-time guarantee the flag name exists. {v1}',
    correctionMessage:
        'Define flag keys as typed constants (enum values or static '
        'const fields) and reference those instead of string literals.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Unambiguous flag methods - still require a flag-like receiver to
  /// avoid false positives on generic `isEnabled('push')` calls.
  static const Set<String> _flagSpecificMethods = <String>{
    'isFeatureEnabled',
    'getFeatureFlag',
    'getFlag',
    'checkFlag',
    'evaluateFlag',
  };

  /// Ambiguous methods that could appear on many classes - require both
  /// a flag-like receiver AND a string literal argument.
  static const Set<String> _genericAccessors = <String>{
    'isEnabled',
    'getBool',
    'getString',
    'getInt',
    'getDouble',
    'getValue',
  };

  /// Receiver patterns that indicate a feature flag context.
  static final RegExp _flagTargetPattern = RegExp(
    r'(featureFlag|featureToggle|featureSwitch|abTest|experiment|remoteConfig|FirebaseRemoteConfig|launchDarkly|featureClient|flagsmith|unleash|configCat)',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (_flagSpecificMethods.contains(methodName)) {
        if (!_hasStringLiteralFirstArg(node)) return;
        // Unambiguous names like getFeatureFlag always trigger
        reporter.atNode(node.methodName, code);
        return;
      }

      if (_genericAccessors.contains(methodName)) {
        // Ambiguous names require a flag-related receiver
        final Expression? target = node.target;
        if (target == null) return;
        if (!_flagTargetPattern.hasMatch(target.toSource())) return;
        if (!_hasStringLiteralFirstArg(node)) return;
        reporter.atNode(node.methodName, code);
      }
    });
  }

  static bool _hasStringLiteralFirstArg(MethodInvocation node) {
    if (node.argumentList.arguments.isEmpty) return false;
    return node.argumentList.arguments.first is StringLiteral;
  }
}

// =============================================================================
// avoid_string_env_parsing
// =============================================================================

/// Warns when `fromEnvironment()` is called without a `defaultValue`.
///
/// Since: v5.1.0 | Rule version: v1
///
/// Alias: env_no_default, missing_env_default
///
/// `String.fromEnvironment`, `int.fromEnvironment`, and
/// `bool.fromEnvironment` silently return the type default (empty string,
/// 0, or false) when the variable is not set via `--dart-define`. Without
/// an explicit `defaultValue`, missing configuration is invisible at
/// runtime, causing hard-to-debug failures across build environments.
///
/// **BAD:**
/// ```dart
/// const apiUrl = String.fromEnvironment('API_URL');
/// const maxRetries = int.fromEnvironment('MAX_RETRIES');
/// const enableLogs = bool.fromEnvironment('ENABLE_LOGS');
/// ```
///
/// **GOOD:**
/// ```dart
/// const apiUrl = String.fromEnvironment(
///   'API_URL',
///   defaultValue: 'https://api.example.com',
/// );
/// const maxRetries = int.fromEnvironment(
///   'MAX_RETRIES',
///   defaultValue: 3,
/// );
/// const enableLogs = bool.fromEnvironment(
///   'ENABLE_LOGS',
///   defaultValue: false,
/// );
/// ```
class AvoidStringEnvParsingRule extends SaropaLintRule {
  AvoidStringEnvParsingRule() : super(code: _code);

  /// Missing defaults cause subtle production bugs.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.trivial;

  static const LintCode _code = LintCode(
    'avoid_string_env_parsing',
    '[avoid_string_env_parsing] fromEnvironment() called without a '
        'defaultValue parameter. Environment variables set via --dart-define '
        'silently return the type default (empty string, 0, or false) when '
        'not provided. This makes missing configuration invisible at runtime '
        'and causes hard-to-debug failures across build environments. {v1}',
    correctionMessage:
        'Add a defaultValue parameter to provide a safe fallback '
        'when the variable is not defined.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _envTypes = <String>{'String', 'int', 'bool'};

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'fromEnvironment') return;

      // Check if target is String, int, or bool
      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (!_envTypes.contains(target.name)) return;

      // Check for defaultValue named argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'defaultValue') {
          return;
        }
      }

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// avoid_platform_specific_imports
// =============================================================================

/// Warns when `dart:io` is imported in code that should be platform-agnostic.
///
/// Since: v5.1.0 | Rule version: v1
///
/// Alias: no_dart_io, platform_agnostic_imports
///
/// `dart:io` is unavailable on web. Importing it in shared code causes
/// compile failures when targeting web. Use conditional imports or
/// `package:universal_io` for cross-platform code.
///
/// **BAD:**
/// ```dart
/// import 'dart:io';
///
/// Future<String> readFile(String path) async {
///   return File(path).readAsStringSync();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// import 'package:universal_io/io.dart';
///
/// // Or use conditional imports:
/// import 'stub_io.dart'
///     if (dart.library.io) 'dart:io';
/// ```
class AvoidPlatformSpecificImportsRule extends SaropaLintRule {
  AvoidPlatformSpecificImportsRule() : super(code: _code);

  /// Platform incompatibilities block entire build targets.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_platform_specific_imports',
    '[avoid_platform_specific_imports] dart:io import detected in shared '
        'code. dart:io is unavailable on web and will cause compile failures '
        'when targeting browser platforms. Shared library code and packages '
        'that support multiple platforms should use conditional imports or '
        'package:universal_io to remain platform-agnostic. {v1}',
    correctionMessage:
        'Use conditional imports or package:universal_io instead of dart:io.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Path segments that indicate platform-specific directories.
  /// Slash-wrapped entries match directory names; slash-prefixed suffix
  /// entries match file/directory name endings (e.g. `widget_android/`).
  static const Set<String> _platformDirs = <String>{
    '/native/',
    '/platform/',
    '/android/',
    '/ios/',
    '/macos/',
    '/windows/',
    '/linux/',
    '/_android/',
    '/_ios/',
    '/_macos/',
    '/_windows/',
    '/_linux/',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Skip platform-specific directories
    final String path = context.filePath.replaceAll('\\', '/');
    for (final String dir in _platformDirs) {
      if (path.contains(dir)) return;
    }

    context.addImportDirective((ImportDirective node) {
      final String? uri = node.uri.stringValue;
      if (uri != 'dart:io') return;

      // Conditional imports are the correct pattern — don't flag them
      if (node.configurations.isNotEmpty) return;

      reporter.atNode(node);
    });
  }
}
