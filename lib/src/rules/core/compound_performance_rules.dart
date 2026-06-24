// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Compound (context-aware) performance rules for Flutter applications.
///
/// These rules flag GPU- and layer-expensive widgets ONLY when they appear
/// inside a parent context that makes the cost recur every frame or every
/// scrolled item — e.g. `Opacity` inside `AnimatedBuilder`, or `BackdropFilter`
/// inside a scrollable. A bare `Opacity` or `ClipPath` used once in a static
/// tree is cheap and is deliberately NOT reported: presence alone is not a
/// defect. The defect is the *combination*. This avoids the false-positive
/// flood that comes from flagging every occurrence of an expensive widget.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../saropa_lint_rule.dart';
import 'compound_performance_patterns.dart';

/// Shared base for "expensive widget inside a costly parent" rules.
///
/// A subclass declares the costly child widgets it watches ([costlyWidgets])
/// and the parent contexts that make them a problem ([problematicParents]).
/// The detection — find the construction, confirm an offending ancestor, report
/// at the child node — is identical across every compound rule, so it lives
/// here once instead of being copied per widget/parent pair (which is exactly
/// the near-duplicate sprawl these rules are meant to replace).
abstract class _CompoundPerformanceRule extends SaropaLintRule {
  _CompoundPerformanceRule(LintCode code) : super(code: code);

  /// Type names of the costly child widget(s) this rule flags.
  Set<String> get costlyWidgets;

  /// Ancestor widget types that turn the costly child into a per-frame or
  /// per-item hazard.
  Set<String> get problematicParents;

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'performance', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // The same widget construction is an InstanceCreationExpression under a
    // resolved tree (IDE / `dart analyze`) but a target-less MethodInvocation
    // under an unresolved tree (the `scan` CLI uses `parseString`). The two
    // forms never occur for the same node simultaneously, so registering both
    // makes the rule behave identically in every host without double-reporting.
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? name = widgetConstructionName(node);
      if (name != null) _reportIfNested(reporter, node, name);
    });

    context.addMethodInvocation((MethodInvocation node) {
      // A widget constructor in an unresolved tree parses as `Foo(...)` with no
      // target; a genuine `obj.method()` call has a target and is not a widget.
      if (node.target != null) return;
      _reportIfNested(reporter, node, node.methodName.name);
    });
  }

  /// Reports [node] when [widgetName] is one of the costly widgets and it sits
  /// inside one of the [problematicParents].
  void _reportIfNested(
    SaropaDiagnosticReporter reporter,
    AstNode node,
    String widgetName,
  ) {
    if (!costlyWidgets.contains(widgetName)) return;
    if (enclosingWidgetOfType(node, problematicParents) != null) {
      reporter.atNode(node);
    }
  }
}

/// Flags `Opacity` rebuilt on every animation tick inside `AnimatedBuilder`.
///
/// Since: v5.x | Rule version: v1
///
/// `Opacity` with a value strictly between 0 and 1 allocates an offscreen
/// layer (`saveLayer`). Inside an `AnimatedBuilder` it is re-laid-out and
/// re-composited on every frame of the animation, which is one of the most
/// common sources of animation jank.
///
/// **BAD:**
/// ```dart
/// AnimatedBuilder(
///   animation: controller,
///   builder: (context, child) => Opacity(
///     opacity: controller.value,
///     child: child,
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// FadeTransition(opacity: controller, child: child)
/// ```
class AvoidOpacityInAnimatedBuilderRule extends _CompoundPerformanceRule {
  AvoidOpacityInAnimatedBuilderRule() : super(_code);

  static const LintCode _code = LintCode(
    'avoid_opacity_in_animated_builder',
    '[avoid_opacity_in_animated_builder] Opacity inside AnimatedBuilder '
        'allocates an offscreen layer (saveLayer) and re-composites the whole '
        'subtree on every animation frame, a leading cause of animation jank. '
        'Animate opacity with the purpose-built FadeTransition (driven directly '
        'by the Animation) instead of rebuilding an Opacity widget each tick. '
        '{v1}',
    correctionMessage:
        'Replace the Opacity with FadeTransition(opacity: animation, ...), or '
        'use AnimatedOpacity for implicit animations.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  Set<String> get costlyWidgets => const {'Opacity'};

  @override
  Set<String> get problematicParents => kAnimatedRebuilders;
}

/// Flags `Opacity` creating a per-item offscreen layer inside a scrollable.
///
/// Since: v5.x | Rule version: v1
///
/// `Opacity` inside `ListView` / `GridView` / `CustomScrollView` / `PageView`
/// forces an offscreen layer for every visible item as it scrolls into view,
/// multiplying GPU cost across the list.
///
/// **BAD:**
/// ```dart
/// ListView(
///   children: [for (final i in items) Opacity(opacity: 0.5, child: Tile(i))],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// // Bake the alpha into the color/decoration, or fade with FadeTransition.
/// ListView(children: [for (final i in items) Tile(i, faded: true)])
/// ```
class AvoidOpacityInScrollableRule extends _CompoundPerformanceRule {
  AvoidOpacityInScrollableRule() : super(_code);

