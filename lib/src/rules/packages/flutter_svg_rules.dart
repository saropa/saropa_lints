// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// flutter_svg package lint rules for Flutter applications.
///
/// These rules cover flutter_svg 2.x migration (deprecated `color` /
/// `colorBlendMode` → `colorFilter`) and correctness/UX best practices for
/// `SvgPicture` (error handlers, loading placeholders, accessibility labels).
///
/// Import gate: every rule checks `fileImportsPackage(node,
/// PackageImports.flutterSvg)` before reporting, so rules are silent on files
/// that do not import `package:flutter_svg/`.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

// =============================================================================
// Internal helpers — SvgPicture constructor matching
// =============================================================================

/// Named constructors on `SvgPicture` that these rules care about.
const Set<String> _svgPictureConstructors = <String>{
  'asset',
  'network',
  'string',
  'memory',
  'file',
};

/// True when [node] is an `InstanceCreationExpression` whose constructor
/// resolves to `SvgPicture` from `package:flutter_svg`.
///
/// The check is two-layered:
/// 1. The constructor's enclosing type name must be `SvgPicture` (syntactic —
///    fast, avoids the expensive element-resolution path).
/// 2. The file must import `package:flutter_svg/` (import-gate).
///
/// This combination prevents false positives on any other widget that happens
/// to carry a matching constructor name or argument name (e.g. `Icon(color:)`,
/// `Container(color:)`, `Text(…)`).
bool _isSvgPictureNode(InstanceCreationExpression node) {
  final typeName = node.constructorName.type.name.lexeme;
  if (typeName != 'SvgPicture') return false;
  // Named constructor (SvgPicture.asset / .network / etc.) or default ctor.
  final constructorName = node.constructorName.name?.name;
  // Allow the default constructor and all named ones in the known set.
  if (constructorName != null &&
      !_svgPictureConstructors.contains(constructorName)) {
    return false;
  }
  return fileImportsPackage(node, PackageImports.flutterSvg);
}

/// True when the named argument list of [node] contains an argument named
/// [name].
bool _hasNamedArg(InstanceCreationExpression node, String name) {
  for (final arg in node.argumentList.arguments) {
    if (arg is NamedExpression && arg.name.label.name == name) return true;
  }
  return false;
}

/// Returns the [NamedExpression] for [name], or null if absent.
NamedExpression? _namedArg(InstanceCreationExpression node, String name) {
  for (final arg in node.argumentList.arguments) {
    if (arg is NamedExpression && arg.name.label.name == name) return arg;
  }
  return null;
}

/// Returns the literal double value of a named argument if it is a simple
/// integer or double literal (used for the width/height-zero guard).
double? _literalDouble(InstanceCreationExpression node, String argName) {
  final arg = _namedArg(node, argName);
  if (arg == null) return null;
  final expr = arg.expression;
  if (expr is IntegerLiteral) return expr.value?.toDouble();
  if (expr is DoubleLiteral) return expr.value;
  return null;
}

/// Returns the [SourceRange] covering [named] plus its surrounding comma.
///
/// Mirrors the comma-handling in `RemoveNamedArgumentFix`: prefers consuming
/// the trailing comma so the remaining arguments stay valid; falls back to the
/// leading comma when the argument is last. Returns null when the range cannot
/// be computed safely.
SourceRange? _namedArgDeletionRange(NamedExpression named) {
  int start = named.offset;
  int end = named.end;

  final Token? next = named.endToken.next;
  if (next != null && next.type == TokenType.COMMA) {
    end = next.end;
  } else {
    final Token? prev = named.beginToken.previous;
    if (prev != null && prev.type == TokenType.COMMA) {
      start = prev.offset;
    }
  }

  if (start < 0 || end <= start) return null;
  return SourceRange(start, end - start);
}

// =============================================================================
// prefer_svg_color_filter  (migration rule — WARNING)
// =============================================================================

