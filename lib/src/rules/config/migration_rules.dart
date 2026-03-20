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
        if (arg is NamedExpression && arg.name.label.name == 'indicatorColor') {
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
        if (arg is NamedExpression && arg.name.label.name == 'indicatorColor') {
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
      while (i >= 0 &&
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
      while (i < content.length && (content[i] == ' ' || content[i] == '\t')) {
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

// ─────────────────────────────────────────────────────────────────────────────
// prefer_platform_menu_bar_child
// ─────────────────────────────────────────────────────────────────────────────

/// Detects deprecated `body` parameter on `PlatformMenuBar`.
///
/// Since: v9.10.0 | Rule version: v1
///
/// Flutter 3.1 deprecated the `body` constructor parameter on
/// `PlatformMenuBar` in favor of `child`. The parameter was renamed to
/// follow the standard Flutter widget convention where the single child
/// widget is named `child`. The deprecated `body` parameter was removed
/// after Flutter 3.16.
///
/// **BAD:**
/// ```dart
/// PlatformMenuBar(
///   menus: menus,
///   body: MyApp(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// PlatformMenuBar(
///   menus: menus,
///   child: MyApp(),
/// )
/// ```
///
/// See: https://github.com/flutter/flutter/pull/138509
class PreferPlatformMenuBarChildRule extends SaropaLintRule {
  PreferPlatformMenuBarChildRule() : super(code: _code);

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
  Set<String>? get requiredPatterns => const <String>{'PlatformMenuBar'};

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _PreferPlatformMenuBarChildFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_platform_menu_bar_child',
    "[prefer_platform_menu_bar_child] The 'body' parameter on PlatformMenuBar "
        'was deprecated in Flutter 3.1 and removed after Flutter 3.16 '
        '(PR #138509). The parameter was renamed to follow the standard '
        "Flutter widget convention where the single child widget is named "
        "'child'. Code using the old 'body' parameter will fail to compile "
        'on Flutter 3.19 and later. {v1}',
    correctionMessage:
        "Rename the 'body' named argument to 'child'. The behavior is "
        'identical — only the parameter name changed.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'PlatformMenuBar') return;

      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'body') {
          reporter.atNode(arg.name);
          return;
        }
      }
    });
  }
}

/// Quick fix: rename `body:` to `child:` in PlatformMenuBar.
class _PreferPlatformMenuBarChildFix extends SaropaFixProducer {
  _PreferPlatformMenuBarChildFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferPlatformMenuBarChild',
    80,
    "Rename 'body' to 'child'",
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final label = node is Label ? node : node.thisOrAncestorOfType<Label>();
    if (label == null) return;

    final identifier = label.label;
    if (identifier.name != 'body') return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(identifier.offset, identifier.length),
        'child',
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// prefer_keepalive_dispose
// ─────────────────────────────────────────────────────────────────────────────

/// Detects deprecated `release()` method on `KeepAliveHandle`.
///
/// Since: v9.10.0 | Rule version: v1
///
/// Flutter 3.3 deprecated `KeepAliveHandle.release()` in favor of
/// `dispose()`. The `release()` method was often called without a
/// subsequent `dispose()`, leading to memory leaks. The functionality was
/// consolidated into `dispose()` so a single call handles both releasing
/// the keep-alive and cleaning up the handle. The deprecated `release()`
/// was removed after Flutter 3.19.
///
/// **BAD:**
/// ```dart
/// keepAliveHandle.release();
/// ```
///
/// **GOOD:**
/// ```dart
/// keepAliveHandle.dispose();
/// ```
///
/// See: https://github.com/flutter/flutter/pull/143961
class PreferKeepaliveDisposeRule extends SaropaLintRule {
  PreferKeepaliveDisposeRule() : super(code: _code);

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
  Set<String>? get requiredPatterns => const <String>{'release'};

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _PreferKeepaliveDisposeFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_keepalive_dispose',
    "[prefer_keepalive_dispose] The 'release()' method on KeepAliveHandle was "
        'deprecated in Flutter 3.3 and removed after Flutter 3.19 '
        '(PR #143961). Calling release() without dispose() caused memory '
        'leaks because the handle was never cleaned up. The functionality '
        'was consolidated into dispose(), which both releases the keep-alive '
        'and cleans up the handle in a single call. {v1}',
    correctionMessage:
        "Replace 'release()' with 'dispose()'. The dispose() method now "
        'performs both release and cleanup. Review call sites to ensure '
        'dispose() is not called twice.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'release') return;