  static const LintCode _code = LintCode(
    'avoid_opacity_in_scrollable',
    '[avoid_opacity_in_scrollable] Opacity inside a scrollable (ListView, '
        'GridView, CustomScrollView, PageView) allocates a separate offscreen '
        'layer for every visible item as it scrolls, multiplying GPU cost and '
        'causing scroll jank on long lists. Bake the alpha into the child color '
        'or decoration, or use FadeTransition for animated fades, so no '
        'per-item saveLayer is needed. {v1}',
    correctionMessage:
        'Apply opacity via the child color/decoration alpha, or use '
        'FadeTransition. Avoid wrapping list items in Opacity.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  Set<String> get costlyWidgets => const {'Opacity'};

  @override
  Set<String> get problematicParents => kScrollableWidgets;
}

/// Flags `BackdropFilter` inside a scrollable — a severe GPU hazard.
///
/// Since: v5.x | Rule version: v1
///
/// `BackdropFilter` samples and filters everything painted beneath it. Inside
/// a scrollable it re-runs that whole-screen filter for every visible item on
/// every scroll frame, one of the worst performance patterns in Flutter.
///
/// **BAD:**
/// ```dart
/// ListView(
///   children: [for (final i in items) BackdropFilter(filter: blur, child: Tile(i))],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// // Pre-render a blurred asset, or apply one BackdropFilter outside the list.
/// ```
class AvoidBackdropFilterInScrollableRule extends _CompoundPerformanceRule {
  AvoidBackdropFilterInScrollableRule() : super(_code);

  static const LintCode _code = LintCode(
    'avoid_backdrop_filter_in_scrollable',
    '[avoid_backdrop_filter_in_scrollable] BackdropFilter inside a scrollable '
        '(ListView, GridView, CustomScrollView, PageView) re-filters everything '
        'painted beneath it for every visible item on every scroll frame, one '
        'of the most expensive GPU patterns in Flutter and a guaranteed source '
        'of dropped frames. Move the blur outside the scrollable, or pre-render '
        'a blurred image, so the filter runs once rather than per item. {v1}',
    correctionMessage:
        'Apply a single BackdropFilter outside the scrollable, or pre-render a '
        'blurred asset. Do not place BackdropFilter on scrolled items.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  Set<String> get costlyWidgets => const {'BackdropFilter'};

  @override
  Set<String> get problematicParents => kScrollableWidgets;
}

/// Flags `ShaderMask` (which triggers `saveLayer`) inside a scrollable.
///
/// Since: v5.x | Rule version: v1
///
/// `ShaderMask` runs a shader through an offscreen `saveLayer`. Inside a
/// scrollable this recurs for every visible item, collapsing frame rate.
///
/// **BAD:**
/// ```dart
/// GridView(
///   children: [for (final i in items) ShaderMask(shaderCallback: s, child: Cell(i))],
/// )
/// ```
class AvoidShaderMaskInScrollableRule extends _CompoundPerformanceRule {
  AvoidShaderMaskInScrollableRule() : super(_code);

