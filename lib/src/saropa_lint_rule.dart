// ignore_for_file: always_specify_types, depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'ignore_utils.dart';

/// Base class for Saropa lint rules with enhanced features:
///
/// 1. **Hyphenated ignore comments**: Supports both `// ignore: no_empty_block`
///    and `// ignore: no-empty-block` formats.
///
/// 2. **Context-aware suppression**: Automatically skip generated files,
///    test files, or example files by overriding the skip* getters.
///
/// 3. **Documentation URLs**: Auto-generates documentation links for rules.
///
/// 4. **Severity overrides**: Supports project-level severity configuration.
///
/// Usage:
/// ```dart
/// class MyRule extends SaropaLintRule {
///   const MyRule() : super(code: _code);
///
///   static const LintCode _code = LintCode(
///     name: 'my_rule_name',
///     // ...
///   );
///
///   // Optional: skip generated files (default: true)
///   @override
///   bool get skipGeneratedCode => true;
///
///   @override
///   void runWithReporter(
///     CustomLintResolver resolver,
///     SaropaDiagnosticReporter reporter,
///     CustomLintContext context,
///   ) {
///     // Use reporter.atNode() as usual
///   }
/// }
/// ```
abstract class SaropaLintRule extends DartLintRule {
  const SaropaLintRule({required super.code});

  // ============================================================
  // Context-Aware Auto-Suppression (#2)
  // ============================================================

  /// Whether to skip generated files (*.g.dart, *.freezed.dart, *.gen.dart).
  ///
  /// Default: `true` - Generated code can't be fixed manually.
  bool get skipGeneratedCode => true;

  /// Whether to skip test files (*_test.dart, test/**).
  ///
  /// Default: `false` - Most rules should run in tests too.
  /// Override to `true` for rules that don't apply to test code.
  bool get skipTestFiles => false;

  /// Whether to skip example files (example/**).
  ///
  /// Default: `false` - Examples should generally follow best practices.
  /// Override to `true` for strict rules that may hinder documentation.
  bool get skipExampleFiles => false;

  /// Whether to skip fixture files (fixture/**, fixtures/**).
  ///
  /// Default: `true` - Fixture files often contain intentionally bad code.
  bool get skipFixtureFiles => true;

  /// Check if a file path should be skipped based on context settings.
  bool _shouldSkipFile(String path) {
    // Normalize path separators
    final normalizedPath = path.replaceAll('\\', '/');

    // Check generated code patterns
    if (skipGeneratedCode) {
      if (normalizedPath.endsWith('.g.dart') ||
          normalizedPath.endsWith('.freezed.dart') ||
          normalizedPath.endsWith('.gen.dart') ||
          normalizedPath.endsWith('.gr.dart') ||
          normalizedPath.endsWith('.config.dart') ||
          normalizedPath.endsWith('.mocks.dart') ||
          normalizedPath.contains('/generated/')) {
        return true;
      }
    }

    // Check test files
    if (skipTestFiles) {
      if (normalizedPath.endsWith('_test.dart') ||
          normalizedPath.contains('/test/') ||
          normalizedPath.contains('/test_driver/') ||
          normalizedPath.contains('/integration_test/')) {
        return true;
      }
    }

    // Check example files
    if (skipExampleFiles) {
      if (normalizedPath.contains('/example/') ||
          normalizedPath.contains('/examples/')) {
        return true;
      }
    }

    // Check fixture files
    if (skipFixtureFiles) {
      if (normalizedPath.contains('/fixture/') ||
          normalizedPath.contains('/fixtures/') ||
          normalizedPath.contains('_fixture.dart')) {
        return true;
      }
    }

    return false;
  }

  // ============================================================
  // Documentation URL Generation (#4)
  // ============================================================

  /// Base URL for rule documentation.
  ///
  /// Override to customize the documentation host.
  static const String documentationBaseUrl =
      'https://pub.dev/packages/saropa_lints';

  /// Returns the documentation URL for this rule.
  ///
  /// Format: `https://pub.dev/packages/saropa_lints#rule_name`
  String get documentationUrl => '$documentationBaseUrl#${code.name}';

