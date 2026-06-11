// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Lottie animation package lint rules.
///
/// Covers five AST-detectable footguns in the `lottie` package (^3.3.2):
///   1. `controller:` without `onLoaded:` — animation stuck at frame 0.
///   2. `Lottie.network` without `errorBuilder:` — silent blank on failure.
///   3. `frameRate: FrameRate.max` without `renderCache:` — 4× repaint cost.
///   4. `renderCache: RenderCache.raster` — high memory risk per API warning.
///   5. `Lottie.network` without `backgroundLoading: true` — main-thread jank.
///
/// All rules gate on `fileImportsPackage(node, PackageImports.lottie)` AND
/// verify the receiver is the `Lottie` class identifier or `LottieBuilder`
/// to avoid collisions with `Image.network`, custom `.asset()`, etc.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Receiver helper
// ─────────────────────────────────────────────────────────────────────────────

/// The Lottie factory method names that return a `LottieBuilder`.
const Set<String> _lottieFactoryMethods = {
  'asset',
  'network',
  'file',
  'memory',
};

/// True when [node] is a Lottie factory call with a matching [methodNames] set.
///
/// Detection strategy (addresses the BLOCKER from plan_lottie.md 2026-06-11):
/// 1. Import guard: file must import `package:lottie/`.
/// 2. Method name must be in [methodNames].
/// 3. Receiver constraint — checked in two complementary ways so the rule
///    works under both the fully-resolved custom_lint AST (type available) and
///    the scan CLI (type absent):
///    a. Static-type path: `node.target?.staticType?.element?.library?.identifier`
///       starts with `package:lottie/`.
///    b. Syntactic path (fallback): `node.target` is a `SimpleIdentifier` with
///       name `'Lottie'` or `'LottieBuilder'`.
///    Either path confirming is sufficient.
bool _isLottieFactory(MethodInvocation node, Set<String> methodNames) {
  if (!methodNames.contains(node.methodName.name)) return false;
  if (!fileImportsPackage(node, PackageImports.lottie)) return false;

  final Expression? target = node.target;
  if (target == null) return false;

  // Static-type path (resolved AST): confirm the element's library is lottie.
  final staticType = target.staticType;
  if (staticType != null) {
    // ignore: deprecated_member_use
    final libraryId =
        staticType
            .element
            ?.library
            ?.identifier ?? // ignore: deprecated_member_use
        '';
    if (libraryId.startsWith('package:lottie/')) return true;
  }

  // Syntactic path (scan CLI / unresolved AST): accept the known class names.
  if (target is SimpleIdentifier) {
    return target.name == 'Lottie' || target.name == 'LottieBuilder';
  }

  return false;
}

/// True when [argList] contains a named argument called [name].
bool _hasNamedArg(ArgumentList argList, String name) {
  for (final Expression arg in argList.arguments) {
    if (arg is NamedExpression && arg.name.label.name == name) return true;
  }
  return false;
}

/// Returns the [NamedExpression] with [name] from [argList], or null.
NamedExpression? _namedArg(ArgumentList argList, String name) {
  for (final Expression arg in argList.arguments) {
    if (arg is NamedExpression && arg.name.label.name == name) return arg;
  }
  return null;
}

// =============================================================================
// lottie_controller_missing_on_loaded
// =============================================================================