  static const LintCode _code = LintCode(
    'avoid_shader_mask_in_scrollable',
    '[avoid_shader_mask_in_scrollable] ShaderMask inside a scrollable '
        '(ListView, GridView, CustomScrollView, PageView) forces an offscreen '
        'saveLayer and a shader pass for every visible item on every scroll '
        'frame, which can reduce frame rate dramatically on long lists. Apply '
        'the gradient or shader as a decoration on each item, or mask once '
        'outside the scrollable, to avoid the per-item saveLayer. {v1}',
    correctionMessage:
        'Use a gradient decoration per item, or apply ShaderMask once outside '
        'the scrollable. Avoid ShaderMask on scrolled items.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  Set<String> get costlyWidgets => const {'ShaderMask'};

  @override
  Set<String> get problematicParents => kScrollableWidgets;
}

/// Flags `ImageFiltered` / `ColorFiltered` inside a scrollable.
///
/// Since: v5.x | Rule version: v1
///
/// Both `ImageFiltered` and `ColorFiltered` push an offscreen filter layer.
/// Inside a scrollable the filter re-runs for every visible item per frame.
///
/// **BAD:**
/// ```dart
/// ListView(
///   children: [for (final i in items) ColorFiltered(colorFilter: f, child: Tile(i))],
/// )
/// ```
class AvoidImageFilterInScrollableRule extends _CompoundPerformanceRule {
  AvoidImageFilterInScrollableRule() : super(_code);

  static const LintCode _code = LintCode(
    'avoid_image_filter_in_scrollable',
    '[avoid_image_filter_in_scrollable] ImageFiltered or ColorFiltered inside '
        'a scrollable (ListView, GridView, CustomScrollView, PageView) pushes '
        'an offscreen filter layer for every visible item on every scroll '
        'frame, causing sustained GPU load and scroll jank. Pre-bake the filter '
        'into the source image or asset, or apply the filter once outside the '
        'scrollable, so it is not recomputed per item. {v1}',
    correctionMessage:
        'Pre-render the filtered image, or filter once outside the scrollable. '
        'Avoid per-item ImageFiltered/ColorFiltered.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  Set<String> get costlyWidgets => const {'ImageFiltered', 'ColorFiltered'};

  @override
  Set<String> get problematicParents => kScrollableWidgets;
}

/// Flags `ClipPath` re-rasterized every frame inside `AnimatedBuilder`.
///
/// Since: v5.x | Rule version: v1
///
/// `ClipPath` is an arbitrary-path clip that rasterizes its subtree. Inside an
/// `AnimatedBuilder` the clip is recomputed and re-rasterized every frame.
///
/// **BAD:**
/// ```dart
/// AnimatedBuilder(
///   animation: controller,
///   builder: (context, child) => ClipPath(clipper: c, child: child),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// // Clip once outside the builder, or prefer ClipRRect for simple shapes.
/// ```
class AvoidClipPathInAnimatedBuilderRule extends _CompoundPerformanceRule {
  AvoidClipPathInAnimatedBuilderRule() : super(_code);

