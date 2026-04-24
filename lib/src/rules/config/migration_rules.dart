// ignore_for_file: always_specify_types, depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/source/source_range.dart';

import '../../fixes/config/prefer_dropdown_menu_item_button_opacity_animation_field_fix.dart';
import '../../fixes/config/replace_asset_manifest_json_fix.dart';
import '../../fixes/type/remove_null_assertion_fix.dart';
import '../../saropa_lint_rule.dart';
import 'flutter_test_window_deprecation_utils.dart';
import 'migration_rule_source_utils.dart' as migration_src;

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
// prefer_dropdown_menu_item_button_opacity_animation
// ─────────────────────────────────────────────────────────────────────────────

/// Flags redundant `opacityAnimation!` and nullable `CurvedAnimation? opacityAnimation`
/// on `State` subclasses for `DropdownMenuItemButton`.
///
/// Since: Unreleased | Rule version: v1
///
/// Flutter 3.32 ([PR #164795](https://github.com/flutter/flutter/pull/164795)) makes
/// `opacityAnimation` on `DropdownMenuItemButton`'s state non-nullable (`late CurvedAnimation`).
/// Nullable fields and null assertions are legacy patterns from when the animation was typed
/// as nullable.
///
/// Detection uses resolved types (`DropdownMenuItemButton`, `State`, `CurvedAnimation`) so
/// unrelated identifiers named `opacityAnimation` are not flagged.
/// [SaropaLintRule.requiresFlutterImport] is
/// false so example fixtures with mocks can be analyzed; the type graph still constrains matches.
///
/// **BAD:**
/// ```dart
/// class _MyState extends State<DropdownMenuItemButton<String>> {
///   CurvedAnimation? opacityAnimation;
///   void tick() {
///     opacityAnimation!.value;
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyState extends State<DropdownMenuItemButton<String>> {
///   late CurvedAnimation opacityAnimation;
///   void tick() {
///     opacityAnimation.value;
///   }
/// }
/// ```
///
/// See: https://github.com/flutter/flutter/pull/164795
class PreferDropdownMenuItemButtonOpacityAnimationRule extends SaropaLintRule {
  PreferDropdownMenuItemButtonOpacityAnimationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config', 'flutter', 'material'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  bool get requiresFlutterImport => false;

  @override
  Set<String>? get requiredPatterns => const <String>{'opacityAnimation'};

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        RemoveNullAssertionFix(context: context),
    ({required CorrectionProducerContext context}) =>
        PreferDropdownMenuItemButtonOpacityAnimationFieldFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_dropdown_menu_item_button_opacity_animation',
    '[prefer_dropdown_menu_item_button_opacity_animation] DropdownMenuItemButton state always assigns a non-null opacity animation (Flutter 3.32+, PR #164795). A nullable CurvedAnimation? field or a null assertion on opacityAnimation is a legacy pattern from older Flutter typings — it adds noise, risks runtime throws from !, and hides the guarantee that the animation exists once the state is initialized. Prefer late CurvedAnimation opacityAnimation and use it without !. {v1}',
    correctionMessage:
        'For the field: use late CurvedAnimation and drop the ?. For opacityAnimation!, remove the ! operator.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPostfixExpression((PostfixExpression node) {
      _reportOpacityAnimationBangIfLegacy(node, reporter);
    });

    context.addFieldDeclaration((FieldDeclaration node) {
      if (node.isStatic) return;
      final AstNode? parent = node.parent;
      if (parent is! ClassDeclaration) return;
      final ClassElement? classEl = parent.declaredFragment?.element;
      if (classEl == null) return;
      if (!_classElementIsStateForDropdownMenuItemButton(classEl)) return;

      for (final VariableDeclaration v in node.fields.variables) {
        if (v.name.lexeme != 'opacityAnimation') {
          continue;
        }
        final Element? decl = v.declaredFragment?.element;
        if (decl is! FieldElement) {
          continue;
        }
        final DartType t = decl.type;
        if (t.nullabilitySuffix != NullabilitySuffix.question) {
          continue;
        }
        if (t is! InterfaceType || t.element.name != 'CurvedAnimation') {
          continue;
        }
        reporter.atToken(v.name, code);
      }
    });
  }
}