      // Verify the target type is KeepAliveHandle via static type
      final targetType = node.realTarget?.staticType;
      if (targetType == null) return;
      final typeName = targetType.getDisplayString();
      if (!typeName.startsWith('KeepAliveHandle')) return;

      reporter.atNode(node.methodName);
    });
  }
}

/// Quick fix: rename `release()` to `dispose()` on KeepAliveHandle.
class _PreferKeepaliveDisposeFix extends SaropaFixProducer {
  _PreferKeepaliveDisposeFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferKeepaliveDispose',
    80,
    "Replace 'release()' with 'dispose()'",
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // The error is reported on the method name SimpleIdentifier.
    if (node is! SimpleIdentifier) return;
    if (node.name != 'release') return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(node.offset, node.length),
        'dispose',
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// prefer_context_menu_builder
// ─────────────────────────────────────────────────────────────────────────────

/// Detects deprecated `previewBuilder` parameter on `CupertinoContextMenu`.
///
/// Since: v9.10.0 | Rule version: v1
///
/// Flutter 3.4 deprecated the `previewBuilder` parameter on
/// `CupertinoContextMenu` in favor of `builder`. The old `previewBuilder`
/// only handled the second half of the context menu's opening animation
/// (after `CupertinoContextMenu.animationOpensAt`). The new `builder`
/// covers the full animation lifecycle from 0 to 1, giving more control.
/// The deprecated parameter was removed after Flutter 3.19.
///
/// **BAD:**
/// ```dart
/// CupertinoContextMenu(
///   previewBuilder: (context, animation, child) {
///     return FittedBox(child: child);
///   },
///   child: myWidget,
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// CupertinoContextMenu(
///   builder: (context, animation) {
///     return FittedBox(child: myWidget);
///   },
///   child: myWidget,
/// )
/// ```
///
/// See: https://github.com/flutter/flutter/pull/143990
class PreferContextMenuBuilderRule extends SaropaLintRule {
  PreferContextMenuBuilderRule() : super(code: _code);

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
  Set<String>? get requiredPatterns => const <String>{'CupertinoContextMenu'};

  static const LintCode _code = LintCode(
    'prefer_context_menu_builder',
    "[prefer_context_menu_builder] The 'previewBuilder' parameter on "
        'CupertinoContextMenu was deprecated in Flutter 3.4 and removed '
        'after Flutter 3.19 (PR #143990). The old previewBuilder only '
        'handled the second half of the opening animation (after '
        'animationOpensAt). The replacement builder parameter covers the '
        'full animation lifecycle from 0 to 1. Note: the callback signature '
        'changed from (context, animation, child) to (context, animation) — '
        'manual migration is required. {v1}',
    correctionMessage:
        "Replace 'previewBuilder' with 'builder' and update the callback "
        'signature from (context, animation, child) to (context, animation). '
        'The child widget must be referenced directly instead of via the '
        'callback parameter.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Skip lint rule/fix source — detection patterns trigger self-referential FPs
    if (context.isLintPluginSource) return;

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'CupertinoContextMenu') return;

      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'previewBuilder') {
          reporter.atNode(arg.name);
          return;
        }
      }
    });
  }

  // No auto-fix: callback signature changed from 3 params to 2 params,
  // requiring manual migration of the child reference.
}

// ─────────────────────────────────────────────────────────────────────────────
// prefer_pan_axis
// ─────────────────────────────────────────────────────────────────────────────

/// Detects deprecated `alignPanAxis` parameter on `InteractiveViewer`.
///
/// Since: v9.10.0 | Rule version: v1
///
/// Flutter 3.7 deprecated the `alignPanAxis` boolean parameter on
/// `InteractiveViewer` in favor of the `panAxis` enum parameter. The old
/// boolean only supported two modes (free or aligned), while the new
/// `PanAxis` enum adds `horizontal` and `vertical` options. The deprecated
/// parameter was removed after Flutter 3.19.
///
/// **BAD:**
/// ```dart
/// InteractiveViewer(
///   alignPanAxis: true,
///   child: child,
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// InteractiveViewer(
///   panAxis: PanAxis.aligned,
///   child: child,
/// )
/// ```
///
/// See: https://github.com/flutter/flutter/pull/142500
class PreferPanAxisRule extends SaropaLintRule {
  PreferPanAxisRule() : super(code: _code);

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
  Set<String>? get requiredPatterns => const <String>{'alignPanAxis'};

