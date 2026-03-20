// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'dart:io' show File;

import 'package:analyzer/dart/ast/ast.dart';

import '../../mode_constants_utils.dart';
import '../../saropa_lint_rule.dart';

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
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config'};

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

  /// Well-known stable domains that are not environment-dependent config.
  static const List<String> _safeUrlDomains = <String>[
    'pub.dev',
    'github.com',
    'dart.dev',
    'flutter.dev',
    'googleapis.com/auth',
  ];

  static bool _isSafeUrl(String value) {
    for (final String domain in _safeUrlDomains) {
      if (value.contains(domain)) return true;
    }
    return false;
  }

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
        if (!_isSafeUrl(value)) {
          reporter.atNode(node);
        }
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
            if (!_isSafeUrl(value)) {
              reporter.atNode(variable);
            }
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
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config'};

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
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config'};

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
    // Skip lint rule/fix source — environment string patterns trigger self-referential FPs
    if (context.isLintPluginSource) return;

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
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config'};

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
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config'};

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
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config'};

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

// =============================================================================
// prefer_semver_version
// =============================================================================

/// Warns when pubspec.yaml version does not follow semantic versioning.
///
/// Version must be major.minor.patch (e.g. 1.0.0, 2.3.1+4, 1.0.0-beta.1).
///
/// **BAD:** `version: 1.0` or `version: 1` or `version: v1.0.0`
///
/// **GOOD:** `version: 1.0.0` or `version: 2.3.1+4`
class PreferSemverVersionRule extends SaropaLintRule {
  PreferSemverVersionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_semver_version',
    '[prefer_semver_version] pubspec.yaml version should follow semantic versioning (major.minor.patch).',
    correctionMessage: 'Use format 1.0.0 or 1.0.0+build (e.g. 2.3.1+4).',
    severity: DiagnosticSeverity.WARNING,
  );

  static final RegExp _semverPattern = RegExp(
    r'^\d+\.\d+\.\d+(\+\d+)?(-[\w.]+)?$',
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final root = ProjectContext.findProjectRoot(context.filePath);
    if (root == null) return;
    final pubspec = File('$root/pubspec.yaml');
    if (!pubspec.existsSync()) return;

    final content = pubspec.readAsStringSync();
    final versionRegex = RegExp(
      '^version:\\s*["\']?([^"\'\\s#]+)',
      multiLine: true,
    );
    final versionMatch = versionRegex.firstMatch(content);
    if (versionMatch == null) return;

    final group1 = versionMatch.group(1);
    if (group1 == null) return;
    final version = group1.trim().toLowerCase();
    final normalized = version.startsWith('v') ? version.substring(1) : version;
    if (version != 'null' && _semverPattern.hasMatch(normalized)) return;

    final path = context.filePath.replaceAll('\\', '/');
    if (!path.contains('/lib/')) return;
    context.addCompilationUnit((CompilationUnit unit) {
      final token = unit.beginToken;
      if (token.isEof) return;
      reporter.atOffset(offset: token.offset, length: token.length);
    });
  }
}

// =============================================================================
// prefer_compile_time_config
// =============================================================================

/// Prefer compile-time configuration (e.g. --dart-define) over runtime-only config.
class PreferCompileTimeConfigRule extends SaropaLintRule {
  PreferCompileTimeConfigRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_compile_time_config',
    '[prefer_compile_time_config] Prefer compile-time configuration '
        '(String.fromEnvironment, --dart-define) for environment-specific '
        'values so they can be tree-shaken and validated at build time.',
    correctionMessage:
        'Use String.fromEnvironment or --dart-define for config where possible.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {}
}

// =============================================================================
// prefer_flavor_configuration
// =============================================================================

/// Prefer flavor-based configuration for multi-environment apps.
class PreferFlavorConfigurationRule extends SaropaLintRule {
  PreferFlavorConfigurationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_flavor_configuration',
    '[prefer_flavor_configuration] Prefer flavor-based configuration '
        '(dev/staging/prod) for environment-specific builds.',
    correctionMessage:
        'Use flavors or build flavors to switch config per build.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {}
}