bool _dartTypeIsOrExtendsDropdownMenuItemButton(DartType? type) {
  if (type is! InterfaceType) return false;
  if (type.element.name == 'DropdownMenuItemButton') return true;
  for (final InterfaceType sup in type.allSupertypes) {
    if (sup.element.name == 'DropdownMenuItemButton') return true;
  }
  return false;
}

bool _classElementIsStateForDropdownMenuItemButton(ClassElement classElement) {
  final InterfaceType? supertype = classElement.supertype;
  if (supertype == null) return false;
  if (supertype.element.name != 'State') return false;
  final List<DartType> args = supertype.typeArguments;
  if (args.isEmpty) return false;
  return _dartTypeIsOrExtendsDropdownMenuItemButton(args.first);
}

bool _fieldIsOpacityOnDropdownMenuState(FieldElement element) {
  if (element.name != 'opacityAnimation') return false;
  final Element? enc = element.enclosingElement;
  if (enc is! ClassElement) return false;
  return _classElementIsStateForDropdownMenuItemButton(enc);
}

void _reportOpacityAnimationBangIfLegacy(
  PostfixExpression node,
  SaropaDiagnosticReporter reporter,
) {
  if (node.operator.lexeme != '!') return;
  final Expression operand = node.operand;
  if (operand is PropertyAccess) {
    if (operand.propertyName.name != 'opacityAnimation') return;
    final Expression? target = operand.realTarget;
    if (target == null) return;
    if (!_dartTypeIsOrExtendsDropdownMenuItemButton(target.staticType)) return;
    reporter.atNode(node);

    return;
  }
  if (operand is SimpleIdentifier) {
    if (operand.name != 'opacityAnimation') return;
    final Element? el = operand.element;
    if (el is! FieldElement) return;
    if (!_fieldIsOpacityOnDropdownMenuState(el)) return;
    reporter.atNode(node);
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

    final named = node.thisOrAncestorOfType<NamedExpression>();
    if (named == null) return;
    if (named.name.label.name != 'indicatorColor') return;

    final range = migration_src.sourceRangeForDeletingNamedArgument(
      unitResult.content,
      named,
    );
    if (range == null) return;

    await builder.addDartFileEdit(file, (b) {
      b.addDeletion(range);
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
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final typeName = node.constructorName.type.name.lexeme;
      if (!_buttonTypes.contains(typeName)) return;

      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'iconAlignment') {
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
      if (arg is NamedExpression && _renames.containsKey(arg.name.label.name)) {
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

// ─────────────────────────────────────────────────────────────────────────────
// prefer_overflow_bar_over_button_bar
// ─────────────────────────────────────────────────────────────────────────────

/// Flags `ButtonBar`, `ButtonBarThemeData`, and `ThemeData.buttonBarTheme` in
/// favor of `OverflowBar`-centric layouts (Flutter 3.13 / 3.24 migration).
///
/// Since: v9.10.1 | Rule version: v2
///
/// Flutter recommends `OverflowBar` for horizontal action rows (PR #128437).
/// `ButtonBar`, `ButtonBarThemeData`, and `ThemeData.buttonBarTheme` were
/// deprecated in PR #145523 (Flutter 3.24.0).
///
/// ## Detection & false-positive guards
///
/// * Instance creations use `isMaterialMigrationInstanceCreationTarget` in
///   `migration_rule_source_utils.dart` (Flutter `package:flutter/...`, null
///   element, or no same-unit class-like declaration of that name).
/// * Unresolved `ButtonBar()`, `ButtonBarThemeData()`, or `ThemeData(...)` may
///   parse as [MethodInvocation] with a null element; those are reported unless
///   the unit declares a matching type name (for `ThemeData`, only
///   `buttonBarTheme:` arguments are checked).
/// * `ThemeData.copyWith(buttonBarTheme:)` and `.buttonBarTheme` use static type
///   `ThemeData` (same pattern as [PreferTabbarThemeIndicatorColorRule]).
///
/// ## Performance
///
/// [SaropaLintRule.requiredPatterns]: `ButtonBar` and `buttonBarTheme` for early file skip.
///
/// ## Quick fix
///
/// Removes `buttonBarTheme:` from `ThemeData` constructors and `copyWith` only.
///
/// **BAD:**
/// ```dart
/// ButtonBar(children: [])
/// ThemeData(buttonBarTheme: ButtonBarThemeData())
/// ```
///
/// **GOOD:**
/// ```dart
/// OverflowBar(children: [])
/// ThemeData()
/// ```
///
/// See: https://github.com/flutter/flutter/pull/128437,
/// https://github.com/flutter/flutter/pull/145523
class PreferOverflowBarOverButtonBarRule extends SaropaLintRule {
  PreferOverflowBarOverButtonBarRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config', 'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  bool get requiresFlutterImport => true;

  @override
  Set<String>? get requiredPatterns => const <String>{
    'ButtonBar',
    'buttonBarTheme',
  };

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _RemoveThemeDataButtonBarThemeArgFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_overflow_bar_over_button_bar',
    "[prefer_overflow_bar_over_button_bar] Prefer OverflowBar instead of "
        'ButtonBar for Material action button rows. OverflowBar is the '
        'supported pattern for horizontal actions that reflow on overflow '
        '(Flutter 3.13.0, PR #128437). ButtonBar, ButtonBarThemeData, and '
        'ThemeData.buttonBarTheme were deprecated in Flutter 3.24.0 (PR '
        '#145523). Remove buttonBarTheme from ThemeData and migrate widgets '
        'to OverflowBar; theme ButtonBarThemeData has no direct replacement — '
        'apply spacing and alignment on OverflowBar or surrounding layout. {v2}',
    correctionMessage:
        'Replace ButtonBar with OverflowBar (adjust parameters). Remove '
        'buttonBarTheme from ThemeData / copyWith; stop using '
        'ButtonBarThemeData.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final CompilationUnit unit = node.root as CompilationUnit;
      final typeName = node.constructorName.type.name.lexeme;
      if (typeName == 'ButtonBar' || typeName == 'ButtonBarThemeData') {
        if (!migration_src.isMaterialMigrationInstanceCreationTarget(
          typeElement: node.constructorName.type.element,
          typeLexeme: typeName,
          compilationUnit: unit,
        )) {
          return;
        }
        reporter.atNode(node.constructorName, code);
        return;
      }
      if (typeName != 'ThemeData') return;
      if (!migration_src.isMaterialMigrationInstanceCreationTarget(
        typeElement: node.constructorName.type.element,
        typeLexeme: typeName,
        compilationUnit: unit,
      )) {
        return;
      }
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'buttonBarTheme') {
          reporter.atNode(arg.name, code);
          return;
        }
      }
    });

    context.addMethodInvocation((MethodInvocation node) {
      if (node.target != null) return;
      if (node.methodName.element != null) return;
      final String m = node.methodName.name;
      final CompilationUnit unit = node.root as CompilationUnit;
      if (m == 'ButtonBar' || m == 'ButtonBarThemeData') {
        if (migration_src.compilationUnitDeclaresClassLikeName(unit, m)) {
          return;
        }
        reporter.atNode(node.methodName, code);
        return;
      }
      if (m == 'ThemeData') {
        if (migration_src.compilationUnitDeclaresClassLikeName(
          unit,
          'ThemeData',
        )) {
          return;
        }
        for (final arg in node.argumentList.arguments) {
          if (arg is NamedExpression &&
              arg.name.label.name == 'buttonBarTheme') {
            reporter.atNode(arg.name, code);
            return;
          }
        }
      }
    });

    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'copyWith') return;
      final targetType = node.realTarget?.staticType;
      if (targetType == null) return;
      if (!targetType.getDisplayString().startsWith('ThemeData')) return;
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'buttonBarTheme') {
          reporter.atNode(arg.name, code);
          return;
        }
      }
    });

    context.addPropertyAccess((PropertyAccess node) {
      if (node.propertyName.name != 'buttonBarTheme') return;
      final targetType = node.realTarget.staticType;
      if (targetType == null) return;
      if (!targetType.getDisplayString().startsWith('ThemeData')) return;
      reporter.atNode(node.propertyName, code);
    });

    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (node.identifier.name != 'buttonBarTheme') return;
      final prefixType = node.prefix.staticType;
      if (prefixType == null) return;
      if (!prefixType.getDisplayString().startsWith('ThemeData')) return;
      reporter.atNode(node.identifier, code);
    });
  }
}