  static const LintCode _code = LintCode(
    'prefer_pan_axis',
    "[prefer_pan_axis] The 'alignPanAxis' parameter on InteractiveViewer was "
        'deprecated in Flutter 3.7 and removed after Flutter 3.19 '
        '(PR #142500). The boolean parameter only supported two modes (free '
        'or aligned). The replacement panAxis parameter uses a PanAxis enum '
        'that adds horizontal-only and vertical-only panning options. '
        'Use PanAxis.aligned instead of alignPanAxis: true, or PanAxis.free '
        '(the default) instead of alignPanAxis: false. {v1}',
    correctionMessage:
        "Replace 'alignPanAxis: true' with 'panAxis: PanAxis.aligned', or "
        "remove 'alignPanAxis: false' (PanAxis.free is the default).",
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'InteractiveViewer') return;

      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'alignPanAxis') {
          reporter.atNode(arg.name);
          return;
        }
      }
    });
  }

  // No auto-fix: the value transformation (bool → PanAxis enum) requires
  // context-dependent replacement that is not safe to automate.
}

// ─────────────────────────────────────────────────────────────────────────────
// prefer_button_style_icon_alignment
// ─────────────────────────────────────────────────────────────────────────────

/// Detects deprecated `iconAlignment` parameter on button constructors.
///
/// Since: v9.10.0 | Rule version: v1
///
/// Flutter 3.28 deprecated the `iconAlignment` parameter directly on
/// `ButtonStyleButton` subclass constructors (`ElevatedButton.icon`,
/// `FilledButton.icon`, `OutlinedButton.icon`, `TextButton.icon`). The
/// property was moved into `ButtonStyle` so it can be customized through
/// themes and `styleFrom` methods consistently with other icon properties.
///
/// **BAD:**
/// ```dart
/// ElevatedButton.icon(
///   label: Text('Button'),
///   icon: Icon(Icons.add),
///   iconAlignment: IconAlignment.end,
///   onPressed: () {},
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ElevatedButton.icon(
///   label: Text('Button'),
///   icon: Icon(Icons.add),
///   style: ElevatedButton.styleFrom(
///     iconAlignment: IconAlignment.end,
///   ),
///   onPressed: () {},
/// )
/// ```
///
/// See: https://github.com/flutter/flutter/pull/160023
class PreferButtonStyleIconAlignmentRule extends SaropaLintRule {
  PreferButtonStyleIconAlignmentRule() : super(code: _code);

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
  Set<String>? get requiredPatterns => const <String>{'iconAlignment'};

  static const LintCode _code = LintCode(
    'prefer_button_style_icon_alignment',
    "[prefer_button_style_icon_alignment] The 'iconAlignment' parameter on "
        'ButtonStyleButton subclass constructors (ElevatedButton.icon, '
        'FilledButton.icon, OutlinedButton.icon, TextButton.icon) was '
        'deprecated in Flutter 3.28 (PR #160023). The property was moved '
        'into ButtonStyle so it can be customized through themes and '
        "styleFrom methods. Use ButtonStyle.iconAlignment via the 'style' "
        'parameter instead of passing it directly to the constructor. {v1}',
    correctionMessage:
        "Remove 'iconAlignment' from the constructor and set it via "
        "the 'style' parameter instead, e.g. "
        'ElevatedButton.styleFrom(iconAlignment: IconAlignment.end).',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Button types whose `.icon` constructor had the deprecated parameter.
  static const _buttonTypes = <String>{
    'ElevatedButton',
    'FilledButton',
    'OutlinedButton',
    'TextButton',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Skip lint rule/fix source — detection patterns trigger self-referential FPs
    if (context.isLintPluginSource) return;

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final typeName = node.constructorName.type.name.lexeme;
      if (!_buttonTypes.contains(typeName)) return;

      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression &&
            arg.name.label.name == 'iconAlignment') {
          reporter.atNode(arg.name);
          return;
        }
      }
    });
  }

  // No auto-fix: moving the value into ButtonStyle requires restructuring
  // the constructor call, which is too complex for a safe automated fix.
}

// ─────────────────────────────────────────────────────────────────────────────
// prefer_key_event
// ─────────────────────────────────────────────────────────────────────────────