  static const LintCode _code = LintCode(
    'avoid_clip_path_in_animated_builder',
    '[avoid_clip_path_in_animated_builder] ClipPath inside AnimatedBuilder '
        'recomputes the arbitrary clip path and re-rasterizes its subtree on '
        'every animation frame, an expensive operation that commonly drops '
        'frames during transitions. Clip once outside the animated builder, or '
        'prefer ClipRRect/BoxDecoration for simple rounded shapes, so the clip '
        'is not recalculated each tick. {v1}',
    correctionMessage:
        'Move the ClipPath outside the AnimatedBuilder, or use '
        'ClipRRect/BoxDecoration for simple shapes.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  Set<String> get costlyWidgets => const {'ClipPath'};

  @override
  Set<String> get problematicParents => kAnimatedRebuilders;
}

/// Flags compound arithmetic in `build()` whose every operand is
/// session-constant, so the value is recomputed on every rebuild instead of
/// once.
///
/// Since: v14.x | Rule version: v1
///
/// A Flutter `build()` frequently computes a value from operands that never
/// change for the whole app session — numeric literals, `static const` /
/// top-level `const` fields, and device-scaled design-token getters such as
/// `ThemeCommonSpace.Footer.size` (a `static final` map lookup resolved once at
/// startup). The result is identical on every frame, yet it is recomputed each
/// rebuild. Hoisting it to a lazily-initialized `static final` field computes it
/// once.
///
/// **Why not `const`?** A token getter like `ThemeCommonSpace.X.size` reads a
/// runtime `static final` cache (keyed off the device display category), so the
/// expression is NOT a compile-time constant — `const` fails to compile and
/// `static final` is the strongest form available. Teaching this distinction is
/// the point of the rule: authors reach for `const`, hit the compile error, and
/// then leave the value inline in `build()`.
///
/// To stay low-noise the rule fires ONLY on a compound expression (at least one
/// operator). A bare single getter (`ThemeCommonSpace.Medium.size`) is skipped:
/// the per-site win is a single map lookup, so hoisting one bare getter is not
/// worth a field. Severity is `info` accordingly — the value is cumulative and
/// pedagogical, not a hot-path emergency.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   final double pad = ThemeCommonSpace.Footer.size * 2; // recomputed per frame
///   return Padding(padding: EdgeInsets.only(bottom: pad));
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// static final double _pad = ThemeCommonSpace.Footer.size * 2; // computed once
///
/// Widget build(BuildContext context) {
///   return Padding(padding: EdgeInsets.only(bottom: _pad));
/// }
/// ```
class PreferStaticFinalForSessionConstantRule extends SaropaLintRule {
  PreferStaticFinalForSessionConstantRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'performance'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_static_final_for_session_constant',
    '[prefer_static_final_for_session_constant] This expression combines only '
        'session-constant values (numeric literals, const fields, and '
        'device-scaled design-token getters that resolve once per app session), '
        'so its result is identical on every rebuild yet is recomputed on every '
        'frame inside build(). The token getters are not compile-time const, so '
        'const will not compile; hoist the whole expression to a lazily computed '
        'static final field so it is evaluated once rather than per build. {v1}',
    correctionMessage:
        'Move the expression to a `static final` field on the State/Widget class '
        '(e.g. `static final double _value = <expr>;`) and reference the field '
        'inside build(). Use static final, not const, because design-token '
        'getters are resolved at runtime.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Default design-token enum types whose value getters resolve once per app
  /// session (a `static final` cache keyed off the device display category).
  ///
  /// Detection is syntactic so it works under both the resolved analyzer tree
  /// (IDE) and the unresolved `parseString` tree (scan/health CLIs). This is the
  /// built-in default set, matching the Saropa design-system token classes the
  /// rule was authored against; it is intentionally narrow to keep the rule
  /// low-noise rather than flagging every `.size` access in a codebase.
  static const Set<String> _tokenEnumTypes = <String>{
    'ThemeCommonSpace',
    'ThemeCommonSize',
    'ThemeCommonFontSize',
    'ThemeCommonElevation',
    'ThemeCommonRadius',
    'ThemeCommonIconSize',
  };

  /// Getter names on a token enum value that return a session-constant scalar.
  static const Set<String> _tokenGetters = <String>{'size'};

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((BinaryExpression node) {
      // Report only the OUTERMOST arithmetic expression. Nested binaries
      // (`a + b * c` contains `b * c`) have a BinaryExpression parent and would
      // double-report the same hoist site, so skip them — the enclosing binary
      // is the one worth extracting.
      if (!_isOutermostArithmetic(node)) return;

      // Location gate: only inside an instance `build()` method (criterion 1).
      // Closures nested in build (LayoutBuilder/itemBuilder) still resolve to
      // the enclosing build MethodDeclaration. initState, didChangeDependencies,
      // field initializers, and static/top-level contexts are excluded because
      // they already run once.
      if (!_isInsideInstanceBuild(node)) return;

      // Every leaf must be session-constant, AND at least one must be a
      // non-trivial constant (token getter or named const). A pure
      // literal-only expression like `2 * 2` is already const-folded by the
      // compiler, so hoisting it buys nothing.
      final _SessionConstResult result = _classify(node);
      if (result.allSessionConstant && result.hasNonTrivialConstant) {
        reporter.atNode(node);
      }
    });
  }

  /// True when [node] is not itself an operand of a wider arithmetic binary
  /// (ignoring redundant parentheses), i.e. it is the top of its operator tree.
  bool _isOutermostArithmetic(BinaryExpression node) {
    AstNode? parent = node.parent;
    while (parent is ParenthesizedExpression) {
      parent = parent.parent;
    }
    return parent is! BinaryExpression;
  }

  /// True when the nearest enclosing method is a non-static `build`.
  bool _isInsideInstanceBuild(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration) {
        return current.name.lexeme == 'build' && !current.isStatic;
      }
      // A top-level function body means we left any widget build path.
      if (current is FunctionDeclaration) return false;
      current = current.parent;
    }
    return false;
  }