/// Removes deprecated `buttonBarTheme:` from [ThemeData] constructors and
/// `copyWith`, matching Flutter's data-driven fix (PR #145523).
class _RemoveThemeDataButtonBarThemeArgFix extends SaropaFixProducer {
  _RemoveThemeDataButtonBarThemeArgFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeThemeDataButtonBarThemeArg',
    80,
    "Remove 'buttonBarTheme' from ThemeData",
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final named = node.thisOrAncestorOfType<NamedExpression>();
    if (named == null) return;
    if (named.name.label.name != 'buttonBarTheme') return;

    final range = migration_src.sourceRangeForDeletingNamedArgument(
      unitResult.content,
      named,
    );
    if (range == null) return;

    await builder.addDartFileEdit(file, (b) {
      b.addDeletion(range);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// avoid_deprecated_flutter_test_window
// ─────────────────────────────────────────────────────────────────────────────

void _reportFlutterTestBindingWindowIfDeprecated(
  SaropaDiagnosticReporter reporter,
  SimpleIdentifier property,
) {
  if (property.name != 'window') return;
  if (!isFlutterTestSdkTestWidgetsFlutterBindingWindowGetter(
    property.element,
  )) {
    return;
  }
  reporter.atNode(property);
}

/// Flags deprecated `TestWindow` and `TestWidgetsFlutterBinding.window` from
/// `package:flutter_test`.
///
/// ## Context
///
/// Flutter 3.10 deprecated these APIs (PR #122824) to prepare for multi-window
/// support. `TestWindow` combined platform dispatcher and view concerns; the
/// replacement split is `WidgetTester.platformDispatcher` /
/// `TestPlatformDispatcher` vs `WidgetTester.view` / `WidgetTester.viewOf`.
///
/// ## Detection strategy
///
/// - **Element resolution only** — no substring heuristics on type names (see
///   CONTRIBUTING.md, avoiding false positives). `TestWindow` and
///   `TestWidgetsFlutterBinding.window` must resolve to declarations in
///   `package:flutter_test`.
/// - **[requiredPatterns]:** `package:flutter_test/` so non-test files skip the
///   rule before AST callbacks run.
/// - **Constructors:** [NamedType] inside a [ConstructorName] is excluded from
///   the [NamedType] visitor and handled only by [InstanceCreationExpression] to
///   avoid duplicate diagnostics on `TestWindow(...)`.
///
/// ## False-positive guards
///
/// - A user-defined `class TestWindow` in the app package is not flagged.
/// - `.window` on types other than `TestWidgetsFlutterBinding` (e.g.
///   `dart:ui` `SingletonFlutterWindow`) is not flagged unless the identifier
///   resolves to that binding's deprecated [GetterElement].
///
/// ## Performance
///
/// Low cost: narrow `requiredPatterns`, registry callbacks only (`NamedType`,
/// `InstanceCreationExpression`, `PropertyAccess`, `PrefixedIdentifier`), no
/// recursion or cross-file work.
///
/// ## Quick fix
///
/// None — replacements need a `WidgetTester` or binding reference in scope;
/// automated rewrites would often be wrong.
///
/// ## References
///
/// - PR: https://github.com/flutter/flutter/pull/122824
///
/// Since: v10.0.3 | Rule version: v1
///
/// **BAD:**
/// ```dart
/// TestWidgetsFlutterBinding.instance!.window.physicalSizeTestValue = size;
/// TestWindow(window: ui.window);
/// ```
///
/// **GOOD:**
/// ```dart
/// tester.view.physicalSize = size;
/// tester.platformDispatcher.clearDevicePixelRatioTestValue();
/// ```
class AvoidDeprecatedFlutterTestWindowRule extends SaropaLintRule {
  AvoidDeprecatedFlutterTestWindowRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'config', 'flutter', 'test'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'package:flutter_test/'};

  static const LintCode _code = LintCode(
    'avoid_deprecated_flutter_test_window',
    '[avoid_deprecated_flutter_test_window] TestWindow and '
        'TestWidgetsFlutterBinding.window were deprecated in Flutter 3.10 '
        '(PR #122824) for upcoming multi-window support. Use '
        'WidgetTester.platformDispatcher (or TestPlatformDispatcher) for '
        'platform-specific test values and WidgetTester.view / '
        'WidgetTester.viewOf for view-specific values instead of the combined '
        'TestWindow API. {v1}',
    correctionMessage:
        'Prefer tester.platformDispatcher and tester.view (or viewOf) in '
        'widget tests; avoid TestWindow and binding.window.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addNamedType((NamedType node) {
      if (node.parent is ConstructorName) return;
      if (!isFlutterTestSdkTestWindowElement(node.element)) return;
      reporter.atNode(node);
    });

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final NamedType typeNode = node.constructorName.type;
      if (!isFlutterTestSdkTestWindowElement(typeNode.element)) return;
      reporter.atNode(typeNode);
    });

    context.addPropertyAccess((PropertyAccess node) {
      _reportFlutterTestBindingWindowIfDeprecated(reporter, node.propertyName);
    });

    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      _reportFlutterTestBindingWindowIfDeprecated(reporter, node.identifier);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// avoid_removed_render_object_element_methods
