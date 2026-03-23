// ignore_for_file: depend_on_referenced_packages

/// Flutter widget migration: align explicit `filterQuality` with post–3.24 defaults.
///
/// Implementation is split so the rule and IDE quick fix stay in sync:
/// [ImageFilterQualityLowDetection] owns all predicates; this file only wires
/// callbacks and metadata. Performance: [requiredPatterns] requires both
/// `filterQuality` and `FilterQuality` in file text; [RuleCost.low] and narrow
/// registry listeners (`addInstanceCreationExpression`, `addMethodInvocation`)
/// keep work bounded (no unit-wide scans, no recursion).
///
/// For maintainers: tier is **Comprehensive** (INFO) alongside other optional
/// Flutter style/migration hints; [LintImpact.low] reflects optional visual
/// defaults, not correctness or security.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../fixes/widget/prefer_image_filter_quality_medium_fix.dart';
import '../../saropa_lint_rule.dart';
import 'image_filter_quality_detection.dart';

/// Suggests `FilterQuality.medium` instead of `FilterQuality.low` on Flutter
/// image APIs, matching Flutter 3.24 defaults ([PR #148799](https://github.com/flutter/flutter/pull/148799)).
///
/// Since: unreleased | Rule version: v1
///
/// **Scope:** `Image` (default + `.network` / `.asset` / `.file` / `.memory`),
/// `RawImage`, `FadeInImage`, and `DecorationImage`. Does not flag `Texture`
/// (its default remained `low` in the same release cycle).
///
/// **Intent:** Code that pinned `filterQuality: FilterQuality.low` matched
/// pre-3.24 image defaults. The framework now defaults to `medium` for these
/// widgets; prefer `medium` or omit the argument to follow current behavior.
///
/// **False positives / limitations:** Deliberate `low` for performance is valid;
/// disable the rule for those call sites. When types fail to resolve, detection
/// falls back to name lexemes for widgets and a strict `FilterQuality.low`
/// shape for the value—see [ImageFilterQualityLowDetection]. A project-local
/// class named `Image` that resolves in analysis is not flagged unless it lives
/// under `package:flutter/`.
///
/// **BAD:**
/// ```dart
/// Image.network(url, filterQuality: FilterQuality.low)
/// ```
///
/// **GOOD:**
/// ```dart
/// Image.network(url, filterQuality: FilterQuality.medium)
/// // or omit filterQuality — default is medium (Flutter 3.24+)
/// ```
///
/// See: https://github.com/flutter/flutter/pull/148799
class PreferImageFilterQualityMediumRule extends SaropaLintRule {
  PreferImageFilterQualityMediumRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui', 'migration'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  bool get requiresFlutterImport => true;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  @override
  Set<String>? get requiredPatterns => const <String>{
    'filterQuality',
    'FilterQuality',
  };

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        PreferImageFilterQualityMediumFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_image_filter_quality_medium',
    '[prefer_image_filter_quality_medium] filterQuality: FilterQuality.low on Image / RawImage / FadeInImage / DecorationImage matches pre–Flutter 3.24 defaults. Flutter 3.24 switched image defaults to FilterQuality.medium (PR #148799). Prefer FilterQuality.medium or omit the argument. {v1}',
    correctionMessage:
        'Replace FilterQuality.low with FilterQuality.medium, or remove filterQuality to use the framework default.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    void reportNamed(NamedExpression? named) {
      if (named == null) return;
      reporter.atNode(named.name);
    }

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      reportNamed(
        ImageFilterQualityLowDetection.violatingFilterQualityNamedArg(node),
      );
    });

    context.addMethodInvocation((MethodInvocation node) {
      reportNamed(
        ImageFilterQualityLowDetection.violatingFilterQualityNamedArgInvocation(
          node,
        ),
      );
    });
  }
}