/// Flags a `Lottie.*` factory call with `controller:` but no `onLoaded:`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// When a custom `AnimationController` is passed to any `Lottie.*` constructor,
/// the package drives the animation entirely through that controller. The
/// controller's `duration` defaults to `Duration.zero`, so without
/// `onLoaded: (c) { controller.duration = c.duration; … }` the animation
/// never advances past frame 0. The package's own full-control example always
/// pairs `controller:` with `onLoaded:`. This is a silent defect: the widget
/// renders but appears frozen with no runtime error or assertion.
///
/// **BAD:**
/// ```dart
/// Lottie.asset(
///   'assets/anim.json',
///   controller: _controller,   // duration stays Duration.zero
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// Lottie.asset(
///   'assets/anim.json',
///   controller: _controller,
///   onLoaded: (composition) {
///     _controller.duration = composition.duration;
///     _controller.forward();
///   },
/// );
/// ```
class LottieControllerMissingOnLoadedRule extends SaropaLintRule {
  LottieControllerMissingOnLoadedRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'lottie_controller_missing_on_loaded',
    '[lottie_controller_missing_on_loaded] A Lottie factory call supplies controller: but no onLoaded: callback. The lottie package delegates all tick-driving to the provided AnimationController, whose duration defaults to Duration.zero. Without onLoaded: the composition duration is never read from the decoded JSON, so the animation is stuck at frame 0. The official full-control example always pairs controller: with onLoaded: (composition) { controller.duration = composition.duration; }. This produces a frozen widget with no runtime error. {v1}',
    correctionMessage:
        'Add onLoaded: (composition) { controller.duration = composition.duration; } to set the controller duration after the composition is decoded.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_isLottieFactory(node, _lottieFactoryMethods)) return;

      final ArgumentList args = node.argumentList;

      // Only report when controller: is present — no controller means the
      // package self-manages the animation, so onLoaded: is optional.
      final NamedExpression? controllerArg = _namedArg(args, 'controller');
      if (controllerArg == null) return;

      // onLoaded: present → developer is handling duration assignment.
      if (_hasNamedArg(args, 'onLoaded')) return;

      // Report at the controller: named expression to point to the root cause.
      reporter.atNode(controllerArg);
    });
  }
}

// =============================================================================
// lottie_network_missing_error_builder
// =============================================================================

/// Flags `Lottie.network(...)` with no `errorBuilder:`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `Lottie.network` makes an HTTP request; the URL may be unreachable, return
/// a non-200, or deliver malformed JSON. Without `errorBuilder`, the widget
/// silently renders nothing — a blank space — leaving users with no feedback
/// and developers with no diagnostic surface. `errorBuilder` is the
/// `ImageErrorWidgetBuilder` typedef, giving access to the exception and stack
/// trace. The `.asset`, `.file`, and `.memory` constructors load from local
/// sources; only `.network` can fail at runtime due to external factors.
///
/// **BAD:**
/// ```dart
/// Lottie.network('https://example.com/anim.json');
/// ```
///
/// **GOOD:**
/// ```dart
/// Lottie.network(
///   'https://example.com/anim.json',
///   errorBuilder: (ctx, err, stack) => const Icon(Icons.error_outline),
/// );
/// ```
class LottieNetworkMissingErrorBuilderRule extends SaropaLintRule {
  LottieNetworkMissingErrorBuilderRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'lottie_network_missing_error_builder',
    '[lottie_network_missing_error_builder] Lottie.network(...) is called without an errorBuilder: argument. The URL may be unreachable, return a non-200 status, or deliver malformed JSON; without errorBuilder the widget silently renders nothing — a blank space — leaving users with no feedback and developers with no diagnostic path. errorBuilder is the same ImageErrorWidgetBuilder typedef as Image.errorBuilder, providing access to the exception and stack trace. The .asset/.file/.memory variants load from deterministic local sources and are intentionally excluded from this rule. {v1}',
    correctionMessage:
        'Add errorBuilder: (context, error, stackTrace) => ... to display a fallback widget when the network animation fails to load.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      // Only the `.network` factory; other factories load from local sources.
      if (!_isLottieFactory(node, const {'network'})) return;