// =============================================================================
// require_config_validation
// =============================================================================

/// Suggests validating config values after load.
class RequireConfigValidationRule extends SaropaLintRule {
  RequireConfigValidationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_config_validation',
    '[require_config_validation] Config value used without validation.',
    correctionMessage: 'Validate config (null, range) after loading.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {}
}

// =============================================================================
// package_names
// =============================================================================

/// Warns when the pubspec package name does not follow conventions.
///
/// Since: v9.10.0 | Rule version: v1
///
/// Dart package names should be `lowercase_with_underscores` per pub.dev
/// convention. Names with uppercase letters, hyphens, or other characters
/// cause publishing issues and violate ecosystem norms.
///
/// **BAD:** `name: MyPackage` or `name: my-package`
///
/// **GOOD:** `name: my_package`
class PackageNamesRule extends SaropaLintRule {
  PackageNamesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config', 'pubspec'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'package_names',
    '[package_names] Package name in pubspec.yaml does not follow the lowercase_with_underscores convention. Non-conforming names cause issues with pub.dev publishing, make imports harder to read, and violate the Dart ecosystem naming standard that all published packages follow. {v1}',
    correctionMessage:
        'Rename the package to use only lowercase letters, digits, and underscores (e.g. my_package).',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Valid Dart package name: lowercase letters, digits, underscores.
  /// Must start with a lowercase letter.
  static final RegExp _validPackageName = RegExp(r'^[a-z][a-z0-9_]*$');

  /// Broader regex that captures ANY non-empty name value from pubspec,
  /// including non-conforming names like "MyPackage" or "my-package".
  /// ProjectContext.getPackageName() only captures conforming names, so
  /// we must parse the raw value ourselves to detect violations.
  static final RegExp _rawNameField = RegExp(
    r'^name:\s+(\S+)',
    multiLine: true,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final root = ProjectContext.findProjectRoot(context.filePath);
    if (root == null) return;

    // Read raw package name from pubspec — must use broad regex because
    // ProjectContext.getPackageName() only captures already-conforming names.
    final pubspec = File('$root/pubspec.yaml');
    if (!pubspec.existsSync()) return;
    final content = pubspec.readAsStringSync();
    final nameMatch = _rawNameField.firstMatch(content);
    final packageName = nameMatch?.group(1) ?? '';
    if (packageName.isEmpty) return;

    // Valid name — no issue
    if (_validPackageName.hasMatch(packageName)) return;

    // Only report once per project: only for files in lib/
    final path = context.filePath.replaceAll('\\', '/');
    if (!path.contains('/lib/')) return;

    context.addCompilationUnit((CompilationUnit unit) {
      final token = unit.beginToken;
      if (token.isEof) return;
      reporter.atOffset(offset: token.offset, length: token.length);
    });
  }
}

// =============================================================================
// sort_pub_dependencies
// =============================================================================