// ─────────────────────────────────────────────────────────────────────────────

/// Flags removed `RenderObjectElement` methods (Flutter 3.0, PR #98616).
///
/// **Why:** `insertChildRenderObject`, `moveChildRenderObject`, and
/// `removeChildRenderObject` were deprecated in Flutter 1.21 (PR #64254) and
/// removed in Flutter 3.0. The replacements swap the word order:
/// `insertRenderObjectChild`, `moveRenderObjectChild`,
/// `removeRenderObjectChild`. Migration is supported by `dart fix`.
///
/// **Detection:** [MethodDeclaration] where the method name matches one of the
/// three removed names and the enclosing class extends `RenderObjectElement`.
/// Also detects [MethodInvocation] via `super.` calls.
///
/// **Quick fix:** renames the method (swaps "Child"↔"RenderObject" order).
///
/// **BAD:**
/// ```dart
/// class MyElement extends RenderObjectElement {
///   @override
///   void insertChildRenderObject(RenderObject child, Object? slot) { ... }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyElement extends RenderObjectElement {
///   @override
///   void insertRenderObjectChild(RenderObject child, Object? slot) { ... }
/// }
/// ```
class AvoidRemovedRenderObjectElementMethodsRule extends SaropaLintRule {
  AvoidRemovedRenderObjectElementMethodsRule() : super(code: _code);

