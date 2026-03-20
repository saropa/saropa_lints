// ignore_for_file: always_specify_types, depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../fixes/config/replace_asset_manifest_json_fix.dart';
import '../../saropa_lint_rule.dart';

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
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_asset_manifest_json',
    "[avoid_asset_manifest_json] The 'AssetManifest.json' file was removed in Flutter 3.38.0 (PR #172594). Code that loads this path at runtime — such as rootBundle.loadString('AssetManifest.json') — will throw a FlutterError because the file no longer exists in the built app bundle. Migrate to the typed AssetManifest API (AssetManifest.loadFromAssetBundle) or use 'AssetManifest.bin' for the binary format. {v1}",
    correctionMessage:
        "Replace 'AssetManifest.json' with AssetManifest.loadFromAssetBundle(rootBundle) from package:flutter/services.dart, or use 'AssetManifest.bin' if you need the raw binary manifest.",
    severity: DiagnosticSeverity.ERROR,
  );

  static final RegExp _assetManifestLiteralRegex = RegExp(
    RegExp.escape('AssetManifest.json'),
  );

  @override
  Set<String>? get requiredPatterns => const <String>{'AssetManifest.json'};

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Skip lint rule/fix source — detection patterns trigger self-referential FPs
    if (context.isLintPluginSource) return;

    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      if (node.value == 'AssetManifest.json') {
        reporter.atNode(node);
      }
    });

    context.addStringInterpolation((StringInterpolation node) {
      final source = node.toSource();
      if (_assetManifestLiteralRegex.hasMatch(source)) {
        reporter.atNode(node);
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        ReplaceAssetManifestJsonFix(context: context),
  ];
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
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config'};

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
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config'};

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

      reporter.atNode(node);
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

// ─────────────────────────────────────────────────────────────────────────────
// prefer_tabbar_theme_indicator_color
// ─────────────────────────────────────────────────────────────────────────────

/// Detects usage of the deprecated `ThemeData.indicatorColor` property.
///
/// Since: v9.10.0 | Rule version: v1
///
/// Flutter 3.32.0 deprecated `ThemeData.indicatorColor` as part of the
/// Material Theme System Updates. The indicator color for tab bars should be
/// set through `TabBarThemeData.indicatorColor` instead of the top-level
/// `ThemeData` property. Using the deprecated property bypasses the
/// component-level theme system and will be removed in a future release.
///
/// **BAD:**
/// ```dart
/// ThemeData(
///   indicatorColor: Colors.blue,
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ThemeData(
///   tabBarTheme: TabBarThemeData(
///     indicatorColor: Colors.blue,
///   ),
/// )
/// ```
///
/// See: https://github.com/flutter/flutter/pull/160024
class PreferTabbarThemeIndicatorColorRule extends SaropaLintRule {
  PreferTabbarThemeIndicatorColorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  bool get requiresFlutterImport => true;

  @override
  Set<String>? get requiredPatterns => const <String>{'indicatorColor'};

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _RemoveIndicatorColorArgFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_tabbar_theme_indicator_color',
    "[prefer_tabbar_theme_indicator_color] The 'indicatorColor' property on "
        'ThemeData was deprecated in Flutter 3.32.0 (PR #160024) as part of '
        'the Material Theme System Updates. Using ThemeData.indicatorColor '
        'directly bypasses the component-level theme system and will be '
        'removed in a future Flutter release. Migrate to '
        'TabBarThemeData.indicatorColor to keep tab indicator colors '
        'consistent with the Material Theme System. {v1}',
    correctionMessage:
        "Move 'indicatorColor' from ThemeData to TabBarThemeData. Set it via "
        'ThemeData(tabBarTheme: TabBarThemeData(indicatorColor: ...)) or '
        'Theme.of(context).tabBarTheme.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Skip lint rule/fix source — detection patterns trigger self-referential FPs
    if (context.isLintPluginSource) return;

    // Case 1: ThemeData(indicatorColor: value)
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'ThemeData') return;

      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression &&
            arg.name.label.name == 'indicatorColor') {
          reporter.atNode(arg.name);
          return;
        }
      }
    });

    // Case 2: themeData.copyWith(indicatorColor: value)
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'copyWith') return;

      // Verify the target type is ThemeData via static type
      final targetType = node.realTarget?.staticType;
      if (targetType == null) return;
      final typeName = targetType.getDisplayString();
      if (!typeName.startsWith('ThemeData')) return;

      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression &&
            arg.name.label.name == 'indicatorColor') {
          reporter.atNode(arg.name);
          return;
        }
      }
    });

    // Case 3: themeData.indicatorColor (property access)
    context.addPropertyAccess((PropertyAccess node) {
      if (node.propertyName.name != 'indicatorColor') return;

      // realTarget is non-nullable on PropertyAccess; staticType may be null
      final targetType = node.realTarget.staticType;
      if (targetType == null) return;
      final typeName = targetType.getDisplayString();
      if (!typeName.startsWith('ThemeData')) return;

      reporter.atNode(node.propertyName);
    });

    // Case 4: themeData.indicatorColor via PrefixedIdentifier
    // (when prefix is a simple identifier, e.g., a local variable)
    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (node.identifier.name != 'indicatorColor') return;

      final prefixType = node.prefix.staticType;
      if (prefixType == null) return;
      final typeName = prefixType.getDisplayString();
      if (!typeName.startsWith('ThemeData')) return;

      reporter.atNode(node.identifier);
    });
  }
}

/// Quick fix: remove the `indicatorColor:` named argument.
///
/// This removes the deprecated argument from ThemeData constructors and
/// copyWith calls. The user must manually add the value to TabBarThemeData.
class _RemoveIndicatorColorArgFix extends SaropaFixProducer {
  _RemoveIndicatorColorArgFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeIndicatorColorArg',
    80,
    "Remove 'indicatorColor' (migrate to TabBarThemeData)",
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Navigate to the NamedExpression containing this label
    final named = node.thisOrAncestorOfType<NamedExpression>();
    if (named == null) return;

    // Only fix constructor/copyWith args, not property access
    final parent = named.parent;
    if (parent is! ArgumentList) return;

    final content = unitResult.content;
    int start = named.offset;
    int end = named.end;

    // Remove leading comma + whitespace/newlines if present
    if (start > 0) {
      int i = start - 1;
      while (
          i >= 0 &&
          (content[i] == ' ' || content[i] == '\t' || content[i] == '\n')) {
        i--;
      }
      if (i >= 0 && content[i] == ',') {
        while (i > 0 && (content[i - 1] == ' ' || content[i - 1] == '\t')) {
          i--;
        }
        start = i;
      }
    }

    // Remove trailing comma + whitespace if this is the first argument
    if (end < content.length) {
      int i = end;
      while (i < content.length &&
          (content[i] == ' ' || content[i] == '\t')) {
        i++;
      }
      if (i < content.length && content[i] == ',') {
        i++;
        while (i < content.length &&
            (content[i] == ' ' || content[i] == '\t')) {
          i++;
        }
        end = i;
      }
    }

    await builder.addDartFileEdit(file, (b) {
      b.addDeletion(SourceRange(start, end - start));
    });
  }
}
