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
