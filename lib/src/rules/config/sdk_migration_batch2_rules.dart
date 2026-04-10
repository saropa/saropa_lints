// ignore_for_file: always_specify_types, depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/source/source_range.dart';

import '../../saropa_lint_rule.dart';

// =============================================================================
// SDK Migration Rules — Batch 2
// =============================================================================
//
// Rules sourced from plan/implementable_only_in_plugin_extension/ files
// 057, 058, 059, 069, 070, 077, 080, 081, 087, 094.

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

bool _isDartFfiLibrary(LibraryElement? lib) {
  if (lib == null) return false;
  return lib.uri.toString() == 'dart:ffi';
}

bool _isDartHtmlLibrary(LibraryElement? lib) {
  if (lib == null) return false;
  return lib.uri.toString() == 'dart:html';
}

bool _isDartIoLibrary(LibraryElement? lib) {
  if (lib == null) return false;
  return lib.uri.toString() == 'dart:io';
}

/// Extracts the [SimpleIdentifier] from an [Annotation], handling both
/// `@alwaysThrows` and `@meta.alwaysThrows` forms.
SimpleIdentifier? _annotationSimpleId(Annotation node) {
  final n = node.name;
  if (n is SimpleIdentifier) return n;
  if (n is PrefixedIdentifier) return n.identifier;
  return null;
}

bool _isMetaLibrary(LibraryElement? lib) {
  if (lib == null) return false;
  final uri = lib.uri;
  return uri.toString() == 'package:meta/meta.dart' ||
      uri.toString() == 'package:meta/meta_meta.dart';
}

// ─────────────────────────────────────────────────────────────────────────────
// #070 — prefer_isnan_over_nan_equality
// ─────────────────────────────────────────────────────────────────────────────

/// Flags `x == double.nan` (always false) and `x != double.nan` (always true).
///
/// Since: v10.10.0 | Rule version: v1
///
/// IEEE 754 defines that `NaN != NaN`, so `x == double.nan` is always `false`
/// and `x != double.nan` is always `true`. This is a common mistake that
/// silently produces the wrong result. Use `x.isNaN` instead.
///
/// **BAD:**
/// ```dart
/// if (value == double.nan) { /* never executes */ }
/// if (value != double.nan) { /* always executes */ }
/// ```
///
/// **GOOD:**
/// ```dart
/// if (value.isNaN) { /* correct NaN check */ }
/// if (!value.isNaN) { /* correct non-NaN check */ }
/// ```
///
/// See: https://github.com/flutter/flutter/pull/115424
class PreferIsNanOverNanEqualityRule extends SaropaLintRule {
  PreferIsNanOverNanEqualityRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'dart-core', 'correctness'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'nan'};

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _PreferIsNanFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_isnan_over_nan_equality',
    '[prefer_isnan_over_nan_equality] Comparing a value to double.nan with == '
        'is always false (and != is always true) because IEEE 754 defines that '
        'NaN is not equal to anything, including itself. This comparison is '
        'likely a bug that silently produces incorrect results. Use the .isNaN '
        'property instead, which correctly detects NaN values. {v1}',
    correctionMessage:
        "Replace 'x == double.nan' with 'x.isNaN' (or 'x != double.nan' "
        "with '!x.isNaN').",
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((BinaryExpression node) {
      final op = node.operator.lexeme;
      if (op != '==' && op != '!=') return;

      // Check both sides: either could be double.nan
      if (_isDoubleNan(node.rightOperand) || _isDoubleNan(node.leftOperand)) {
        reporter.atNode(node);
      }
    });
  }
}

/// True when [expr] is `double.nan`.
bool _isDoubleNan(Expression expr) {
  if (expr is PrefixedIdentifier) {
    return expr.prefix.name == 'double' && expr.identifier.name == 'nan';
  }
  if (expr is PropertyAccess) {
    final target = expr.realTarget;
    if (target is SimpleIdentifier && target.name == 'double') {
      return expr.propertyName.name == 'nan';
    }
  }
  return false;
}