/// Warns when pubspec dependencies are not sorted alphabetically.
///
/// Since: v9.10.0 | Rule version: v1
///
/// Keeping dependencies sorted in pubspec.yaml makes them easier to
/// scan, reduces merge conflicts, and matches the `dart pub add` behavior.
///
/// **BAD:**
/// ```yaml
/// dependencies:
///   http: ^1.0.0
///   args: ^2.0.0
/// ```
///
/// **GOOD:**
/// ```yaml
/// dependencies:
///   args: ^2.0.0
///   http: ^1.0.0
/// ```
class SortPubDependenciesRule extends SaropaLintRule {
  SortPubDependenciesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config', 'pubspec'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'sort_pub_dependencies',
    '[sort_pub_dependencies] Dependencies in pubspec.yaml are not sorted alphabetically. Unsorted dependency lists are harder to scan visually, increase the chance of merge conflicts when multiple developers add packages, and deviate from the alphabetical order that `dart pub add` uses by default. {v1}',
    correctionMessage:
        'Sort dependencies alphabetically within each section (dependencies, dev_dependencies).',
    severity: DiagnosticSeverity.INFO,
  );

  /// Matches a YAML section header for dependency sections.
  static final RegExp _sectionHeader = RegExp(
    r'^(dependencies|dev_dependencies):',
    multiLine: true,
  );

  /// Matches an indented dependency entry (2-space indent, name followed by :).
  /// Known limitation: relies on standard 2-space YAML indentation. Nested
  /// sub-keys (git:, hosted:, path:) use 4+ spaces and won't match. Unusual
  /// inline map structures at the 2-space level could produce false positives,
  /// but this is rare in practice since pubspec dependencies use flat key: value.
  static final RegExp _depEntry = RegExp(r'^  (\w[\w-]*):');

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final root = ProjectContext.findProjectRoot(context.filePath);
    if (root == null) return;

    final pubspec = File('$root/pubspec.yaml');
    if (!pubspec.existsSync()) return;

    final content = pubspec.readAsStringSync();
    if (!_hasSortingIssue(content)) return;

    // Only report once per project: only for files in lib/
    final path = context.filePath.replaceAll('\\', '/');
    if (!path.contains('/lib/')) return;

    context.addCompilationUnit((CompilationUnit unit) {
      final token = unit.beginToken;
      if (token.isEof) return;
      reporter.atOffset(offset: token.offset, length: token.length);
    });
  }

  /// Checks if any dependency section has unsorted entries.
  bool _hasSortingIssue(String content) {
    final lines = content.split('\n');
    bool inDepSection = false;
    final List<String> currentDeps = [];

    for (final line in lines) {
      // Check for section headers
      if (_sectionHeader.hasMatch(line)) {
        // Check previous section before starting new one
        if (_isUnsorted(currentDeps)) return true;
        currentDeps.clear();
        inDepSection = true;
        continue;
      }

      // Non-indented line ends the current section
      if (inDepSection && line.isNotEmpty && !line.startsWith(' ')) {
        if (_isUnsorted(currentDeps)) return true;
        currentDeps.clear();
        inDepSection = false;
        continue;
      }

      if (inDepSection) {
        final match = _depEntry.firstMatch(line);
        if (match != null) {
          currentDeps.add(match.group(1)!);
        }
      }
    }

    // Check the last section
    return _isUnsorted(currentDeps);
  }

  bool _isUnsorted(List<String> deps) {
    if (deps.length < 2) return false;
    for (int i = 1; i < deps.length; i++) {
      if (deps[i].compareTo(deps[i - 1]) < 0) return true;
    }
    return false;
  }
}

// =============================================================================
// secure_pubspec_urls
// =============================================================================

/// Warns when pubspec.yaml contains insecure HTTP URLs.
///
/// Since: v9.10.0 | Rule version: v1
///
/// Dependency sources in pubspec.yaml should use HTTPS for integrity and
/// security. Plain HTTP URLs are vulnerable to man-in-the-middle attacks
/// that could inject malicious code into dependencies.
///
/// **BAD:**
/// ```yaml
/// dependencies:
///   my_pkg:
///     git:
///       url: http://github.com/org/repo.git
/// ```
///
/// **GOOD:**
/// ```yaml
/// dependencies:
///   my_pkg:
///     git:
///       url: https://github.com/org/repo.git
/// ```
class SecurePubspecUrlsRule extends SaropaLintRule {
  SecurePubspecUrlsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  /// Security-sensitive — insecure dependency URLs enable MITM attacks.
  /// Classified as hotspot: http:// in homepage/description is benign,
  /// but in dependency sources it's a genuine security risk.
  @override
  RuleType? get ruleType => RuleType.securityHotspot;