  static const Map<String, String> _renames = {
    'insertChildRenderObject': 'insertRenderObjectChild',
    'moveChildRenderObject': 'moveRenderObjectChild',
    'removeChildRenderObject': 'removeRenderObjectChild',
  };

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'config'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  bool get requiresFlutterImport => true;

  @override
  Set<String>? get requiredPatterns => const <String>{
    'insertChildRenderObject',
    'moveChildRenderObject',
    'removeChildRenderObject',
  };

  static const LintCode _code = LintCode(
    'avoid_removed_render_object_element_methods',
    '[avoid_removed_render_object_element_methods] '
        'insertChildRenderObject, moveChildRenderObject, and '
        'removeChildRenderObject were removed from RenderObjectElement in '
        'Flutter 3.0 (PR #98616, deprecated since Flutter 1.21). Use '
        'insertRenderObjectChild, moveRenderObjectChild, and '
        'removeRenderObjectChild instead. Migration is supported by '
        '`dart fix`. {v1}',
    correctionMessage:
        'Rename the method: swap Child↔RenderObject word order '
        '(e.g. insertChildRenderObject → insertRenderObjectChild).',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _RenameRenderObjectElementMethodFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Detect override declarations of the removed methods.
    context.addMethodDeclaration((MethodDeclaration node) {
      final name = node.name.lexeme;
      if (!_renames.containsKey(name)) return;

      // Verify enclosing class extends RenderObjectElement via type check.
      final classDecl = node.parent;
      if (classDecl is! ClassDeclaration) return;
      final supertype = classDecl.extendsClause?.superclass;
      if (supertype == null) return;

      // Check resolved supertype or fall back to name matching.
      // Resolved: walk supertypes for RenderObjectElement.
      final supertypeEl = supertype.element;
      if (supertypeEl is InterfaceElement) {
        final isROE =
            supertypeEl.allSupertypes.any(
              (t) => t.element.name == 'RenderObjectElement',
            ) ||
            supertypeEl.name == 'RenderObjectElement';
        if (!isROE) return;
      } else {
        // Unresolved — fall back to name matching on the extends clause.
        if (supertype.name.lexeme != 'RenderObjectElement') return;
      }

      reporter.atToken(node.name);
    });

    // Detect super.insertChildRenderObject(...) etc.
    context.addMethodInvocation((MethodInvocation node) {
      final name = node.methodName.name;
      if (!_renames.containsKey(name)) return;
      if (node.target is! SuperExpression) return;
      reporter.atNode(node.methodName);
    });
  }
}