/// Quick fix: replace `x == double.nan` with `x.isNaN`.
class _PreferIsNanFix extends SaropaFixProducer {
  _PreferIsNanFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferIsNanOverNanEquality',
    80,
    'Replace with .isNaN',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node is! BinaryExpression) return;

    final op = node.operator.lexeme;
    // Determine which side is the value and which is double.nan
    final Expression valueExpr;
    if (_isDoubleNan(node.rightOperand)) {
      valueExpr = node.leftOperand;
    } else if (_isDoubleNan(node.leftOperand)) {
      valueExpr = node.rightOperand;
    } else {
      return;
    }

    final valueSource = valueExpr.toSource();
    // Wrap complex expressions in parens to preserve precedence.
    // Simple identifiers and property accesses don't need wrapping.
    final needsParens = valueExpr is! SimpleIdentifier &&
        valueExpr is! PrefixedIdentifier &&
        valueExpr is! PropertyAccess;
    final wrapped = needsParens ? '($valueSource)' : valueSource;
    // x == double.nan → x.isNaN ; x != double.nan → !x.isNaN
    final replacement = op == '!=' ? '!$wrapped.isNaN' : '$wrapped.isNaN';

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(node.offset, node.length),
        replacement,
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// #058 — prefer_code_unit_at
// ─────────────────────────────────────────────────────────────────────────────