/// Detects deprecated `RawKeyEvent`/`RawKeyboard` API usage.
///
/// Since: v9.10.0 | Rule version: v1
///
/// Flutter 3.18 deprecated the `RawKeyEvent`/`RawKeyboard` key event system
/// in favor of the `KeyEvent`/`HardwareKeyboard` system. The old system is
/// being removed. The new system provides better key repeat handling (via a
/// separate `KeyRepeatEvent` type) and moves modifier key state queries to
/// `HardwareKeyboard.instance` instead of the event object.
///
/// **BAD:**
/// ```dart
/// RawKeyboardListener(
///   focusNode: focusNode,
///   onKey: (event) {
///     if (event is RawKeyDownEvent) { ... }
///   },
///   child: child,
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// KeyboardListener(
///   focusNode: focusNode,
///   onKeyEvent: (event) {
///     if (event is KeyDownEvent) { ... }
///   },
///   child: child,
/// )
/// ```
///
/// See: https://github.com/flutter/flutter/pull/136677
class PreferKeyEventRule extends SaropaLintRule {
  PreferKeyEventRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  bool get requiresFlutterImport => true;

  // 'RawKey' is more specific than 'Raw' — avoids scanning files that merely
  // contain RawImage, RawGestureDetector, rawValue, etc.
  @override
  Set<String>? get requiredPatterns => const <String>{'RawKey'};

  static const LintCode _code = LintCode(
    'prefer_key_event',
    "[prefer_key_event] The RawKeyEvent/RawKeyboard key event system was "
        'deprecated in Flutter 3.18 (PR #136677) in favor of '
        'KeyEvent/HardwareKeyboard. The old system will be removed in a '
        'future release. Migrate: RawKeyEvent → KeyEvent, '
        'RawKeyDownEvent → KeyDownEvent, RawKeyUpEvent → KeyUpEvent, '
        'RawKeyboard → HardwareKeyboard, '
        'RawKeyboardListener → KeyboardListener. Also replace onKey '
        'callbacks with onKeyEvent on Focus/FocusNode/FocusScope. {v1}',
    correctionMessage:
        'Replace RawKeyEvent with KeyEvent, RawKeyboard with '
        'HardwareKeyboard, RawKeyboardListener with KeyboardListener, '
        'and onKey with onKeyEvent. See the Flutter key event migration '
        'guide for details.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Deprecated type names and their replacements.
  static const _deprecatedTypes = <String>{
    'RawKeyEvent',
    'RawKeyDownEvent',
    'RawKeyUpEvent',
    'RawKeyboard',
    'RawKeyboardListener',
  };

  /// Widget types where `onKey:` is deprecated in favor of `onKeyEvent:`.
  static const _onKeyWidgets = <String>{
    'Focus',
    'FocusNode',
    'FocusScope',
    'FocusScopeNode',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Skip lint rule/fix source — detection patterns trigger self-referential FPs
    if (context.isLintPluginSource) return;

    // Case 1: Detect deprecated type references (e.g., RawKeyEvent in type
    // annotations, is-checks, and constructor calls).
    context.addNamedType((NamedType node) {
      if (_deprecatedTypes.contains(node.name.lexeme)) {
        reporter.atNode(node);
      }
    });

    // Case 2: Detect `onKey:` named argument in Focus/FocusNode constructors.
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final typeName = node.constructorName.type.name.lexeme;
      if (!_onKeyWidgets.contains(typeName)) return;

      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'onKey') {
          reporter.atNode(arg.name);
          return;
        }
      }
    });
  }

  // No auto-fix: the migration involves multiple interrelated changes
  // (type renames, callback signature changes, modifier key query changes)
  // that are not safe to automate piecemeal.
}

// ─────────────────────────────────────────────────────────────────────────────
// prefer_m3_text_theme
// ─────────────────────────────────────────────────────────────────────────────

