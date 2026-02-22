// ignore_for_file: always_specify_types, depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../saropa_lint_rule.dart';

// =============================================================================
// MIGRATION RULES
// =============================================================================
//
// Rules that detect deprecated or removed Flutter/Dart APIs and guide users
// toward the recommended replacements. These catch migration issues that the
// Dart analyzer may not flag (e.g., string-based asset paths, renamed
// constructor parameters).

// ─────────────────────────────────────────────────────────────────────────────
// avoid_asset_manifest_json
// ─────────────────────────────────────────────────────────────────────────────

/// Detects usage of the removed `AssetManifest.json` file path.
///
/// Since: v5.1.0 | Rule version: v1
///
/// Flutter 3.38.0 removed the deprecated `AssetManifest.json` file. Apps that
/// load this file via `rootBundle.loadString('AssetManifest.json')` or similar
/// will fail at runtime. The replacement is `AssetManifest.bin` (binary format)
/// or the typed `AssetManifest` API from `package:flutter/services.dart`.
///
/// **BAD:**
/// ```dart
/// final manifest = await rootBundle.loadString('AssetManifest.json');
/// final decoded = json.decode(manifest);
/// ```
///
/// **GOOD:**
/// ```dart
/// final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
/// final assets = manifest.listAssets();
/// ```
///
/// See: https://github.com/flutter/flutter/pull/172594
class AvoidAssetManifestJsonRule extends SaropaLintRule {
  AvoidAssetManifestJsonRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_asset_manifest_json',
    "[avoid_asset_manifest_json] The 'AssetManifest.json' file was removed in Flutter 3.38.0 (PR #172594). Code that loads this path at runtime — such as rootBundle.loadString('AssetManifest.json') — will throw a FlutterError because the file no longer exists in the built app bundle. Migrate to the typed AssetManifest API (AssetManifest.loadFromAssetBundle) or use 'AssetManifest.bin' for the binary format. {v1}",
    correctionMessage:
        "Replace 'AssetManifest.json' with AssetManifest.loadFromAssetBundle(rootBundle) from package:flutter/services.dart, or use 'AssetManifest.bin' if you need the raw binary manifest.",
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  Set<String>? get requiredPatterns => const <String>{'AssetManifest.json'};

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      if (node.value == 'AssetManifest.json') {
        reporter.atNode(node);
      }
    });

    context.addStringInterpolation((StringInterpolation node) {
      final source = node.toSource();
      if (source.contains('AssetManifest.json')) {
        reporter.atNode(node);
      }
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// prefer_dropdown_initial_value
// ─────────────────────────────────────────────────────────────────────────────

/// Detects deprecated `value` parameter on `DropdownButtonFormField`.
///
/// Since: v5.1.0 | Rule version: v1
///
/// Flutter 3.35.0 deprecated the `value` constructor parameter on
/// `DropdownButtonFormField` in favor of `initialValue`. The `value` parameter
/// conflicted with `FormField.value` and caused confusing behavior when set
/// to null. The new `initialValue` parameter has clearer semantics.
///
/// **BAD:**
/// ```dart
/// DropdownButtonFormField<String>(
///   value: selectedItem,
///   items: items,
///   onChanged: (v) {},
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// DropdownButtonFormField<String>(
///   initialValue: selectedItem,
///   items: items,
///   onChanged: (v) {},
/// )
/// ```
///
/// See: https://github.com/flutter/flutter/pull/170805
class PreferDropdownInitialValueRule extends SaropaLintRule {
  PreferDropdownInitialValueRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  bool get requiresFlutterImport => true;

  @override
  Set<String>? get requiredPatterns => const <String>{
    'DropdownButtonFormField',
  };

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _PreferDropdownInitialValueFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_dropdown_initial_value',
    "[prefer_dropdown_initial_value] The 'value' parameter on DropdownButtonFormField was deprecated in Flutter 3.35.0 (PR #170805) in favor of 'initialValue'. The old 'value' parameter conflicted with FormField.value and caused confusing behavior when set to null — for example, the selected value was not properly reset. The renamed 'initialValue' parameter has identical behavior but clearer semantics that it only sets the initial selection, not a controlled value. {v1}",
    correctionMessage:
        "Rename the 'value' named argument to 'initialValue'. The behavior is identical — only the parameter name changed.",
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'DropdownButtonFormField') return;

      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'value') {
          reporter.atNode(arg.name);
          return;
        }
      }
    });
  }
}

