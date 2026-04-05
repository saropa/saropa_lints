// ignore_for_file: always_specify_types, depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/source_range.dart';

import '../../saropa_lint_rule.dart';
import 'migration_rule_source_utils.dart' as migration_src;

// =============================================================================
// Flutter SDK migration rules (various versions)
// =============================================================================
//
// ## Purpose
//
// Rules that detect deprecated, removed, or suboptimal API patterns from
// specific Flutter/Dart SDK versions and guide migration to the recommended
// replacement.

// ─────────────────────────────────────────────────────────────────────────────
// Helper: check if a type comes from dart:convert
// ─────────────────────────────────────────────────────────────────────────────

bool _isDartConvertLibrary(LibraryElement? lib) {
  if (lib == null) return false;
  return lib.uri.toString() == 'dart:convert';
}

// ─────────────────────────────────────────────────────────────────────────────
// prefer_iterable_cast (#024)
// ─────────────────────────────────────────────────────────────────────────────

/// Flags `Iterable.castFrom(x)` and suggests `x.cast<T>()` instead.
///
/// Since: Unreleased | Rule version: v1
///
/// The `Iterable.castFrom` static method is less readable and less consistent
/// with other Iterable usages than the `cast<T>()` instance method. Flutter
/// 3.24.0 switched to the instance method throughout its codebase
/// (PR #150185). The instance method is more concise and reads left-to-right.
///
/// Also detects `List.castFrom`, `Set.castFrom`, and `Map.castFrom` static
/// methods which have the same `cast()` instance method replacements.
///
/// **BAD:**
/// ```dart
/// final result = Iterable.castFrom<Object, String>(items);
/// final list = List.castFrom<Object, String>(items);
/// ```
///
/// **GOOD:**
/// ```dart
/// final result = items.cast<String>();
/// final list = items.cast<String>();
/// ```
///
/// See: https://github.com/flutter/flutter/pull/150185
class PreferIterableCastRule extends SaropaLintRule {
  PreferIterableCastRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core', 'config', 'migration'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'castFrom'};

  static const LintCode _code = LintCode(
    'prefer_iterable_cast',
    '[prefer_iterable_cast] Iterable.castFrom (and List.castFrom, Set.castFrom, '
        'Map.castFrom) is a static method that is less readable and less '
        'consistent with other Iterable operations than the .cast<T>() instance '
        'method. Flutter 3.24 (PR #150185) migrated to .cast<T>() throughout '
        'its codebase. The instance method reads left-to-right and is more '
        'concise: items.cast<String>() instead of '
        'Iterable.castFrom<Object, String>(items). {v1}',
    correctionMessage:
        "Replace 'Iterable.castFrom(x)' with 'x.cast<T>()'. "
        'The same applies to List.castFrom, Set.castFrom, and Map.castFrom.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Types whose static `castFrom` should be replaced with `.cast()`.
  static const _castFromTargets = {'Iterable', 'List', 'Set', 'Map'};

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (context.isLintPluginSource) return;

    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'castFrom') return;

      // Must be a static call: Iterable.castFrom(...)
      final target = node.target;
      if (target is! SimpleIdentifier) return;
      if (!_castFromTargets.contains(target.name)) return;

      // Verify it resolves to a dart:core static method
      final element = node.methodName.element;
      if (element is! MethodElement || !element.isStatic) return;
      if (element.library.uri.toString() != 'dart:core') return;

      reporter.atNode(node);
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _PreferIterableCastFix(context: context),
  ];
}

/// Quick fix: replace `Iterable.castFrom<S, T>(x)` with `x.cast<T>()`.
class _PreferIterableCastFix extends SaropaFixProducer {
  _PreferIterableCastFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferIterableCast',
    80,
    "Replace with '.cast<T>()'",
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final invocation =
        node is MethodInvocation
            ? node
            : node.thisOrAncestorOfType<MethodInvocation>();
    if (invocation == null) return;
    if (invocation.methodName.name != 'castFrom') return;

    final args = invocation.argumentList.arguments;
    // castFrom takes 1 positional argument (the source iterable)
    if (args.isEmpty) return;
    final sourceArg = args.first;

    // Extract the target type argument (the second type argument, T in castFrom<S, T>)
    final typeArgs = invocation.typeArguments?.arguments;
    final targetType =
        (typeArgs != null && typeArgs.length >= 2)
            ? typeArgs[1].toSource()
            : null;

    final castSuffix =
        targetType != null ? '.cast<$targetType>()' : '.cast()';
    final sourceText = sourceArg.toSource();