/// Flags `string.codeUnits[index]` and suggests `string.codeUnitAt(index)`.
///
/// Since: v10.10.0 | Rule version: v1
///
/// Accessing `String.codeUnits[index]` creates a new `List<int>` via the
/// `.codeUnits` getter, then indexes into it — allocating an entire list just
/// to read one code unit. `String.codeUnitAt(index)` returns the code unit
/// directly without any intermediate allocation.
///
/// **BAD:**
/// ```dart
/// final c = text.codeUnits[0];
/// if (text.codeUnits[i] == 0x0A) { }
/// ```
///
/// **GOOD:**
/// ```dart
/// final c = text.codeUnitAt(0);
/// if (text.codeUnitAt(i) == 0x0A) { }
/// ```
///
/// See: https://github.com/flutter/flutter/pull/120234
class PreferCodeUnitAtRule extends SaropaLintRule {
  PreferCodeUnitAtRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core', 'performance'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'codeUnits'};

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _PreferCodeUnitAtFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_code_unit_at',
    '[prefer_code_unit_at] Accessing String.codeUnits[index] allocates an '
        'entire List<int> via the .codeUnits getter just to read a single code '
        'unit. String.codeUnitAt(index) returns the code unit directly without '
        'any intermediate list allocation, which is both faster and produces '
        'less garbage-collection pressure. This pattern was fixed across the '
        'Flutter framework in PR #120234. {v1}',
    correctionMessage:
        "Replace 'text.codeUnits[i]' with 'text.codeUnitAt(i)'.",
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIndexExpression((IndexExpression node) {
      // target must be a property access like `expr.codeUnits`
      final target = node.target;
      if (target == null) return;

      // Check for `.codeUnits` property access
      if (target is PropertyAccess && target.propertyName.name == 'codeUnits') {
        // Verify the target receiver is a String type
        final receiverType = target.realTarget.staticType;
        if (receiverType != null && receiverType.isDartCoreString) {
          reporter.atNode(node);
        }
        return;
      }

      if (target is PrefixedIdentifier &&
          target.identifier.name == 'codeUnits') {
        final receiverType = target.prefix.staticType;
        if (receiverType != null && receiverType.isDartCoreString) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Quick fix: replace `s.codeUnits[i]` with `s.codeUnitAt(i)`.
class _PreferCodeUnitAtFix extends SaropaFixProducer {
  _PreferCodeUnitAtFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferCodeUnitAt',
    80,
    "Replace with 'codeUnitAt()'",
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node is! IndexExpression) return;

    final target = node.target;
    if (target == null) return;

    // Extract the receiver (everything before .codeUnits)
    final String receiverSource;
    if (target is PropertyAccess) {
      receiverSource = target.realTarget.toSource();
    } else if (target is PrefixedIdentifier) {
      receiverSource = target.prefix.toSource();
    } else {
      return;
    }

    if (receiverSource.isEmpty) return;

    final indexSource = node.index.toSource();
    final replacement = '$receiverSource.codeUnitAt($indexSource)';

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(node.offset, node.length),
        replacement,
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// #057 — prefer_never_over_always_throws
// ─────────────────────────────────────────────────────────────────────────────

/// Flags the deprecated `@alwaysThrows` annotation; prefer `Never` return type.
///
/// Since: v10.10.0 | Rule version: v1
///
/// The `@alwaysThrows` annotation from `package:meta` was deprecated in favor
/// of the `Never` return type introduced in Dart 2.12. Using `Never` as the
/// return type is a language-level guarantee that the function never returns
/// normally — the compiler can use this for flow analysis and dead-code
/// detection, which `@alwaysThrows` could not provide.
///
/// **BAD:**
/// ```dart
/// @alwaysThrows
/// void throwError(String message) {
///   throw ArgumentError(message);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Never throwError(String message) {
///   throw ArgumentError(message);
/// }
/// ```
///
/// See: https://github.com/flutter/engine/pull/39269
class PreferNeverOverAlwaysThrowsRule extends SaropaLintRule {
  PreferNeverOverAlwaysThrowsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core', 'migration'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'alwaysThrows'};

  static const LintCode _code = LintCode(
    'prefer_never_over_always_throws',
    '[prefer_never_over_always_throws] The @alwaysThrows annotation from '
        'package:meta is deprecated since Dart 2.12. The Never return type '
        'provides the same guarantee at the language level — functions typed '
        'as Never cannot return normally, and the compiler uses this for flow '
        'analysis and dead-code detection. @alwaysThrows is only a hint that '
        'tooling may ignore. Migrate to a Never return type for stronger '
        'guarantees. {v1}',
    correctionMessage:
        "Remove @alwaysThrows and change the return type to 'Never'.",
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addAnnotation((Annotation node) {
      // Handle both `@alwaysThrows` and `@meta.alwaysThrows`
      final id = _annotationSimpleId(node);
      if (id == null || id.name != 'alwaysThrows') return;

      // Verify it comes from package:meta, not a user-defined annotation
      final element = id.element ?? node.element;
      if (element != null && !_isMetaLibrary(element.library)) return;

      reporter.atNode(node);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// #069 — prefer_visibility_over_opacity_zero
// ─────────────────────────────────────────────────────────────────────────────

/// Flags `Opacity(opacity: 0.0, ...)` and suggests `Visibility` instead.
///
/// Since: v10.10.0 | Rule version: v1
///
/// When `Opacity` is given a literal `0` or `0.0`, the widget is fully
/// invisible but still inserts an opacity compositing layer into the render
/// tree, which is unnecessary GPU work. The `Visibility` widget (Flutter 3.7+)
/// skips the child entirely when `visible: false`, avoiding the compositing
/// overhead and reducing the render tree size.
///
/// **BAD:**
/// ```dart
/// Opacity(
///   opacity: 0.0,
///   child: Text('hidden'),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Visibility(
///   visible: false,
///   child: Text('hidden'),
/// )
/// ```
///
/// See: https://github.com/flutter/flutter/pull/112191
class PreferVisibilityOverOpacityZeroRule extends SaropaLintRule {
  PreferVisibilityOverOpacityZeroRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'performance', 'widget'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  bool get requiresFlutterImport => true;

  @override
  Set<String>? get requiredPatterns => const <String>{'Opacity'};

  static const LintCode _code = LintCode(
    'prefer_visibility_over_opacity_zero',
    '[prefer_visibility_over_opacity_zero] Using Opacity with a literal '
        'opacity of 0 or 0.0 hides the widget but still inserts an opacity '
        'compositing layer into the render tree, consuming GPU resources for '
        'nothing. The Visibility widget (available since Flutter 3.7) skips '
        'painting the child entirely when visible is false, avoiding '
        'compositing overhead and reducing the render tree. This pattern was '
        'adopted across the Flutter framework in PR #112191. {v1}',
    correctionMessage:
        "Replace 'Opacity(opacity: 0.0, child: x)' with "
        "'Visibility(visible: false, child: x)'.",
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (context.isLintPluginSource) return;

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Opacity') return;

      for (final arg in node.argumentList.arguments) {
        if (arg is! NamedExpression) continue;
        if (arg.name.label.name != 'opacity') continue;

        // Check for literal 0 or 0.0
        final expr = arg.expression;
        if (expr is IntegerLiteral && expr.value == 0) {
          reporter.atNode(node.constructorName);
          return;
        }
        if (expr is DoubleLiteral && expr.value == 0.0) {
          reporter.atNode(node.constructorName);
          return;
        }
      }
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// #094 — avoid_platform_constructor
// ─────────────────────────────────────────────────────────────────────────────

/// Flags `Platform()` constructor usage (deprecated in Dart 3.1).
///
/// Since: v10.10.0 | Rule version: v1
///
/// Since Dart 3.1, instantiating the `Platform` class is deprecated. All useful
/// members of `Platform` are static (e.g., `Platform.isAndroid`,
/// `Platform.environment`), so constructing an instance has no purpose. The
/// constructor may be removed in a future Dart release.
///
/// **BAD:**
/// ```dart
/// final platform = Platform();
/// final p = new Platform();
/// ```
///
/// **GOOD:**
/// ```dart
/// final isAndroid = Platform.isAndroid;
/// final env = Platform.environment;
/// ```
///
/// See: Dart SDK 3.1 release notes
class AvoidPlatformConstructorRule extends SaropaLintRule {
  AvoidPlatformConstructorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-io', 'migration'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'Platform'};

  static const LintCode _code = LintCode(
    'avoid_platform_constructor',
    '[avoid_platform_constructor] Instantiating the Platform class was '
        'deprecated in Dart 3.1. All useful Platform members are static '
        '(Platform.isAndroid, Platform.environment, Platform.operatingSystem, '
        'etc.), so constructing an instance serves no purpose. The constructor '
        'may be removed in a future Dart release, causing a compile failure. '
        'Use Platform static members directly instead of constructing an '
        'instance. {v1}',
    correctionMessage:
        "Remove the 'Platform()' constructor call and use static members "
        "(e.g., Platform.isAndroid) directly.",
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Platform') return;

      // Verify it resolves to dart:io Platform, not a user-defined class
      final typeElement = node.constructorName.type.element;
      if (typeElement != null && !_isDartIoLibrary(typeElement.library)) return;

      reporter.atNode(node);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// #077 — prefer_keyboard_listener_over_raw
// ─────────────────────────────────────────────────────────────────────────────

/// Flags usage of the deprecated `RawKeyboardListener` widget.
///
/// Since: v10.10.0 | Rule version: v1
///
/// `RawKeyboardListener` was deprecated in Flutter 3.18 in favor of
/// `KeyboardListener` (which wraps `Focus`). The raw keyboard API does not
/// properly handle key composition, IME input, or text editing shortcuts on
/// all platforms. `KeyboardListener` uses the newer `KeyEvent` system that
/// handles these correctly.
///
/// **BAD:**
/// ```dart
/// RawKeyboardListener(
///   focusNode: _focusNode,
///   onKey: (event) { },
///   child: child,
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// KeyboardListener(
///   focusNode: _focusNode,
///   onKeyEvent: (event) { },
///   child: child,
/// )
/// ```
///
/// See: https://github.com/flutter/flutter/pull/101537
class PreferKeyboardListenerOverRawRule extends SaropaLintRule {
  PreferKeyboardListenerOverRawRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'migration', 'widget'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  bool get requiresFlutterImport => true;

  @override
  Set<String>? get requiredPatterns => const <String>{'RawKeyboardListener'};

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _PreferKeyboardListenerFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_keyboard_listener_over_raw',
    '[prefer_keyboard_listener_over_raw] RawKeyboardListener was deprecated '
        'in Flutter 3.18 in favor of KeyboardListener. The raw keyboard API '
        'does not properly handle key composition, IME input, or text editing '
        'shortcuts on all platforms. KeyboardListener uses the newer KeyEvent '
        'system that correctly handles these cases. Migrate to '
        'KeyboardListener and update onKey callbacks to onKeyEvent. {v1}',
    correctionMessage:
        "Replace 'RawKeyboardListener' with 'KeyboardListener' and rename "
        "'onKey' to 'onKeyEvent'.",
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
      if (typeName != 'RawKeyboardListener') return;

      // Verify it resolves to Flutter's RawKeyboardListener, not a user class
      final typeElement = node.constructorName.type.element;
      if (typeElement != null) {
        final lib = typeElement.library;
        if (lib == null) return;
        final uri = lib.uri;
        // Flutter's RawKeyboardListener is in package:flutter/...
        if (!uri.isScheme('package') ||
            uri.pathSegments.isEmpty ||
            uri.pathSegments.first != 'flutter') {
          return;
        }
      }

      reporter.atNode(node.constructorName);
    });
  }
}

/// Quick fix: rename `RawKeyboardListener` to `KeyboardListener`.
class _PreferKeyboardListenerFix extends SaropaFixProducer {
  _PreferKeyboardListenerFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferKeyboardListenerOverRaw',
    80,
    "Replace with 'KeyboardListener'",
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Find the InstanceCreationExpression
    final creation = node is InstanceCreationExpression
        ? node
        : node.thisOrAncestorOfType<InstanceCreationExpression>();
    if (creation == null) return;

    final typeId = creation.constructorName.type.name;
    if (typeId.lexeme != 'RawKeyboardListener') return;

    await builder.addDartFileEdit(file, (builder) {
      // Rename widget class
      builder.addSimpleReplacement(
        SourceRange(typeId.offset, typeId.length),
        'KeyboardListener',
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// #080 — avoid_extending_html_native_class
// ─────────────────────────────────────────────────────────────────────────────

/// Flags extending native `dart:html` classes that can no longer be subclassed.
///
/// Since: v10.10.0 | Rule version: v1
///
/// Dart 3.8 made native classes in `dart:html` (like `HtmlElement`,
/// `HtmlDocument`, `CanvasElement`, etc.) non-extensible. Code that extends
/// these classes will fail at compile time. Migrate to composition or use
/// the `dart:js_interop` APIs instead.
///
/// **BAD:**
/// ```dart
/// class MyElement extends HtmlElement { }
/// class MyCanvas extends CanvasElement { }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyElement {
///   final HtmlElement _element;
///   MyElement(this._element);
/// }
/// ```
///
/// See: Dart SDK 3.8 release notes
class AvoidExtendingHtmlNativeClassRule extends SaropaLintRule {
  AvoidExtendingHtmlNativeClassRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'dart-html', 'breaking-change'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{
    'HtmlElement',
    'HtmlDocument',
    'CanvasElement',
    'DivElement',
    'SpanElement',
    'InputElement',
    'ButtonElement',
    'AnchorElement',
    'ImageElement',
  };

  static const LintCode _code = LintCode(
    'avoid_extending_html_native_class',
    '[avoid_extending_html_native_class] Native classes from dart:html (such '
        'as HtmlElement, HtmlDocument, CanvasElement, DivElement, '
        'SpanElement, etc.) can no longer be extended as of Dart 3.8. This is '
        'a breaking change — code extending these classes will fail at compile '
        'time. Migrate to composition (wrap the native element in a plain '
        'class) or use the dart:js_interop APIs for custom element '
        'definitions. {v1}',
    correctionMessage:
        'Replace class extension with composition: hold a reference to the '
        'native element as a field instead of extending it.',
    severity: DiagnosticSeverity.ERROR,
  );

  /// Well-known native `dart:html` classes that cannot be extended.
  static const Set<String> _htmlNativeClasses = <String>{
    'HtmlElement',
    'HtmlDocument',
    'CanvasElement',
    'DivElement',
    'SpanElement',
    'InputElement',
    'ButtonElement',
    'AnchorElement',
    'ImageElement',
    'SelectElement',
    'TextAreaElement',
    'FormElement',
    'TableElement',
    'IFrameElement',
    'VideoElement',
    'AudioElement',
    'Element',
    'Node',
    'Document',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check extends clause
      final extendsClause = node.extendsClause;
      if (extendsClause != null) {
        final superName = extendsClause.superclass.name.lexeme;
        if (_htmlNativeClasses.contains(superName)) {
          final superElement = extendsClause.superclass.element;
          if (superElement == null ||
              _isDartHtmlLibrary(superElement.library)) {
            reporter.atNode(extendsClause.superclass);
            return;
          }
        }
      }

      // Check implements clause — implementing native dart:html classes is
      // also invalid after Dart 3.8.
      final implementsClause = node.implementsClause;
      if (implementsClause == null) return;
      for (final iface in implementsClause.interfaces) {
        if (!_htmlNativeClasses.contains(iface.name.lexeme)) continue;
        final el = iface.element;
        if (el == null || _isDartHtmlLibrary(el.library)) {
          reporter.atNode(iface);
          return;
        }
      }
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// #081 — avoid_extending_security_context
// ─────────────────────────────────────────────────────────────────────────────

/// Flags extending `SecurityContext` which is now `final` in Dart 3.5.
///
/// Since: v10.10.0 | Rule version: v1
///
/// Dart 3.5 made `SecurityContext` from `dart:io` a `final` class. Code that
/// extends or implements `SecurityContext` will fail at compile time. Use
/// composition instead: hold a `SecurityContext` reference and delegate calls.
///
/// **BAD:**
/// ```dart
/// class MySecurityContext extends SecurityContext { }
/// class MockSecurityContext implements SecurityContext { }
/// ```
///
/// **GOOD:**
/// ```dart
/// class TlsConfig {
///   final SecurityContext _context;
///   TlsConfig() : _context = SecurityContext();
///   void useCertificate(String path) => _context.useCertificateChain(path);
/// }
/// ```
///
/// See: Dart SDK 3.5 breaking change #55786
class AvoidExtendingSecurityContextRule extends SaropaLintRule {
  AvoidExtendingSecurityContextRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'dart-io', 'breaking-change'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'SecurityContext'};

  static const LintCode _code = LintCode(
    'avoid_extending_security_context',
    '[avoid_extending_security_context] SecurityContext from dart:io was made '
        'final in Dart 3.5 (breaking change #55786). It can no longer be '
        'extended or implemented. Code that subclasses SecurityContext will '
        'fail at compile time. Use composition instead — hold a '
        'SecurityContext reference as a field and delegate calls through it. '
        'For testing, consider using IOOverrides or creating a wrapper class '
        'with a SecurityContext field. {v1}',
    correctionMessage:
        'Replace class extension/implementation with composition: hold a '
        'SecurityContext field and delegate method calls.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check extends clause
      final extendsClause = node.extendsClause;
      if (extendsClause != null) {
        final superName = extendsClause.superclass.name.lexeme;
        if (superName == 'SecurityContext') {
          final el = extendsClause.superclass.element;
          if (el == null || _isDartIoLibrary(el.library)) {
            reporter.atNode(extendsClause.superclass);
            return;
          }
        }
      }

      // Check implements clause
      final implementsClause = node.implementsClause;
      if (implementsClause == null) return;
      for (final iface in implementsClause.interfaces) {
        if (iface.name.lexeme != 'SecurityContext') continue;
        final el = iface.element;
        if (el == null || _isDartIoLibrary(el.library)) {
          reporter.atNode(iface);
          return;
        }
      }
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// #087 — avoid_deprecated_pointer_arithmetic
// ─────────────────────────────────────────────────────────────────────────────

/// Flags deprecated `Pointer.elementAt()` and `Pointer.offsetBy()` in dart:ffi.
///
/// Since: v10.10.0 | Rule version: v1
///
/// Dart 3.3 deprecated `Pointer.elementAt(index)` in favor of the `+` operator
/// and `Pointer.offsetBy(bytes)` in favor of pointer arithmetic. The operator
/// syntax is more concise and consistent with C-style pointer arithmetic that
/// FFI users expect.
///
/// **BAD:**
/// ```dart
/// final next = ptr.elementAt(5);
/// final raw = ptr.offsetBy(16);
/// ```
///
/// **GOOD:**
/// ```dart
/// final next = ptr + 5;
/// final raw = Pointer.fromAddress(ptr.address + 16);
/// ```
///
/// See: Dart SDK 3.3 release notes
class AvoidDeprecatedPointerArithmeticRule extends SaropaLintRule {
  AvoidDeprecatedPointerArithmeticRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-ffi', 'migration'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'elementAt'};

  static const LintCode _code = LintCode(
    'avoid_deprecated_pointer_arithmetic',
    '[avoid_deprecated_pointer_arithmetic] Pointer.elementAt() was deprecated '
        'in Dart 3.3 in favor of the + operator (e.g., ptr + 5 instead of '
        'ptr.elementAt(5)). The operator syntax is more concise and consistent '
        'with C-style pointer arithmetic that FFI users expect. This also '
        'applies to Array.elementAt() which was deprecated in favor of the '
        '[] operator. Migrate to operator syntax before the deprecated methods '
        'are removed. {v1}',
    correctionMessage:
        "Replace 'ptr.elementAt(n)' with 'ptr + n'.",
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _PointerArithmeticFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final methodName = node.methodName.name;
      if (methodName != 'elementAt') return;

      // Check if the target type is a Pointer from dart:ffi
      final targetType = node.realTarget?.staticType;
      if (targetType == null) return;
      if (targetType is! InterfaceType) return;

      // Check for Pointer or any subtype of Pointer from dart:ffi
      final classElement = targetType.element;
      if (_isFfiPointerType(classElement)) {
        reporter.atNode(node);
      }
    });
  }
}

bool _isFfiPointerType(InterfaceElement element) {
  if (element.name == 'Pointer' && _isDartFfiLibrary(element.library)) {
    return true;
  }
  // Check supertypes for Pointer
  for (final sup in element.allSupertypes) {
    if (sup.element.name == 'Pointer' && _isDartFfiLibrary(sup.element.library)) {
      return true;
    }
  }
  return false;
}

/// Quick fix: replace `ptr.elementAt(n)` with `ptr + n`.
class _PointerArithmeticFix extends SaropaFixProducer {
  _PointerArithmeticFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.avoidDeprecatedPointerArithmetic',
    80,
    "Replace with 'ptr + n'",
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node is! MethodInvocation) return;
    if (node.methodName.name != 'elementAt') return;

    final target = node.realTarget;
    if (target == null) return;
    final args = node.argumentList.arguments;
    if (args.length != 1) return;

    final targetSource = target.toSource();
    final argSource = args.first.toSource();

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(node.offset, node.length),
        '$targetSource + $argSource',
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// #059 — prefer_extracting_repeated_map_lookup
// ─────────────────────────────────────────────────────────────────────────────

/// Flags repeated identical map lookups within the same function body.
///
/// Since: v10.10.0 | Rule version: v1
///
/// Accessing the same map key multiple times (e.g., `map['key']` used 3+
/// times) is both a readability issue and a minor performance concern — each
/// access performs a hash lookup. Extracting the value into a local variable
/// is more readable, type-safe (the local can be non-nullable via `!` or
/// null-check), and avoids redundant hash lookups.
///
/// The rule flags the **third and subsequent** accesses to the same
/// `target[key]` pattern within a single function/method body. The first
/// two accesses are not flagged since occasional duplicate access is normal.
///
/// **BAD:**
/// ```dart
/// void process(Map<String, int> config) {
///   print(config['timeout']);
///   print(config['timeout']);
///   print(config['timeout']); // 3rd+ access flagged
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void process(Map<String, int> config) {
///   final timeout = config['timeout'];
///   print(timeout);
///   print(timeout);
///   print(timeout);
/// }
/// ```
///
/// See: https://github.com/flutter/flutter/pull/122178
class PreferExtractingRepeatedMapLookupRule extends SaropaLintRule {
  PreferExtractingRepeatedMapLookupRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'performance', 'readability'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_extracting_repeated_map_lookup',
    '[prefer_extracting_repeated_map_lookup] The same map key is accessed '
        '3 or more times in this function body. Each access performs a hash '
        'lookup and returns a nullable type, forcing repeated null handling. '
        'Extracting the value into a local variable improves readability, '
        'is more type-safe (the local can be non-nullable), and avoids '
        'redundant hash computations. This pattern was cleaned up across the '
        'Flutter framework in PR #122178. {v1}',
    correctionMessage:
        'Extract the map lookup into a local variable and reference it '
        'instead of repeating the lookup.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Scan each function/method body for repeated index expressions
    context.addBlockFunctionBody((BlockFunctionBody body) {
      _checkBlockForRepeatedLookups(body.block, reporter);
    });
  }
}

void _checkBlockForRepeatedLookups(
  Block block,
  SaropaDiagnosticReporter reporter,
) {
  // Collect all index expressions within this block
  final lookupCounts = <String, List<IndexExpression>>{};

  // Walk the block's statements to find index expressions
  block.visitChildren(_IndexExpressionCollector(lookupCounts));

  // Report the 3rd+ occurrences
  for (final entry in lookupCounts.entries) {
    final nodes = entry.value;
    if (nodes.length < 3) continue;
    // Flag from the 3rd occurrence onward
    for (var i = 2; i < nodes.length; i++) {
      reporter.atNode(nodes[i]);
    }
  }
}

/// Visitor that collects `target[key]` index expressions into a map keyed by
/// their normalized source representation.
class _IndexExpressionCollector extends RecursiveAstVisitor<void> {
  _IndexExpressionCollector(this._lookups);

  final Map<String, List<IndexExpression>> _lookups;

  @override
  void visitIndexExpression(IndexExpression node) {
    super.visitIndexExpression(node);

    final target = node.target;
    if (target == null) return;

    // Only flag map lookups where the key is a simple literal or identifier
    final index = node.index;
    if (index is! SimpleStringLiteral &&
        index is! IntegerLiteral &&
        index is! SimpleIdentifier) {
      return;
    }

    // Build a canonical key from the source text
    final key = '${target.toSource()}[${index.toSource()}]';
    _lookups.putIfAbsent(key, () => <IndexExpression>[]).add(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Don't descend into nested functions — each has its own scope
  }
}