/// Warns when a `SvgPicture.*` constructor uses the deprecated `color:` or
/// `colorBlendMode:` parameters that were replaced by `colorFilter:` in
/// flutter_svg 2.0.0.
///
/// Since: v4.16.0 | Rule version: v1
///
/// flutter_svg 2.0 deprecated `color` and `colorBlendMode` in favor of a
/// single `colorFilter` parameter. The deprecated parameters still compile on
/// 2.x but will be removed in a future release.
///
/// **BAD:**
/// ```dart
/// SvgPicture.asset('icon.svg', color: Colors.red,
///     colorBlendMode: BlendMode.srcIn)
/// ```
///
/// **GOOD:**
/// ```dart
/// SvgPicture.asset('icon.svg',
///     colorFilter: const ColorFilter.mode(Colors.red, BlendMode.srcIn))
/// ```
class PreferSvgColorFilterRule extends SaropaLintRule {
  PreferSvgColorFilterRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  // Quick-scan gate: skip files that never mention the deprecated parameters.
  @override
  Set<String>? get requiredPatterns => const <String>{'color'};

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _PreferSvgColorFilterFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_svg_color_filter',
    '[prefer_svg_color_filter] SvgPicture uses the deprecated "color" or "colorBlendMode" parameters that were replaced by the "colorFilter" parameter in flutter_svg 2.0.0. These deprecated parameters still compile on 2.x but will be removed in a future release. Replace them with a single "colorFilter: ColorFilter.mode(color, blendMode)" argument. If "colorBlendMode" is absent the default BlendMode.srcIn applies. A nullable color expression cannot be migrated mechanically because ColorFilter.mode does not accept null — review the call site and supply a non-null color or guard the call. {v1}',
    correctionMessage:
        'Replace "color: c, colorBlendMode: m" with '
        '"colorFilter: ColorFilter.mode(c, m)". '
        'If colorBlendMode is absent, use BlendMode.srcIn as the default. '
        'A nullable color expression requires a manual null-guard before migration.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!_isSvgPictureNode(node)) return;

      final colorArg = _namedArg(node, 'color');
      // colorBlendMode alone (without color) is also a migration target.
      final blendArg = _namedArg(node, 'colorBlendMode');

      if (colorArg == null && blendArg == null) return;

      reporter.atNode(node);
    });
  }
}

/// Quick fix for [PreferSvgColorFilterRule].
///
/// Removes `color:` (and `colorBlendMode:` if present) from the argument list
/// and inserts `colorFilter: ColorFilter.mode(<colorExpr>, <blendExpr>)` (or
/// `BlendMode.srcIn` when `colorBlendMode` was absent).
///
/// The fix is skipped when:
/// - `color:` is absent (colorBlendMode-only — no mechanical color to place).
/// - The color expression is not a simple non-null expression (nullable
///   variable, conditional, method call returning nullable) — the caller must
///   supply a null-guard first.
class _PreferSvgColorFilterFix extends SaropaFixProducer {
  _PreferSvgColorFilterFix({required super.context});

  @override
  FixKind get fixKind => FixKind(
    'saropa.fix.preferSvgColorFilter',
    80,
    'Replace deprecated color/colorBlendMode with colorFilter',
  );

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Walk up to the InstanceCreationExpression.
    AstNode? current = node;
    while (current != null && current is! InstanceCreationExpression) {
      current = current.parent;
    }
    if (current is! InstanceCreationExpression) return;
    if (!_isSvgPictureNode(current)) return;

    final colorArg = _namedArg(current, 'color');
    if (colorArg == null) return; // colorBlendMode-only: no mechanical fix.

    final blendArg = _namedArg(current, 'colorBlendMode');

    // Reject non-provably-non-null color expressions: nullable types,
    // conditional expressions, and null-aware operators are not safe.
    final colorExpr = colorArg.expression;

    // Simple heuristic: trust constructor calls, prefixed/property accesses,
    // simple identifiers, and method invocations; reject anything else (e.g.
    // conditional, null-aware) to avoid emitting a broken fix.
    final bool probablyNonNull =
        colorExpr is InstanceCreationExpression ||
        colorExpr is PrefixedIdentifier ||
        colorExpr is PropertyAccess ||
        colorExpr is SimpleIdentifier ||
        colorExpr is MethodInvocation;
    if (!probablyNonNull) return;

    // Determine constness: preserve `const` when the color is a const
    // constructor and the blend operand is a static enum accessor (both sides
    // are const-eligible).
    final bool colorIsConst =
        colorExpr is InstanceCreationExpression &&
        colorExpr.keyword?.lexeme == 'const';
    final bool blendIsConst =
        blendArg == null ||
        blendArg.expression is PrefixedIdentifier ||
        blendArg.expression is SimpleIdentifier;
    final bool useConst = colorIsConst && blendIsConst;