      if (_hasNamedArg(node.argumentList, 'errorBuilder')) return;

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// lottie_frame_rate_max_without_render_cache
// =============================================================================

/// Flags `frameRate: FrameRate.max` on a Lottie call with no `renderCache:`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `FrameRate.max` instructs the widget to call `markNeedsPaint` on every vsync
/// tick regardless of the composition's own frame rate. On a 120 Hz ProMotion
/// device running a 30 FPS Lottie file this quadruples the number of paint
/// operations. Without `renderCache`, every paint re-evaluates the full vector
/// drawing tree. The combination is the worst possible battery and CPU profile
/// for an animation. `FrameRate.composition` (the default) gives smooth playback
/// at the authored rate; `FrameRate.max` is only justified for scrub-driven
/// progress indicators, and even then `renderCache` should offset the extra cost.
///
/// **BAD:**
/// ```dart
/// Lottie.asset('a.json', frameRate: FrameRate.max);
/// ```
///
/// **GOOD:**
/// ```dart
/// Lottie.asset(
///   'a.json',
///   frameRate: FrameRate.max,
///   renderCache: RenderCache.drawingCommands,
/// );
/// ```
class LottieFrameRateMaxWithoutRenderCacheRule extends SaropaLintRule {
  LottieFrameRateMaxWithoutRenderCacheRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'lottie_frame_rate_max_without_render_cache',
    '[lottie_frame_rate_max_without_render_cache] A Lottie factory call uses frameRate: FrameRate.max without a renderCache: argument. FrameRate.max triggers markNeedsPaint on every vsync tick regardless of the composition frame rate; on a 120 Hz ProMotion device running a 30 FPS file this quadruples repaint work. Without renderCache every paint re-evaluates the full vector drawing tree, producing the worst possible battery and CPU profile. FrameRate.composition (the default) gives smooth playback at the authored rate. If FrameRate.max is intentional (e.g. a scrub-driven indicator), add renderCache: to offset the extra tick cost. {v1}',
    correctionMessage:
        'Add renderCache: RenderCache.drawingCommands (or RenderCache.raster for very small/short animations) to offset the extra repaint cost of FrameRate.max.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_isLottieFactory(node, _lottieFactoryMethods)) return;

      final ArgumentList args = node.argumentList;

      final NamedExpression? frameRateArg = _namedArg(args, 'frameRate');
      if (frameRateArg == null) return;

      // Only match the static member access `FrameRate.max`.
      // A variable holding FrameRate.max is not statically resolvable here;
      // the conservative approach is not to flag it (avoids FPs).
      if (!_isPrefixedAccess(frameRateArg.expression, 'FrameRate', 'max')) {
        return;
      }

      // renderCache: present → developer is aware of the repaint cost.
      if (_hasNamedArg(args, 'renderCache')) return;

      reporter.atNode(frameRateArg);
    });
  }
}

// =============================================================================
// lottie_render_cache_raster_large_risk
// =============================================================================

/// Flags `renderCache: RenderCache.raster` on any Lottie factory call.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `RenderCache.raster` caches each rendered frame as a fully rasterized
/// `dart:ui.Image`. The official API documentation explicitly warns:
/// *"should only be used for very short and very small animations"*. Memory
/// consumption scales as `rendered_width × rendered_height × frame_count`,
/// with a 50 MB default cap. A full-screen 60 FPS animation for 3 seconds at
/// 390×844 px would require approximately 280 MB before the cap kicks in and
/// evicts frames, defeating the purpose of the cache. The rule fires on every
/// use to require a deliberate developer decision with a justification comment.
///
/// **BAD:**
/// ```dart
/// Lottie.asset('icon.json', renderCache: RenderCache.raster);
/// ```
///
/// **GOOD:**
/// ```dart
/// // OK for a 16x16px icon animation < 0.5s — raster cache is safe here.
/// // ignore: lottie_render_cache_raster_large_risk
/// Lottie.asset('tiny_icon.json', renderCache: RenderCache.raster);
/// ```
class LottieRenderCacheRasterLargeRiskRule extends SaropaLintRule {
  LottieRenderCacheRasterLargeRiskRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'lottie_render_cache_raster_large_risk',
    '[lottie_render_cache_raster_large_risk] A Lottie factory call uses renderCache: RenderCache.raster. The official package documentation explicitly warns this value should only be used for very short and very small animations. Memory consumption scales as rendered_width * rendered_height * frame_count, with a 50 MB default cap; a full-screen 60 FPS animation for 3 seconds at 390x844 px requires approximately 280 MB before eviction kicks in, defeating the cache. Suppress with a one-line justification comment if the animation is genuinely tiny and short. {v1}',
    correctionMessage:
        'Prefer RenderCache.drawingCommands for larger animations. If the animation is genuinely very small and short, suppress with // ignore: lottie_render_cache_raster_large_risk and a justification comment.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_isLottieFactory(node, _lottieFactoryMethods)) return;