class _RenameRenderObjectElementMethodFix extends SaropaFixProducer {
  _RenameRenderObjectElementMethodFix({required super.context});

  static const Map<String, String> _renames = {
    'insertChildRenderObject': 'insertRenderObjectChild',
    'moveChildRenderObject': 'moveRenderObjectChild',
    'removeChildRenderObject': 'removeRenderObjectChild',
  };

  static const FixKind _fixKind = FixKind(
    'saropa.fix.renameRenderObjectElementMethod',
    80,
    'Rename to replacement method',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;

    // MethodInvocation (super.foo) → coveringNode is SimpleIdentifier.
    // MethodDeclaration (override) → coveringNode is MethodDeclaration;
    // extract the name Token so the fix works for both detection paths.
    final String name;
    final int offset;
    final int length;
    if (node is SimpleIdentifier) {
      name = node.name;
      offset = node.offset;
      length = node.length;
    } else if (node is MethodDeclaration) {
      name = node.name.lexeme;
      offset = node.name.offset;
      length = node.name.length;
    } else {
      return;
    }

    final replacement = _renames[name];
    if (replacement == null) return;

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(SourceRange(offset, length), replacement);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// avoid_deprecated_animated_list_typedefs
// ─────────────────────────────────────────────────────────────────────────────

/// Flags deprecated `AnimatedListItemBuilder` and
/// `AnimatedListRemovedItemBuilder` typedefs (Flutter 3.7, PR #113131).
///
/// **Why:** These typedefs were renamed to `AnimatedItemBuilder` and
/// `AnimatedRemovedItemBuilder` for broader applicability (same signature,
/// new names). No semantic difference — just a rename.
///
/// **Detection:** [NamedType] where the identifier matches either deprecated
/// typedef name and resolves to `package:flutter/` or is unresolved.
///
/// **Quick fix:** renames the type reference.
///
/// **BAD:**
/// ```dart
/// AnimatedListItemBuilder builder = (context, index, animation) { ... };
/// ```
///
/// **GOOD:**
/// ```dart
/// AnimatedItemBuilder builder = (context, index, animation) { ... };
/// ```
class AvoidDeprecatedAnimatedListTypedefsRule extends SaropaLintRule {
  AvoidDeprecatedAnimatedListTypedefsRule() : super(code: _code);

  static const Map<String, String> _renames = {
    'AnimatedListItemBuilder': 'AnimatedItemBuilder',
    'AnimatedListRemovedItemBuilder': 'AnimatedRemovedItemBuilder',
  };

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'config'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  bool get requiresFlutterImport => true;

  @override
  Set<String>? get requiredPatterns => const <String>{
    'AnimatedListItemBuilder',
    'AnimatedListRemovedItemBuilder',
  };

  static const LintCode _code = LintCode(
    'avoid_deprecated_animated_list_typedefs',
    '[avoid_deprecated_animated_list_typedefs] '
        'AnimatedListItemBuilder and AnimatedListRemovedItemBuilder were '
        'deprecated in Flutter 3.7 (PR #113131). Use AnimatedItemBuilder '
        'and AnimatedRemovedItemBuilder instead — the signatures are '
        'identical, only the names changed for broader applicability. {v1}',
    correctionMessage:
        'Rename AnimatedListItemBuilder → AnimatedItemBuilder and '
        'AnimatedListRemovedItemBuilder → AnimatedRemovedItemBuilder.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _RenameAnimatedListTypedefFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addNamedType((NamedType node) {
      final name = node.name.lexeme;
      if (!_renames.containsKey(name)) return;

      // If resolved, verify it comes from Flutter.
      final el = node.element;
      if (el != null) {
        final uri = el.library?.uri.toString() ?? '';
        if (!uri.startsWith('package:flutter/')) return;
      }

      reporter.atNode(node);
    });
  }
}

