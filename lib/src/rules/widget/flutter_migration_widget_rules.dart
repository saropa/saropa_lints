// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../fixes/widget/prefer_super_key_fix.dart';
import '../../saropa_lint_rule.dart';
import 'flutter_migration_widget_detection.dart';

// =============================================================================
// Flutter migration / API consistency (widget)
// =============================================================================

/// Prefer `super.key` over `Key? key` with `super(key: key)` on Flutter widgets.
///
/// Since: v9.11.0 | Rule version: v1
///
/// Matches the Flutter framework style from Flutter 3.24 ([PR #147621](https://github.com/flutter/flutter/pull/147621)):
/// forward the widget key with Dart super-parameter syntax instead of an
/// explicit super constructor call.
///
/// **Narrower than** the stylistic rule `prefer_super_parameters`: only applies
/// to classes that extend `StatelessWidget`, `StatefulWidget`, or a type whose
/// name ends with `Widget`, and only for a `Key`-typed parameter named `key`.
/// If you already enable `prefer_super_parameters`, you may get duplicate
/// diagnostics on the same `key: key` forwarding; prefer one or the other for
/// widget keys.
///
/// Detection logic lives in [PreferSuperKeyDetection] so the quick fix stays in
/// lockstep with the rule.
///
/// **Limitations:** Only the unqualified type name `Key` is accepted (not
/// import-prefix forms like `widgets.Key`). `super(key: key)` combined with
/// other super arguments is not reported—only a sole `key` forward matches.
///
/// **BAD:**
/// ```dart
/// class MyPage extends StatelessWidget {
///   const MyPage({Key? key}) : super(key: key);
///   // ...
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyPage extends StatelessWidget {
///   const MyPage({super.key});
///   // ...
/// }
/// ```
///
/// See: https://github.com/flutter/flutter/pull/147621
class PreferSuperKeyRule extends SaropaLintRule {
  PreferSuperKeyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'convention'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  bool get requiresFlutterImport => true;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        PreferSuperKeyFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_super_key',
    '[prefer_super_key] Widget constructor uses Key? key with super(key: key). Prefer super.key (Dart super parameters) for the same behavior with less boilerplate, matching current Flutter framework style (Flutter 3.24+). {v1}',
    correctionMessage:
        'Replace the Key? key parameter with super.key and remove the super(key: key) initializer.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addConstructorDeclaration((ConstructorDeclaration node) {
      final AstNode? parent = node.parent;
      if (parent is! ClassDeclaration) return;
      if (!PreferSuperKeyDetection.shouldReportPreferSuperKey(
        ctor: node,
        parent: parent,
      )) {
        return;
      }
      final SuperConstructorInvocation? superInit =
          PreferSuperKeyDetection.soleSuperKeyForwarding(node);
      if (superInit == null) return;
      final NodeList<Expression> args = superInit.argumentList.arguments;
      if (args.isEmpty) return;
      final Expression a = args.single;
      if (a is NamedExpression) {
        reporter.atNode(a.name);
      }
    });
  }
}

/// Flags `InkWell` with a circular `customBorder` on chip `deleteIcon` values.
///
/// Since: v9.11.0 | Rule version: v1
///
/// Material chip delete buttons use a **square** hit region; using
/// `InkWell(customBorder: CircleBorder(), …)` on `deleteIcon` mismatches that
/// shape and reproduces the inconsistency fixed in Flutter 3.22
/// ([PR #144319](https://github.com/flutter/flutter/pull/144319)). Prefer a
/// rectangular or stadium-shaped border, or omit `customBorder` and rely on
/// defaults.
///
/// Uses [requiredPatterns] (`deleteIcon`, `CircleBorder`) for cheap file
/// pre-filtering before AST walks.
///
/// Listens to both [InstanceCreationExpression] (e.g. `const InputChip(`) and
/// unqualified [MethodInvocation] (e.g. `InputChip(`), because the parser may
/// represent constructor calls as either depending on context.
///
/// **BAD:**
/// ```dart
/// InputChip(
///   label: const Text('x'),
///   onDeleted: () {},
///   deleteIcon: InkWell(
///     customBorder: const CircleBorder(),
///     onTap: () {},
///     child: const Icon(Icons.close),
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// InputChip(
///   label: const Text('x'),
///   onDeleted: () {},
///   deleteIcon: const Icon(Icons.close),
/// )
/// ```
///
/// See: https://github.com/flutter/flutter/pull/144319
class AvoidChipDeleteInkWellCircleBorderRule extends SaropaLintRule {
  AvoidChipDeleteInkWellCircleBorderRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'material', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  bool get requiresFlutterImport => true;

  @override
  Set<String>? get requiredPatterns => const <String>{
    'deleteIcon',
    'CircleBorder',
  };

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_chip_delete_inkwell_circle_border',
    '[avoid_chip_delete_inkwell_circle_border] Chip deleteIcon uses InkWell with CircleBorder as customBorder. Chip delete affordances are square; a circular ink shape mismatches the control and the behavior corrected in Flutter 3.22 (PR #144319). Use a non-circular shape (e.g. RoundedRectangleBorder), or use the default chip delete styling without a custom InkWell border. {v1}',
    correctionMessage:
        'Remove customBorder or replace CircleBorder with a rectangular or stadium-shaped ShapeBorder aligned to the chip delete region.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    void reportIfBad(NamedExpression? bad) {
      if (bad == null) return;
      reporter.atNode(bad.name);
    }

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      reportIfBad(
        ChipDeleteInkWellCircleBorderDetection.violationForChipConstructor(
          node,
        ),
      );
    });

    context.addMethodInvocation((MethodInvocation node) {
      reportIfBad(
        ChipDeleteInkWellCircleBorderDetection.violationForChipMethodInvocation(
          node,
        ),
      );
    });
  }
}