  /// Classifies the operand tree of [expr]: whether EVERY leaf is
  /// session-constant, and whether at least one leaf is a non-trivial constant
  /// (so an all-literal expression does not qualify).
  _SessionConstResult _classify(Expression expr) {
    final Expression inner = _unwrap(expr);

    if (inner is IntegerLiteral || inner is DoubleLiteral) {
      return const _SessionConstResult(
        allSessionConstant: true,
        hasNonTrivialConstant: false,
      );
    }

    // Unary minus / plus on a constant operand (e.g. `-2`, `-kGap`).
    if (inner is PrefixExpression) {
      return _classify(inner.operand);
    }

    if (inner is BinaryExpression) {
      final _SessionConstResult left = _classify(inner.leftOperand);
      if (!left.allSessionConstant) return _notConstant;
      final _SessionConstResult right = _classify(inner.rightOperand);
      if (!right.allSessionConstant) return _notConstant;
      return _SessionConstResult(
        allSessionConstant: true,
        hasNonTrivialConstant:
            left.hasNonTrivialConstant || right.hasNonTrivialConstant,
      );
    }

    if (_isTokenGetter(inner) || _isNamedConstant(inner)) {
      return const _SessionConstResult(
        allSessionConstant: true,
        hasNonTrivialConstant: true,
      );
    }

    // Anything else (context, widget.*, instance fields, parameters, locals,
    // method calls) can change between rebuilds — fail the whole expression.
    return _notConstant;
  }

  static const _SessionConstResult _notConstant = _SessionConstResult(
    allSessionConstant: false,
    hasNonTrivialConstant: false,
  );

  /// Strips redundant parentheses so classification sees the real expression.
  Expression _unwrap(Expression expr) {
    Expression current = expr;
    while (current is ParenthesizedExpression) {
      current = current.expression;
    }
    return current;
  }

  /// A session-constant design-token getter: `Enum.Value.size` where `Enum` is
  /// in [_tokenEnumTypes] and the getter is in [_tokenGetters].
  bool _isTokenGetter(Expression expr) {
    if (expr is! PropertyAccess) return false;
    if (!_tokenGetters.contains(expr.propertyName.name)) return false;
    final Expression? target = expr.target;
    // `ThemeCommonSpace.Footer` parses as a PrefixedIdentifier; the enum type
    // is its prefix. `widget.foo.size` / `iconSize.size` fail here because their
    // prefix is not a known token enum, which is exactly what we want.
    return target is PrefixedIdentifier &&
        _tokenEnumTypes.contains(target.prefix.name);
  }

  /// A reference to a `static const` / top-level `const` by Dart/Flutter naming
  /// convention (`kFoo`, `_kFoo`, or SCREAMING_SNAKE_CASE).
  ///
  /// Detection is name-based, not element-based, so it behaves identically under
  /// the resolved analyzer tree and the unresolved `parseString` tree the scan
  /// and health CLIs use (where element info is absent). The k-prefix and
  /// all-caps conventions are near-universal for Dart constants, which keeps the
  /// false-positive risk low for an info-level rule. A volatile local that
  /// happens to follow the convention is the only miss, and is rare.
  bool _isNamedConstant(Expression expr) {
    if (expr is SimpleIdentifier) return _looksLikeConstName(expr.name);
    // `SomeClass.kField` static const access parses as a PrefixedIdentifier.
    if (expr is PrefixedIdentifier) {
      return _looksLikeConstName(expr.identifier.name);
    }
    return false;
  }

  bool _looksLikeConstName(String name) {
    // Flutter/Dart const convention: `kName` or private `_kName`.
    final String core = name.startsWith('_') ? name.substring(1) : name;
    if (core.length >= 2 &&
        core[0] == 'k' &&
        core[1] == core[1].toUpperCase() &&
        core[1] != core[1].toLowerCase()) {
      return true;
    }
    // SCREAMING_SNAKE_CASE constants (e.g. MAX_WIDTH, _DEFAULT_GAP).
    return RegExp(r'^_?[A-Z][A-Z0-9_]*$').hasMatch(name);
  }
}

/// Outcome of classifying an arithmetic operand tree for
/// [PreferStaticFinalForSessionConstantRule].
class _SessionConstResult {
  const _SessionConstResult({
    required this.allSessionConstant,
    required this.hasNonTrivialConstant,
  });

  /// Every leaf of the tree is session-constant.
  final bool allSessionConstant;

  /// At least one leaf is a token getter or named constant (not a bare literal),
  /// so hoisting actually avoids recomputed work.
  final bool hasNonTrivialConstant;
}