    final String blendSrc =
        blendArg?.expression.toSource() ?? 'BlendMode.srcIn';
    final String colorSrc = colorExpr.toSource();
    final String constKw = useConst ? 'const ' : '';
    final String colorFilterSrc =
        '${constKw}ColorFilter.mode($colorSrc, $blendSrc)';

    await builder.addDartFileEdit(file, (b) {
      // Replace color: <expr> → colorFilter: ColorFilter.mode(...)
      b.addSimpleReplacement(
        colorArg.sourceRange,
        'colorFilter: $colorFilterSrc',
      );

      // Remove colorBlendMode: <expr> if present using token-based deletion.
      if (blendArg != null) {
        final range = _namedArgDeletionRange(blendArg);
        if (range != null) b.addDeletion(range);
      }
    });
  }
}

// =============================================================================
// svg_network_missing_error_builder  (correctness — WARNING)
// =============================================================================

/// Warns when `SvgPicture.network(...)` has no `errorBuilder:` argument.
///
/// Since: v4.16.0 | Rule version: v1
///
/// Without `errorBuilder:`, a failed network request or non-SVG response
/// renders nothing and provides no user signal. `placeholderBuilder:` only
/// shows while loading and does NOT cover the error case.
///
/// **BAD:**
/// ```dart
/// SvgPicture.network('https://example.com/icon.svg')
/// ```
///
/// **GOOD:**
/// ```dart
/// SvgPicture.network(
///   'https://example.com/icon.svg',
///   errorBuilder: (context, error, stackTrace) =>
///       const Icon(Icons.broken_image),
/// )
/// ```
class SvgNetworkMissingErrorBuilderRule extends SaropaLintRule {
  SvgNetworkMissingErrorBuilderRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'svg_network_missing_error_builder',
    '[svg_network_missing_error_builder] SvgPicture.network is called without an "errorBuilder" argument. When the network request fails or returns a non-SVG body the widget renders nothing, giving users no visual signal that content is missing. The "placeholderBuilder" parameter only shows during loading and does NOT cover the error case. Added in flutter_svg 2.0.17. Provide an "errorBuilder" to show a fallback widget and make failures visible. {v1}',
    correctionMessage:
        'Add errorBuilder: (context, error, stackTrace) => const SizedBox.shrink() '
        'and replace the stub with a meaningful fallback widget.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!_isSvgPictureNode(node)) return;
      if (node.constructorName.name?.name != 'network') return;
      if (_hasNamedArg(node, 'errorBuilder')) return;

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// svg_network_missing_placeholder  (UX — INFO)
// =============================================================================

/// Warns when `SvgPicture.network(...)` has no `placeholderBuilder:` argument.
///
/// Since: v4.16.0 | Rule version: v1
///
/// Network SVGs load asynchronously. Without a `placeholderBuilder:` the widget
/// renders blank/transparent until the first frame arrives, which is
/// indistinguishable from a broken layout on slow or offline connections.
///
/// The rule is skipped when both `width: 0` and `height: 0` are present —
/// that signals an intentionally invisible placeholder widget.
///
/// **BAD:**
/// ```dart
/// SvgPicture.network('https://example.com/icon.svg')
/// ```
///
/// **GOOD:**
/// ```dart
/// SvgPicture.network(
///   'https://example.com/icon.svg',
///   placeholderBuilder: (context) => const CircularProgressIndicator(),
/// )
/// ```
class SvgNetworkMissingPlaceholderRule extends SaropaLintRule {
  SvgNetworkMissingPlaceholderRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'svg_network_missing_placeholder',
    '[svg_network_missing_placeholder] SvgPicture.network is called without a "placeholderBuilder" argument. Because the SVG is fetched asynchronously the widget renders an empty transparent space until the first frame arrives. On slow or offline connections this blank area is visible for a noticeable duration and is indistinguishable from a broken layout. Provide a "placeholderBuilder" to show a loading indicator or skeleton. Suppressed when both width and height are literal zero (intentionally invisible widget). {v1}',
    correctionMessage:
        'Add placeholderBuilder: (context) => const SizedBox.shrink() '
        'and replace the stub with a suitable loading widget.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!_isSvgPictureNode(node)) return;
      if (node.constructorName.name?.name != 'network') return;
      if (_hasNamedArg(node, 'placeholderBuilder')) return;