/// Quick fix: rename `value:` to `initialValue:` in DropdownButtonFormField.
class _PreferDropdownInitialValueFix extends SaropaFixProducer {
  _PreferDropdownInitialValueFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferDropdownInitialValue',
    80,
    "Rename 'value' to 'initialValue'",
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // The error is reported on the NamedExpression's Label node.
    // Find the label whose name is 'value'.
    final label = node is Label ? node : node.thisOrAncestorOfType<Label>();
    if (label == null) return;

    final identifier = label.label;
    if (identifier.name != 'value') return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(identifier.offset, identifier.length),
        'initialValue',
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// prefer_on_pop_with_result
// ─────────────────────────────────────────────────────────────────────────────

/// Detects usage of the deprecated `onPop` callback on routes.
///
/// Since: v5.1.0 | Rule version: v1
///
/// Flutter 3.35.0 deprecated `Route.onPop` in favor of `onPopWithResult`,
/// which provides the pop result value to the callback. Code using `onPop`
/// loses the ability to inspect or react to the result value when a route
/// is popped.
///
/// **BAD:**
/// ```dart
/// MaterialPageRoute(
///   builder: (context) => const DetailPage(),
///   onPop: () {
///     debugPrint('Route was popped');
///   },
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// MaterialPageRoute(
///   builder: (context) => const DetailPage(),
///   onPopWithResult: (result) {
///     debugPrint('Route popped with: $result');
///   },
/// )
/// ```
///
/// See: https://github.com/flutter/flutter/pull/169700
class PreferOnPopWithResultRule extends SaropaLintRule {
  PreferOnPopWithResultRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  bool get requiresFlutterImport => true;

  @override
  Set<String>? get requiredPatterns => const <String>{'onPop'};

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _PreferOnPopWithResultFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_on_pop_with_result',
    "[prefer_on_pop_with_result] The 'onPop' callback on Route and PopNavigatorRouterDelegateMixin was deprecated in Flutter 3.35.0 (PR #169700) in favor of 'onPopWithResult'. The deprecated 'onPop' callback does not receive the pop result value, which means callers cannot inspect or react to data returned by the popped route. The replacement 'onPopWithResult' provides the result as a parameter, enabling proper data flow between routes. {v1}",
    correctionMessage:
        "Replace 'onPop' with 'onPopWithResult' and update the callback signature to accept the result parameter.",
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Detect onPop as a named argument in constructor/method calls.
    // Heuristic: flags any `onPop:` named argument inside an ArgumentList,
    // not just Route constructors. False positives are unlikely because:
    // 1. requiresFlutterImport filters to Flutter files only
    // 2. 'onPop' is a navigation-specific name rarely used elsewhere
    context.addNamedExpression((NamedExpression node) {
      if (node.name.label.name != 'onPop') return;

      final parent = node.parent;
      if (parent is! ArgumentList) return;

      reporter.atNode(node.name);
    });

    // Detect onPop as a method declaration override.
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'onPop') return;

      // Only flag if it's an override (not an unrelated method named onPop).
      for (final annotation in node.metadata) {
        if (annotation.name.name == 'override') {
          reporter.atToken(node.name);
          return;
        }
      }
    });
  }
}

/// Quick fix: rename `onPop` to `onPopWithResult`.
class _PreferOnPopWithResultFix extends SaropaFixProducer {
  _PreferOnPopWithResultFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferOnPopWithResult',
    80,
    "Rename 'onPop' to 'onPopWithResult'",
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // For named arguments: the error is on the Label node.
    final label = node is Label ? node : node.thisOrAncestorOfType<Label>();
    if (label != null && label.label.name == 'onPop') {
      final identifier = label.label;
      await builder.addDartFileEdit(file, (builder) {
        builder.addSimpleReplacement(
          SourceRange(identifier.offset, identifier.length),
          'onPopWithResult',
        );
      });
      return;
    }

    // For method declaration overrides: the error is on the method name token.
    final method = node is MethodDeclaration
        ? node
        : node.thisOrAncestorOfType<MethodDeclaration>();
    if (method != null && method.name.lexeme == 'onPop') {
      final nameToken = method.name;
      await builder.addDartFileEdit(file, (builder) {
        builder.addSimpleReplacement(
          SourceRange(nameToken.offset, nameToken.length),
          'onPopWithResult',
        );
      });
    }
  }
}