  @override
  Set<String> get tags => const {'security', 'config', 'pubspec'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'secure_pubspec_urls',
    '[secure_pubspec_urls] Insecure URL (http:// or git://) found in pubspec.yaml dependency source. Plain HTTP and unencrypted git:// URLs are vulnerable to man-in-the-middle attacks that could inject malicious code into your dependencies. Always use https:// for dependency URLs to ensure integrity and authenticity. {v1}',
    correctionMessage:
        'Replace http:// with https:// in the dependency URL. For git dependencies, use https://github.com/... instead of git://github.com/...',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Matches insecure URLs: http:// or git:// (not https://)
  static final RegExp _insecureUrl = RegExp(
    r'(?:^|\s)(http://|git://)',
    multiLine: true,
  );

  /// Matches YAML comment lines to exclude them.
  static final RegExp _commentLine = RegExp(r'^\s*#');

  /// Section headers for dependency-related YAML blocks.
  static final RegExp _depSectionHeader = RegExp(
    r'^(dependencies|dev_dependencies|dependency_overrides):',
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final root = ProjectContext.findProjectRoot(context.filePath);
    if (root == null) return;

    final pubspec = File('$root/pubspec.yaml');
    if (!pubspec.existsSync()) return;

    final content = pubspec.readAsStringSync();

    // Only check inside dependency sections (not homepage, description, etc.)
    // to avoid false positives on non-dependency URLs.
    final lines = content.split('\n');
    bool inDepSection = false;
    bool foundInsecure = false;
    for (final line in lines) {
      // Track whether we're inside a dependency section
      if (_depSectionHeader.hasMatch(line)) {
        inDepSection = true;
        continue;
      }
      // Non-indented, non-empty line ends the current section
      if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('#')) {
        inDepSection = false;
        continue;
      }
      if (!inDepSection) continue;
      if (_commentLine.hasMatch(line)) continue;
      // Strip inline comments before checking for URLs
      final beforeComment = line.contains('#') ? line.split('#').first : line;
      if (_insecureUrl.hasMatch(beforeComment)) {
        foundInsecure = true;
        break;
      }
    }

    if (!foundInsecure) return;

    // Only report once per project: only for files in lib/
    final path = context.filePath.replaceAll('\\', '/');
    if (!path.contains('/lib/')) return;

    context.addCompilationUnit((CompilationUnit unit) {
      final token = unit.beginToken;
      if (token.isEof) return;
      reporter.atOffset(offset: token.offset, length: token.length);
    });
  }
}

// =============================================================================
// depend_on_referenced_packages
// =============================================================================

/// Warns when an imported package is not listed in pubspec dependencies.
///
/// Since: v9.10.0 | Rule version: v1
///
/// Every `package:foo/...` import must correspond to a dependency declared
/// in pubspec.yaml. Missing dependencies cause resolution failures and
/// make the project non-portable.
///
/// **BAD:**
/// ```dart
/// import 'package:http/http.dart';  // http not in pubspec.yaml
/// ```
///
/// **GOOD:**
/// ```dart
/// import 'package:http/http.dart';  // http listed in dependencies
/// ```
class DependOnReferencedPackagesRule extends SaropaLintRule {
  DependOnReferencedPackagesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config', 'reliability'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'depend_on_referenced_packages',
    '[depend_on_referenced_packages] Imported package is not listed in pubspec.yaml dependencies. Using a package without declaring the dependency means builds rely on transitive resolution, which can break unexpectedly when other packages update their own dependencies. Every package import must have a corresponding entry in pubspec.yaml. {v1}',
    correctionMessage:
        'Add the missing package to dependencies (or dev_dependencies for test files) in pubspec.yaml.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Extracts the package name from a package: URI.
  /// e.g. 'package:http/http.dart' -> 'http'
  static final RegExp _packageUri = RegExp(r'^package:(\w+)/');

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Resolve project root and own package name once per file (not per
    // import directive) to avoid N directory traversals for N imports.
    final root = ProjectContext.findProjectRoot(context.filePath);
    final ownName = root != null ? ProjectContext.getPackageName(root) : '';

    context.addImportDirective((ImportDirective node) {
      final String? uri = node.uri.stringValue;
      if (uri == null) return;

      // Only check package: imports (skip dart: and relative)
      if (!uri.startsWith('package:')) return;

      final match = _packageUri.firstMatch(uri);
      if (match == null) return;

      final String packageName = match.group(1)!;

      // Skip the project's own package name
      if (packageName == ownName) return;

      // Check if the package is in pubspec dependencies
      if (ProjectContext.hasDependency(context.filePath, packageName)) return;

      // Package not found in dependencies — report at the import directive
      reporter.atNode(node);
    });
  }
}