      // Skip intentionally invisible widgets (width: 0, height: 0).
      final width = _literalDouble(node, 'width');
      final height = _literalDouble(node, 'height');
      if (width == 0.0 && height == 0.0) return;

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// svg_missing_semantics_label  (a11y — INFO — report-only)
// =============================================================================

/// Warns when any `SvgPicture.*` constructor provides neither a non-empty
/// `semanticsLabel:` nor `excludeFromSemantics: true`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// SVGs are opaque to screen readers unless annotated. An unlabeled but
/// semantics-included node still pollutes the accessibility tree with an empty
/// description — VoiceOver / TalkBack users receive no context. Decorative
/// SVGs must explicitly opt out via `excludeFromSemantics: true`.
///
/// **No quick fix** — inserting an empty string + TODO comment is a banned
/// no-op fix. The developer must supply a meaningful label or the explicit
/// exclusion.
///
/// **BAD:**
/// ```dart
/// SvgPicture.asset('icon.svg') // no label, no exclusion
/// ```
///
/// **GOOD:**
/// ```dart
/// // Informative SVG — provide a label.
/// SvgPicture.asset('icon.svg', semanticsLabel: 'Company logo')
///
/// // Decorative SVG — explicitly exclude.
/// SvgPicture.asset('icon.svg', excludeFromSemantics: true)
/// ```
class SvgMissingSemanticsLabelRule extends SaropaLintRule {
  SvgMissingSemanticsLabelRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'svg_missing_semantics_label',
    '[svg_missing_semantics_label] SvgPicture is used without either a "semanticsLabel" argument or "excludeFromSemantics: true". SVGs are opaque to screen readers — without annotation VoiceOver and TalkBack receive an empty accessibility node with no description, giving users with visual impairments no context. Informative SVGs must have a non-empty semanticsLabel describing the image content. Decorative SVGs that should be invisible to assistive technology must set excludeFromSemantics: true explicitly. {v1}',
    correctionMessage:
        'For informative SVGs add semanticsLabel: "Describe this image here". '
        'For decorative SVGs that should not appear in the accessibility tree '
        'add excludeFromSemantics: true.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!_isSvgPictureNode(node)) return;

      // Suppress when explicitly excluded from semantics (decorative SVG).
      final excludeArg = _namedArg(node, 'excludeFromSemantics');
      if (excludeArg != null) {
        final val = excludeArg.expression;
        // BooleanLiteral true → legitimately decorative, skip.
        if (val is BooleanLiteral && val.value) return;
      }

      // Suppress when a semanticsLabel is present and is not an empty literal.
      final labelArg = _namedArg(node, 'semanticsLabel');
      if (labelArg != null) {
        final val = labelArg.expression;
        // Any non-literal expression (variable, method call) is trusted.
        if (val is! StringLiteral) return;
        final strVal = val.stringValue;
        // Non-empty string literal → OK.
        if (strVal != null && strVal.isNotEmpty) return;
        // Empty string literal '' falls through and is reported.
      }

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// svg_string_missing_error_builder  (correctness — WARNING / INFO)
// =============================================================================

/// Warns when `SvgPicture.string(...)` has no `errorBuilder:` argument.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `SvgPicture.string` decodes raw SVG markup at runtime. A malformed,
/// truncated, or unsupported SVG will throw during parsing; without
/// `errorBuilder:` the exception propagates as an unhandled widget build error
/// and the subtree is dropped.
///
/// Severity is WARNING when the string argument is dynamic (variable, method
/// call, interpolation — evidence of external input) and INFO when it is a
/// compile-time string literal (content fixed at write time, lower risk).
///
/// **BAD:**
/// ```dart
/// SvgPicture.string(dynamicSvg) // dynamic — WARNING
/// SvgPicture.string('<svg>…</svg>') // literal — INFO
/// ```
///
/// **GOOD:**
/// ```dart
/// SvgPicture.string(
///   dynamicSvg,
///   errorBuilder: (context, error, stackTrace) =>
///       const Icon(Icons.broken_image),
/// )
/// ```
class SvgStringMissingErrorBuilderRule extends SaropaLintRule {
  SvgStringMissingErrorBuilderRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'svg_string_missing_error_builder',
    '[svg_string_missing_error_builder] SvgPicture.string is called without an "errorBuilder" argument. The string is decoded as SVG markup at runtime; a malformed, truncated, or unsupported SVG throws during parsing and the widget subtree is dropped without any user-visible fallback. When the string is dynamic (a variable, method call, or interpolation) this is especially likely because the content is not verified at compile time. Provide an "errorBuilder" to degrade gracefully. Severity is WARNING for dynamic inputs and INFO for compile-time string literals. {v1}',
    correctionMessage:
        'Add errorBuilder: (context, error, stackTrace) => const SizedBox.shrink() '
        'and replace the stub with a meaningful fallback widget.',
    severity: DiagnosticSeverity.WARNING,
  );

