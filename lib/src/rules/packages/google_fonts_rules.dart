// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// google_fonts package lint rules.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../saropa_lint_rule.dart';

// cspell:ignore roboto
/// Warns when GoogleFonts usage lacks fontFamilyFallback.
///
/// Since: v2.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: google_fonts_fallback, require_font_fallback
///
/// Google Fonts may fail to load on slow connections or offline. Without a
/// fallback, text may be invisible or use system default unexpectedly.
///
/// **BAD:**
/// ```dart
/// Text(
///   'Hello',
///   style: GoogleFonts.roboto(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Text(
///   'Hello',
///   style: GoogleFonts.roboto(
///     fontFamilyFallback: ['Arial', 'sans-serif'],
///   ),
/// )
/// ```
class RequireGoogleFontsFallbackRule extends SaropaLintRule {
  RequireGoogleFontsFallbackRule() : super(code: _code);

  // Medium impact - UI fallback, not crash-causing
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_google_fonts_fallback',
    '[require_google_fonts_fallback] GoogleFonts should specify fontFamilyFallback. Google Fonts may fail to load on slow connections or offline. Without a fallback, text may be invisible or use system default unexpectedly. {v2}',
    correctionMessage:
        'Add fontFamilyFallback to handle font loading failures. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      // Check for GoogleFonts calls
      final String? target = node.target?.toSource();
      if (target != 'GoogleFonts') return;

      // Check for fontFamilyFallback parameter
      final bool hasFallback = node.argumentList.arguments.any((
        Expression arg,
      ) {
        if (arg is NamedExpression) {
          return arg.name.label.name == 'fontFamilyFallback';
        }
        return false;
      });

      if (!hasFallback) {
        reporter.atNode(node);
      }
    });
  }
}