class _RenameAnimatedListTypedefFix extends SaropaFixProducer {
  _RenameAnimatedListTypedefFix({required super.context});

  static const Map<String, String> _renames = {
    'AnimatedListItemBuilder': 'AnimatedItemBuilder',
    'AnimatedListRemovedItemBuilder': 'AnimatedRemovedItemBuilder',
  };

  static const FixKind _fixKind = FixKind(
    'saropa.fix.renameAnimatedListTypedef',
    80,
    'Rename to replacement typedef',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node is! NamedType) return;
    final replacement = _renames[node.name.lexeme];
    if (replacement == null) return;
    final t = node.name;

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(SourceRange(t.offset, t.length), replacement);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// avoid_deprecated_use_material3_copy_with
// ─────────────────────────────────────────────────────────────────────────────

/// Flags `useMaterial3` parameter in `ThemeData.copyWith()` (Flutter 3.16,
/// PR #131455).
///
/// **Why:** Setting `useMaterial3` to `false` in `ThemeData.copyWith()` does
/// **not** force Material 2 — it only works when set in the `ThemeData()`
/// constructor directly. Using it in `copyWith()` is misleading and a common
/// source of bugs. The parameter was deprecated to prevent misuse.
///
/// **Detection:** [MethodInvocation] named `copyWith` on a target whose
/// static type is `ThemeData`, containing a `useMaterial3` named argument.
///
/// **Quick fix:** removes the `useMaterial3` named argument.
///
/// **BAD:**
/// ```dart
/// theme.copyWith(useMaterial3: false);
/// ```
///
/// **GOOD:**
/// ```dart
/// ThemeData(useMaterial3: false, ...); // set in constructor, not copyWith
/// ```
class AvoidDeprecatedUseMaterial3CopyWithRule extends SaropaLintRule {
  AvoidDeprecatedUseMaterial3CopyWithRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'config'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  bool get requiresFlutterImport => true;

  @override
  Set<String>? get requiredPatterns => const <String>{'useMaterial3'};

  static const LintCode _code = LintCode(
    'avoid_deprecated_use_material3_copy_with',
    '[avoid_deprecated_use_material3_copy_with] The useMaterial3 parameter '
        'in ThemeData.copyWith() was deprecated in Flutter 3.16 (PR #131455). '
        'Setting useMaterial3 in copyWith() does not force Material 2 — it '
        'must be set in the ThemeData() constructor directly. Remove the '
        'parameter from copyWith() to avoid misleading behavior. {v1}',
    correctionMessage:
        "Remove 'useMaterial3' from copyWith() and set it in "
        'the ThemeData() constructor instead.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _RemoveUseMaterial3CopyWithFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'copyWith') return;

      // Verify the target is ThemeData via static type.
      final targetType = node.realTarget?.staticType;
      if (targetType == null) return;
      final targetEl = targetType.element;
      if (targetEl?.name != 'ThemeData') return;

      // Check for useMaterial3 named argument.
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'useMaterial3') {
          reporter.atNode(arg.name);
          return;
        }
      }
    });
  }
}