  // INFO variant used when the first positional argument is a string literal
  // (lower risk — content is fixed at compile time).
  static const LintCode _infoCode = LintCode(
    'svg_string_missing_error_builder',
    '[svg_string_missing_error_builder] SvgPicture.string is called without an "errorBuilder" argument. The string is decoded as SVG markup at runtime; a malformed, truncated, or unsupported SVG throws during parsing and the widget subtree is dropped without any user-visible fallback. When the string is dynamic (a variable, method call, or interpolation) this is especially likely because the content is not verified at compile time. Provide an "errorBuilder" to degrade gracefully. Severity is WARNING for dynamic inputs and INFO for compile-time string literals. {v1}',
    correctionMessage:
        'Add errorBuilder: (context, error, stackTrace) => const SizedBox.shrink() '
        'and replace the stub with a meaningful fallback widget.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!_isSvgPictureNode(node)) return;
      if (node.constructorName.name?.name != 'string') return;
      if (_hasNamedArg(node, 'errorBuilder')) return;

      // Narrow severity: literal string → INFO, dynamic → WARNING.
      final firstPositional = _firstPositionalArg(node);
      final bool isLiteral = firstPositional is StringLiteral;

      // The rule's `code` field uses WARNING; emit the INFO variant for literals.
      if (isLiteral) {
        reporter.atNode(node, _infoCode);
      } else {
        reporter.atNode(node);
      }
    });
  }

  /// Returns the first positional (non-named) argument, or null.
  Expression? _firstPositionalArg(InstanceCreationExpression node) {
    for (final arg in node.argumentList.arguments) {
      if (arg is! NamedExpression) return arg;
    }
    return null;
  }
}

/// Warns when SvgPicture lacks errorBuilder callback.
///
/// Since: v2.2.0 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: svg_error_handler, require_svg_error_builder
///
/// SVG loading can fail for various reasons. Without an error builder,
/// the UI may break or show nothing when an SVG fails to load.
///
/// **BAD:**
/// ```dart
/// SvgPicture.asset('assets/icon.svg')
/// SvgPicture.network('https://example.com/icon.svg')
/// ```
///
/// **GOOD:**
/// ```dart
/// SvgPicture.asset(
///   'assets/icon.svg',
///   placeholderBuilder: (context) => CircularProgressIndicator(),
///   errorBuilder: (context, error, stackTrace) => Icon(Icons.error),
/// )
/// ```
class RequireSvgErrorHandlerRule extends SaropaLintRule {
  RequireSvgErrorHandlerRule() : super(code: _code);

  // Medium impact - UI fallback, not crash-causing
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_svg_error_handler',
    '[require_svg_error_handler] SvgPicture without errorBuilder shows blank on invalid SVG. SVG loading can fail for various reasons. Without an error builder, the UI may break or show nothing when an SVG fails to load. {v3}',
    correctionMessage:
        'Add errorBuilder to handle SVG loading failures. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      // Check for SvgPicture factory constructors
      final String? target = node.target?.toSource();
      if (target != 'SvgPicture') return;

      final String methodName = node.methodName.name;
      if (methodName != 'asset' &&
          methodName != 'network' &&
          methodName != 'file' &&
          methodName != 'memory') {
        return;
      }

      // Check for errorBuilder parameter
      final bool hasErrorBuilder = node.argumentList.arguments.any((
        Expression arg,
      ) {
        if (arg is NamedExpression) {
          return arg.name.label.name == 'errorBuilder';
        }
        return false;
      });

      if (!hasErrorBuilder) {
        reporter.atNode(node);
      }
    });
  }
}
