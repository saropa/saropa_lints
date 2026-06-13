// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// uuid package lint rules.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../fixes/packages/package_specific/replace_v1_with_v4_fix.dart';
import '../../saropa_lint_rule.dart';

/// Suggests using UUID v4 instead of v1 for better randomness.
///
/// Since: v2.2.0 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: prefer_uuid_v4_over_v1, use_uuid_v4
///
/// UUID v1 is time-based and includes MAC address, which may leak information.
/// UUID v4 is random and more suitable for most use cases.
///
/// **BAD:**
/// ```dart
/// final id = Uuid().v1();
/// ```
///
/// **GOOD:**
/// ```dart
/// final id = Uuid().v4();
/// ```
class PreferUuidV4Rule extends SaropaLintRule {
  PreferUuidV4Rule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        ReplaceV1WithV4Fix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_uuid_v4',
    '[prefer_uuid_v4] Prefer UUID v4 over v1 to improve randomness and privacy. UUID v1 is time-based and includes MAC address, which may leak information. UUID v4 is random and more suitable for most use cases. {v3}',
    correctionMessage:
        'Use Uuid().v4() instead of Uuid().v1(). Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'v1') return;

      // Check if it's a Uuid call
      final String source = node.toSource();
      if (RegExp(r'\bUuid\s*\(\s*\)|uuid\.').hasMatch(source)) {
        reporter.atNode(node);
      }
    });
  }
}