  /// Returns the rule name in hyphenated format for display.
  ///
  /// Example: `no_empty_block` → `no-empty-block`
  String get hyphenatedName => code.name.replaceAll('_', '-');

  // ============================================================
  // Severity Override Support (#5)
  // ============================================================

  /// Global severity overrides map.
  ///
  /// Set this to override severities at the project level:
  /// ```dart
  /// SaropaLintRule.severityOverrides = {
  ///   'avoid_print': DiagnosticSeverity.ERROR,
  ///   'prefer_const': DiagnosticSeverity.INFO,
  /// };
  /// ```
  static Map<String, DiagnosticSeverity>? severityOverrides;

  /// Rules that are completely disabled via severity overrides.
  ///
  /// Set rule name to null in [severityOverrides] to disable.
  static Set<String>? disabledRules;

  /// Check if this rule is disabled via configuration.
  bool get isDisabled => disabledRules?.contains(code.name) ?? false;

  /// Get the effective severity for this rule, considering overrides.
  DiagnosticSeverity? get effectiveSeverity =>
      severityOverrides?[code.name] ?? code.errorSeverity;

  // ============================================================
  // Core Implementation
  // ============================================================

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check if rule is disabled
    if (isDisabled) return;

    // Check if file should be skipped based on context
    final path = resolver.source.fullName;
    if (_shouldSkipFile(path)) return;

    // Create wrapped reporter with severity override support
    final wrappedReporter = SaropaDiagnosticReporter(
      reporter,
      code.name,
      severityOverride: severityOverrides?[code.name],
    );

    runWithReporter(resolver, wrappedReporter, context);
  }

  /// Override this method instead of [run] to implement your lint rule.
  ///
  /// The [reporter] automatically handles:
  /// - Hyphenated ignore comment aliases
  /// - Severity overrides
  /// - Context-aware suppression (files are pre-filtered)
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  );
}

/// A diagnostic reporter that checks for hyphenated ignore comments
/// and supports severity overrides.
///
/// Wraps a [DiagnosticReporter] and intercepts [atNode] calls to check
/// for ignore comments in both underscore and hyphen formats.
class SaropaDiagnosticReporter {
  SaropaDiagnosticReporter(
    this._delegate,
    this._ruleName, {
    this.severityOverride,
  });

  final DiagnosticReporter _delegate;
  final String _ruleName;

  /// Optional severity override for this rule.
  final DiagnosticSeverity? severityOverride;

  /// Creates a new LintCode with overridden severity if configured.
  LintCode _applyOverride(LintCode code) {
    final override = severityOverride;
    if (override == null) return code;

    return LintCode(
      name: code.name,
      problemMessage: code.problemMessage,
      correctionMessage: code.correctionMessage,
      uniqueName: code.uniqueName,
      url: code.url,
      errorSeverity: override,
    );
  }

  /// Reports a diagnostic at the given [node], unless an ignore comment
  /// is present (supports both underscore and hyphen formats).
  void atNode(AstNode node, LintCode code) {
    // Check for hyphenated ignore comment before reporting
    if (IgnoreUtils.hasIgnoreComment(node, _ruleName)) {
      return;
    }
    _delegate.atNode(node, _applyOverride(code));
  }

  /// Reports a diagnostic at the given [token].
  void atToken(Token token, LintCode code) {
    // Check for hyphenated ignore comment on the token
    if (IgnoreUtils.hasIgnoreCommentOnToken(token, _ruleName)) {
      return;
    }
    _delegate.atToken(token, _applyOverride(code));
  }

  /// Reports a diagnostic at the given offset and length.
  ///
  /// Note: This method cannot check for ignore comments since we only have
  /// offset/length, not an AST node. Use [atNode] when possible.
  void atOffset({
    required int offset,
    required int length,
    required LintCode errorCode,
  }) {
    // Cannot easily check for ignore comments with just offset/length
    // Delegate directly to the underlying reporter
    _delegate.atOffset(
      offset: offset,
      length: length,
      diagnosticCode: _applyOverride(errorCode),
    );
  }
}