    // Wrap in parentheses if the source is a complex expression
    // (e.g. a conditional, cascade, etc.) to preserve semantics
    final needsParens =
        sourceArg is ConditionalExpression ||
        sourceArg is BinaryExpression ||
        sourceArg is CascadeExpression ||
        sourceArg is AsExpression ||
        sourceArg is IsExpression;
    final replacement =
        needsParens ? '($sourceText)$castSuffix' : '$sourceText$castSuffix';

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(invocation.offset, invocation.length),
        replacement,
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// avoid_deprecated_use_inherited_media_query (#043)
// ─────────────────────────────────────────────────────────────────────────────

/// Flags usage of the deprecated `useInheritedMediaQuery` parameter.
///
/// Since: Unreleased | Rule version: v1
///
/// The `useInheritedMediaQuery` parameter on `WidgetsApp`, `MaterialApp`,
/// and `CupertinoApp` was deprecated after Flutter 3.7 (v3.7.0-29.0.pre).
/// The setting is now ignored — the widget never introduces its own
/// `MediaQuery`; the `View` widget takes care of that. Passing this argument
/// is dead code and may confuse readers into thinking it does something.
///
/// **BAD:**
/// ```dart
/// MaterialApp(
///   useInheritedMediaQuery: true,
///   home: MyHome(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// MaterialApp(
///   home: MyHome(),
/// )
/// ```
///
/// See: https://github.com/flutter/flutter/pull/139940
class AvoidDeprecatedUseInheritedMediaQueryRule extends SaropaLintRule {
  AvoidDeprecatedUseInheritedMediaQueryRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'config', 'migration'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  bool get requiresFlutterImport => true;

  @override
  Set<String>? get requiredPatterns =>
      const <String>{'useInheritedMediaQuery'};

  static const LintCode _code = LintCode(
    'avoid_deprecated_use_inherited_media_query',
    '[avoid_deprecated_use_inherited_media_query] The useInheritedMediaQuery '
        'parameter on MaterialApp, CupertinoApp, and WidgetsApp was deprecated '
        'after Flutter 3.7 (v3.7.0-29.0.pre). The setting is now ignored — '
        'WidgetsApp never introduces its own MediaQuery; the View widget takes '
        'care of that. Passing this argument is dead code and may confuse '
        'readers into thinking the parameter still controls behavior. Remove '
        'the argument entirely. {v1}',
    correctionMessage:
        "Remove the 'useInheritedMediaQuery' named argument. "
        'It is ignored since Flutter 3.7.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Widget classes that accepted the deprecated parameter.
  static const _targetWidgets = {
    'MaterialApp',
    'CupertinoApp',
    'WidgetsApp',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (context.isLintPluginSource) return;

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final typeName = node.constructorName.type.name.lexeme;
      if (!_targetWidgets.contains(typeName)) return;

      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression &&
            arg.name.label.name == 'useInheritedMediaQuery') {
          reporter.atNode(arg);
          return;
        }
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _RemoveUseInheritedMediaQueryFix(context: context),
  ];
}

/// Quick fix: remove the `useInheritedMediaQuery:` named argument.
class _RemoveUseInheritedMediaQueryFix extends SaropaFixProducer {
  _RemoveUseInheritedMediaQueryFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeUseInheritedMediaQuery',
    80,
    "Remove 'useInheritedMediaQuery' argument",
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Walk up to the NamedExpression
    final named =
        node is NamedExpression
            ? node
            : node.thisOrAncestorOfType<NamedExpression>();
    if (named == null) return;
    if (named.name.label.name != 'useInheritedMediaQuery') return;

    // Reuse shared utility for robust comma/whitespace deletion
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
// prefer_utf8_encode (#050)
// ─────────────────────────────────────────────────────────────────────────────

/// Flags `Utf8Encoder().convert(x)` and `const Utf8Encoder().convert(x)` and
/// suggests `utf8.encode(x)` instead.
///
/// Since: Unreleased | Rule version: v1
///
/// `utf8.encode()` from `dart:convert` is shorter and more idiomatic than
/// constructing a `Utf8Encoder` and calling `.convert()`. Since Dart SDK
/// 2.18 / Flutter 3.16 (PR #130567), `utf8.encode()` returns `Uint8List`
/// directly, making the longer form unnecessary.
///
/// **BAD:**
/// ```dart
/// import 'dart:convert';
/// final bytes = const Utf8Encoder().convert('hello');
/// final bytes2 = Utf8Encoder().convert('hello');
/// ```
///
/// **GOOD:**
/// ```dart
/// import 'dart:convert';
/// final bytes = utf8.encode('hello');
/// ```
///
/// See: https://github.com/flutter/flutter/pull/130567
class PreferUtf8EncodeRule extends SaropaLintRule {
  PreferUtf8EncodeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-convert', 'config', 'migration'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'Utf8Encoder'};

  static const LintCode _code = LintCode(
    'prefer_utf8_encode',
    '[prefer_utf8_encode] Utf8Encoder().convert(x) is verbose and '
        'unnecessary. Since Dart 2.18 / Flutter 3.16 (PR #130567), '
        'utf8.encode(x) returns Uint8List directly and is the idiomatic '
        'replacement. The Utf8Encoder constructor form adds a needless '
        'intermediate object. Prefer the shorter utf8.encode(x) call from '
        'dart:convert for clarity and consistency with Dart SDK conventions. {v1}',
    correctionMessage:
        "Replace 'Utf8Encoder().convert(x)' with 'utf8.encode(x)' "
        'from dart:convert.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (context.isLintPluginSource) return;

    // Detect: Utf8Encoder().convert(x) or const Utf8Encoder().convert(x)
    // The AST shape is a MethodInvocation where:
    //   - methodName = 'convert'
    //   - target = InstanceCreationExpression for Utf8Encoder
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'convert') return;