/// Detects deprecated 2018-era `TextTheme` member names.
///
/// Since: v9.10.0 | Rule version: v1
///
/// Flutter 3.1 deprecated the 2018-era `TextTheme` property names in favor
/// of the Material 3 naming scheme. The deprecated names were removed in
/// Flutter 3.22 (PR #139255). The full mapping is:
///
/// - `headline1` → `displayLarge`
/// - `headline2` → `displayMedium`
/// - `headline3` → `displaySmall`
/// - `headline4` → `headlineMedium`
/// - `headline5` → `headlineSmall`
/// - `headline6` → `titleLarge`
/// - `subtitle1` → `titleMedium`
/// - `subtitle2` → `titleSmall`
/// - `bodyText1` → `bodyLarge`
/// - `bodyText2` → `bodyMedium`
/// - `caption` → `bodySmall`
/// - `button` → `labelLarge`
/// - `overline` → `labelSmall`
///
/// **BAD:**
/// ```dart
/// final style = Theme.of(context).textTheme.headline1;
/// ```
///
/// **GOOD:**
/// ```dart
/// final style = Theme.of(context).textTheme.displayLarge;
/// ```
///
/// See: https://github.com/flutter/flutter/pull/139255
class PreferM3TextThemeRule extends SaropaLintRule {
  PreferM3TextThemeRule() : super(code: _code);

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
  Set<String>? get requiredPatterns => const <String>{'TextTheme'};

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _PreferM3TextThemeFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_m3_text_theme',
    "[prefer_m3_text_theme] This TextTheme member uses the deprecated "
        '2018-era naming scheme that was removed in Flutter 3.22 '
        '(PR #139255). The 13 deprecated names (headline1-6, subtitle1-2, '
        'bodyText1-2, caption, button, overline) were replaced by the '
        'Material 3 naming scheme (displayLarge/Medium/Small, '
        'headlineMedium/Small, titleLarge/Medium/Small, '
        'bodyLarge/Medium/Small, labelLarge/Small). Code using the old '
        'names will fail to compile on Flutter 3.22 and later. {v1}',
    correctionMessage:
        'Rename the deprecated TextTheme member to its Material 3 '
        'equivalent (e.g. headline1 → displayLarge, bodyText2 → bodyMedium, '
        'caption → bodySmall).',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Maps deprecated 2018 TextTheme member names to M3 replacements.
  static const _renames = <String, String>{
    'headline1': 'displayLarge',
    'headline2': 'displayMedium',
    'headline3': 'displaySmall',
    'headline4': 'headlineMedium',
    'headline5': 'headlineSmall',
    'headline6': 'titleLarge',
    'subtitle1': 'titleMedium',
    'subtitle2': 'titleSmall',
    'bodyText1': 'bodyLarge',
    'bodyText2': 'bodyMedium',
    'caption': 'bodySmall',
    'button': 'labelLarge',
    'overline': 'labelSmall',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Skip lint rule/fix source — detection patterns trigger self-referential FPs
    if (context.isLintPluginSource) return;

    // Case 1: TextTheme(headline1: ...) or textTheme.copyWith(headline1: ...)
    // Detect deprecated named args in TextTheme constructor and copyWith.
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'TextTheme') return;

      _flagDeprecatedArgs(node.argumentList, reporter);
    });

    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'copyWith') return;

      final targetType = node.realTarget?.staticType;
      if (targetType == null) return;
      if (!targetType.getDisplayString().startsWith('TextTheme')) return;

      _flagDeprecatedArgs(node.argumentList, reporter);
    });

    // Case 2: textTheme.headline1 (property access on TextTheme instance)
    context.addPropertyAccess((PropertyAccess node) {
      final propName = node.propertyName.name;
      if (!_renames.containsKey(propName)) return;

      final targetType = node.realTarget.staticType;
      if (targetType == null) return;
      if (!targetType.getDisplayString().startsWith('TextTheme')) return;

      reporter.atNode(node.propertyName);
    });

    // Case 3: textTheme.headline1 via PrefixedIdentifier (simple variable)
    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      final propName = node.identifier.name;
      if (!_renames.containsKey(propName)) return;

      final prefixType = node.prefix.staticType;
      if (prefixType == null) return;
      if (!prefixType.getDisplayString().startsWith('TextTheme')) return;

      reporter.atNode(node.identifier);
    });
  }

  /// Flags any deprecated named arguments in the given argument list.
  static void _flagDeprecatedArgs(
    ArgumentList argList,
    SaropaDiagnosticReporter reporter,
  ) {
    for (final arg in argList.arguments) {
      if (arg is NamedExpression &&
          _renames.containsKey(arg.name.label.name)) {
        reporter.atNode(arg.name);
      }
    }
  }
}

/// Quick fix: rename a deprecated TextTheme member to its M3 equivalent.
class _PreferM3TextThemeFix extends SaropaFixProducer {
  _PreferM3TextThemeFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferM3TextTheme',
    80,
    'Rename to Material 3 text theme name',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // For named arguments: reported on Label → find the identifier
    final label = node is Label ? node : node.thisOrAncestorOfType<Label>();
    if (label != null) {
      final identifier = label.label;
      final replacement = PreferM3TextThemeRule._renames[identifier.name];
      if (replacement == null) return;

      await builder.addDartFileEdit(file, (b) {
        b.addSimpleReplacement(
          SourceRange(identifier.offset, identifier.length),
          replacement,
        );
      });
      return;
    }

    // For property access: reported on the SimpleIdentifier
    if (node is SimpleIdentifier) {
      final replacement = PreferM3TextThemeRule._renames[node.name];
      if (replacement == null) return;

      await builder.addDartFileEdit(file, (b) {
        b.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          replacement,
        );
      });
    }
  }
}
