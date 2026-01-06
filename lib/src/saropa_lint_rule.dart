// ignore_for_file: always_specify_types, depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'ignore_utils.dart';

/// Base class for Saropa lint rules that supports hyphenated ignore comments.
///
/// This class wraps the [DiagnosticReporter] to automatically check for
/// ignore comments using both underscore and hyphen formats before reporting.
///
/// Example: A rule named `no_empty_block` will respect both:
/// - `// ignore: no_empty_block` (standard underscore format)
/// - `// ignore: no-empty-block` (hyphenated format)
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
///   @override
///   void runWithReporter(
///     CustomLintResolver resolver,
///     SaropaDiagnosticReporter reporter,
///     CustomLintContext context,
///   ) {
///     // Use reporter.atNode() as usual - hyphen aliases are handled automatically
///   }
/// }
/// ```
abstract class SaropaLintRule extends DartLintRule {
  const SaropaLintRule({required super.code});

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final wrappedReporter = SaropaDiagnosticReporter(reporter, code.name);
    runWithReporter(resolver, wrappedReporter, context);
  }

  /// Override this method instead of [run] to implement your lint rule.
  ///
  /// The [reporter] automatically handles hyphenated ignore comment aliases.
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  );
}

/// A diagnostic reporter that checks for hyphenated ignore comments.
///
/// Wraps a [DiagnosticReporter] and intercepts [atNode] calls to check
/// for ignore comments in both underscore and hyphen formats.
class SaropaDiagnosticReporter {
  SaropaDiagnosticReporter(this._delegate, this._ruleName);

  final DiagnosticReporter _delegate;
  final String _ruleName;

  /// Reports a diagnostic at the given [node], unless an ignore comment
  /// is present (supports both underscore and hyphen formats).
  void atNode(AstNode node, LintCode code) {
    // Check for hyphenated ignore comment before reporting
    if (IgnoreUtils.hasIgnoreComment(node, _ruleName)) {
      return;
    }
    _delegate.atNode(node, code);
  }

  /// Reports a diagnostic at the given [token].
  void atToken(Token token, LintCode code) {
    // Check for hyphenated ignore comment on the token
    if (IgnoreUtils.hasIgnoreCommentOnToken(token, _ruleName)) {
      return;
    }
    _delegate.atToken(token, code);
  }
}