      final target = node.target;
      if (target is! InstanceCreationExpression) return;

      final typeName = target.constructorName.type.name.lexeme;
      if (typeName != 'Utf8Encoder') return;

      // Verify it resolves to dart:convert's Utf8Encoder
      final typeElement = target.constructorName.type.element;
      if (typeElement != null && !_isDartConvertLibrary(typeElement.library)) {
        return;
      }

      reporter.atNode(node);
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _PreferUtf8EncodeFix(context: context),
  ];
}

/// Quick fix: replace `Utf8Encoder().convert(x)` with `utf8.encode(x)`.
class _PreferUtf8EncodeFix extends SaropaFixProducer {
  _PreferUtf8EncodeFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferUtf8Encode',
    80,
    "Replace with 'utf8.encode(x)'",
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final invocation =
        node is MethodInvocation
            ? node
            : node.thisOrAncestorOfType<MethodInvocation>();
    if (invocation == null) return;
    if (invocation.methodName.name != 'convert') return;

    // Grab the arguments passed to .convert(...)
    final args = invocation.argumentList.arguments;
    if (args.isEmpty) return;
    final argText = args.map((a) => a.toSource()).join(', ');

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(invocation.offset, invocation.length),
        'utf8.encode($argText)',
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// avoid_removed_appbar_backwards_compatibility (#055)
// ─────────────────────────────────────────────────────────────────────────────

/// Flags usage of the removed `AppBar.backwardsCompatibility` parameter.
///
/// Since: Unreleased | Rule version: v1
///
/// `AppBar.backwardsCompatibility` was deprecated in Flutter 2.4 (PR #86198)
/// and removed in Flutter 3.10 (PR #120618). Code using this parameter will
/// fail to compile on Flutter 3.10+. The parameter controlled whether AppBar
/// used the legacy Material 1 styling; since Material 3 is now the default,
/// the parameter is no longer applicable.
///
/// Note: `AppBar.color` was also removed in the same PR, but `color` is too
/// generic a parameter name to lint for without false positives on unrelated
/// widgets. This rule focuses on `backwardsCompatibility` which is unique to
/// AppBar.
///
/// **BAD:**
/// ```dart
/// AppBar(
///   backwardsCompatibility: false,
///   title: Text('My App'),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// AppBar(
///   title: Text('My App'),
/// )
/// ```
///
/// See: https://github.com/flutter/flutter/pull/120618
class AvoidRemovedAppbarBackwardsCompatibilityRule extends SaropaLintRule {
  AvoidRemovedAppbarBackwardsCompatibilityRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'material', 'config', 'migration'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  bool get requiresFlutterImport => true;

  @override
  Set<String>? get requiredPatterns =>
      const <String>{'backwardsCompatibility'};

  static const LintCode _code = LintCode(
    'avoid_removed_appbar_backwards_compatibility',
    '[avoid_removed_appbar_backwards_compatibility] '
        'AppBar.backwardsCompatibility was deprecated in Flutter 2.4 '
        '(PR #86198) and removed in Flutter 3.10 (PR #120618). Code using '
        'this parameter will fail to compile on Flutter 3.10 and later. The '
        'parameter controlled whether AppBar used legacy Material 1 styling, '
        'which is no longer supported since Material 3 became the default. '
        'Remove the backwardsCompatibility argument entirely. {v1}',
    correctionMessage:
        "Remove the 'backwardsCompatibility' named argument from AppBar. "
        'It was removed in Flutter 3.10.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (context.isLintPluginSource) return;

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final typeName = node.constructorName.type.name.lexeme;
      // AppBar and SliverAppBar both accepted this parameter
      if (typeName != 'AppBar' && typeName != 'SliverAppBar') return;

      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression &&
            arg.name.label.name == 'backwardsCompatibility') {
          reporter.atNode(arg);
          return;
        }
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _RemoveAppbarBackwardsCompatibilityFix(context: context),
  ];
}

/// Quick fix: remove the `backwardsCompatibility:` named argument.
class _RemoveAppbarBackwardsCompatibilityFix extends SaropaFixProducer {
  _RemoveAppbarBackwardsCompatibilityFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeAppbarBackwardsCompatibility',
    80,
    "Remove 'backwardsCompatibility' argument",
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final named =
        node is NamedExpression
            ? node
            : node.thisOrAncestorOfType<NamedExpression>();
    if (named == null) return;
    if (named.name.label.name != 'backwardsCompatibility') return;

    // Reuse shared utility for robust comma/whitespace deletion
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