class _RemoveUseMaterial3CopyWithFix extends SaropaFixProducer {
  _RemoveUseMaterial3CopyWithFix({required super.context});

  static const FixKind _fixKind = FixKind(
    'saropa.fix.removeUseMaterial3CopyWith',
    80,
    "Remove 'useMaterial3' from copyWith()",
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Find the NamedExpression for useMaterial3.
    final named = node is NamedExpression
        ? node
        : node.thisOrAncestorOfType<NamedExpression>();
    if (named == null || named.name.label.name != 'useMaterial3') return;

    final argList = named.parent;
    if (argList is! ArgumentList) return;

    final args = argList.arguments;
    final index = args.indexOf(named);
    if (index < 0) return;

    int start = named.offset;
    int end = named.end;

    // Remove surrounding comma and whitespace.
    if (args.length == 1) {
      // Only argument — remove it, leave empty parens.
      start = named.offset;
      end = named.end;
    } else if (index < args.length - 1) {
      // Not the last argument — remove trailing comma + whitespace.
      end = args[index + 1].offset;
    } else {
      // Last argument — remove leading comma + whitespace.
      start = args[index - 1].end;
    }

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(SourceRange(start, end - start), '');
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// avoid_deprecated_on_surface_destroyed
// ─────────────────────────────────────────────────────────────────────────────

/// Flags deprecated `SurfaceProducer.onSurfaceDestroyed` (Flutter 3.29,
/// PR #160937).
///
/// **Why:** `onSurfaceDestroyed` was deprecated in favor of
/// `onSurfaceCleanup`. The new name better reflects the callback's purpose
/// (cleanup before surface teardown, not notification after destruction).
///
/// **Detection:** [PropertyAccess] and [PrefixedIdentifier] where the
/// property name is `onSurfaceDestroyed` and the target's static type
/// resolves to `SurfaceProducer`.
///
/// **Quick fix:** renames `onSurfaceDestroyed` → `onSurfaceCleanup`.
///
/// **BAD:**
/// ```dart
/// surfaceProducer.onSurfaceDestroyed = () { ... };
/// ```
///
/// **GOOD:**
/// ```dart
/// surfaceProducer.onSurfaceCleanup = () { ... };
/// ```
class AvoidDeprecatedOnSurfaceDestroyedRule extends SaropaLintRule {
  AvoidDeprecatedOnSurfaceDestroyedRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'config'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  bool get requiresFlutterImport => true;

  @override
  Set<String>? get requiredPatterns => const <String>{'onSurfaceDestroyed'};

  static const LintCode _code = LintCode(
    'avoid_deprecated_on_surface_destroyed',
    '[avoid_deprecated_on_surface_destroyed] '
        'SurfaceProducer.onSurfaceDestroyed was deprecated in Flutter 3.29 '
        '(PR #160937). Use onSurfaceCleanup instead — the new name better '
        'reflects the callback semantics (cleanup before teardown, not '
        'notification after destruction). {v1}',
    correctionMessage: 'Rename onSurfaceDestroyed to onSurfaceCleanup.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _RenameOnSurfaceDestroyedFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    void checkProperty(SimpleIdentifier prop, DartType? targetType) {
      if (prop.name != 'onSurfaceDestroyed') return;
      if (targetType == null) return;
      final el = targetType.element;
      if (el?.name != 'SurfaceProducer') return;
      reporter.atNode(prop);
    }

    context.addPropertyAccess((PropertyAccess node) {
      checkProperty(node.propertyName, node.realTarget.staticType);
    });

    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      checkProperty(node.identifier, node.prefix.staticType);
    });
  }
}

class _RenameOnSurfaceDestroyedFix extends SaropaFixProducer {
  _RenameOnSurfaceDestroyedFix({required super.context});

  static const FixKind _fixKind = FixKind(
    'saropa.fix.renameOnSurfaceDestroyed',
    80,
    "Rename to 'onSurfaceCleanup'",
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node is! SimpleIdentifier || node.name != 'onSurfaceDestroyed') return;

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(node.offset, node.length),
        'onSurfaceCleanup',
      );
    });
  }
}