      final NamedExpression? renderCacheArg = _namedArg(
        node.argumentList,
        'renderCache',
      );
      if (renderCacheArg == null) return;

      // Only match the static member access `RenderCache.raster`.
      if (!_isPrefixedAccess(
        renderCacheArg.expression,
        'RenderCache',
        'raster',
      )) {
        return;
      }

      reporter.atNode(renderCacheArg);
    });
  }
}

// =============================================================================
// lottie_network_missing_background_loading
// =============================================================================

/// Flags `Lottie.network(...)` without `backgroundLoading: true`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `Lottie.network` must download the JSON/dotLottie file and then parse it
/// (decompress + JSON decode + layer tree construction). For typical production
/// Lottie files (50–500 KB compressed), the parse step alone can take 10–80 ms
/// on a mid-range device. Without `backgroundLoading: true` this work runs on
/// the Flutter UI isolate, causing jank or a visible frame drop on first render.
/// The `backgroundLoading` parameter was added in v3.0 precisely to offload this
/// cost. Absent (`backgroundLoading:` not set) OR explicitly `false` both fire.
///
/// **BAD:**
/// ```dart
/// Lottie.network('https://example.com/anim.json');
/// Lottie.network('https://example.com/anim.json', backgroundLoading: false);
/// ```
///
/// **GOOD:**
/// ```dart
/// Lottie.network(
///   'https://example.com/anim.json',
///   backgroundLoading: true,
/// );
/// ```
class LottieNetworkMissingBackgroundLoadingRule extends SaropaLintRule {
  LottieNetworkMissingBackgroundLoadingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'lottie_network_missing_background_loading',
    '[lottie_network_missing_background_loading] Lottie.network(...) is called without backgroundLoading: true. The network variant must download then parse the Lottie JSON (decompress, JSON decode, layer tree construction); for typical production files (50-500 KB compressed) the parse step takes 10-80 ms on a mid-range device. Without backgroundLoading: true this work runs on the Flutter UI isolate, causing jank or a frame drop on first render. The backgroundLoading parameter was introduced in v3.0 precisely to offload this cost. Explicitly setting backgroundLoading: false also triggers this rule. {v1}',
    correctionMessage:
        'Add backgroundLoading: true so JSON parsing is offloaded to a background isolate, preventing first-render jank on the UI thread.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      // Only the `.network` factory loads from an external URL.
      if (!_isLottieFactory(node, const {'network'})) return;

      final ArgumentList args = node.argumentList;

      final NamedExpression? bgArg = _namedArg(args, 'backgroundLoading');

      // Absent backgroundLoading: → default false → UI-thread parse.
      if (bgArg == null) {
        reporter.atNode(node);
        return;
      }

      // Explicit backgroundLoading: false is as bad as omitting it.
      final Expression value = bgArg.expression;
      if (value is BooleanLiteral && value.value == true) return;

      // Any other value (variable, false literal) → report at the argument.
      reporter.atNode(bgArg);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared AST helpers
// ─────────────────────────────────────────────────────────────────────────────

/// True when [expr] is a static member access of the form `<prefix>.<member>`,
/// matching both `PrefixedIdentifier` (the common form) and `PropertyAccess`
/// (generated in some AST configurations).
///
/// Used to match `FrameRate.max` and `RenderCache.raster` without accepting a
/// bare variable name or an unrelated type's static member.
bool _isPrefixedAccess(Expression expr, String prefix, String member) {
  // Most common syntactic form: `FrameRate.max` parses as a PrefixedIdentifier.
  if (expr is PrefixedIdentifier) {
    return expr.prefix.name == prefix && expr.identifier.name == member;
  }
  // Less common but valid: `FrameRate.max` as a PropertyAccess when the target
  // is itself resolved as a SimpleIdentifier target of a PropertyAccess node.
  if (expr is PropertyAccess) {
    final Expression target = expr.target ?? expr.realTarget;
    return target is SimpleIdentifier &&
        target.name == prefix &&
        expr.propertyName.name == member;
  }
  return false;
}
