// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// cached_network_image package lint rules (new coverage only).
///
/// The repo already ships extensive coverage for the `CachedNetworkImage`
/// WIDGET form in `lib/src/rules/media/image_rules.dart`
/// (`require_cached_image_dimensions`, `require_cached_image_placeholder`,
/// `require_cached_image_error_widget`, `prefer_cached_image_fade_animation`,
/// `prefer_cached_image_cache_manager`, `require_cached_image_device_pixel_ratio`,
/// `avoid_cached_image_unbounded_list`, `avoid_cached_image_web`) plus the
/// `avoid_cached_image_in_build` cacheKey rule and the
/// `prefer_cached_network_image` migration rule (Image.network → widget).
///
/// These rules cover the gaps those do NOT touch: the `CachedNetworkImageProvider`
/// (ImageProvider) form, which has no `placeholder`/`errorWidget`/`memCacheWidth`
/// surface of its own, and inline `CacheManager` construction passed straight to a
/// `cacheManager:` argument (rebuilt every frame).
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

/// True when [node] constructs the named type.
///
/// A constructor call is only an [InstanceCreationExpression] when resolved, so
/// matching on the type-name lexeme is the correct gate for these rules; the
/// `fileImportsPackage` guard at each call site narrows to the package.
bool _isConstruction(InstanceCreationExpression node, String typeName) =>
    node.constructorName.type.name.lexeme == typeName;

/// True when the argument list carries a named arg called [name].
bool _hasNamedArg(InstanceCreationExpression node, String name) {
  for (final Expression arg in node.argumentList.arguments) {
    if (arg is NamedExpression && arg.name.label.name == name) return true;
  }
  return false;
}

// =============================================================================
// require_cached_image_provider_dimensions
// =============================================================================

/// Flags `CachedNetworkImageProvider(...)` with no `maxWidth`/`maxHeight`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `CachedNetworkImageProvider` is the ImageProvider form of the package. It
/// accepts `maxWidth`/`maxHeight` (int?) to resize the source before it enters
/// the Flutter image cache. Without either, it decodes the full-resolution image
/// into memory — the same OOM footgun as the widget without memCacheWidth/Height.
/// The existing `require_cached_image_dimensions` rule only checks the WIDGET
/// constructor, leaving every provider call site uncovered.
///
/// **BAD:**
/// ```dart
/// final p = CachedNetworkImageProvider(url);
/// ```
///
/// **GOOD:**
/// ```dart
/// final p = CachedNetworkImageProvider(url, maxWidth: 200, maxHeight: 200);
/// ```
class RequireCachedImageProviderDimensionsRule extends SaropaLintRule {
  RequireCachedImageProviderDimensionsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns =>
      const <String>{'CachedNetworkImageProvider'};

  static const LintCode _code = LintCode(
    'require_cached_image_provider_dimensions',
    '[require_cached_image_provider_dimensions] CachedNetworkImageProvider is constructed without maxWidth or maxHeight, so the source image is decoded at full resolution before it enters the Flutter image cache. A high-resolution photo can decode to hundreds of megabytes of uncompressed bitmap, exhausting RAM and crashing on lower-end devices. The widget-form rule require_cached_image_dimensions does not cover the provider form, so these call sites are otherwise unguarded. {v1}',
    correctionMessage:
        'Add maxWidth and/or maxHeight (matching the rendered display size) to resize the image before it is cached in memory.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!_isConstruction(node, 'CachedNetworkImageProvider')) return;
      if (!fileImportsPackage(node, PackageImports.cachedNetworkImage)) return;

      // Either dimension is enough to bound the decode; only the total absence
      // of both is the OOM footgun this rule targets.
      if (_hasNamedArg(node, 'maxWidth') || _hasNamedArg(node, 'maxHeight')) {
        return;
      }
      reporter.atNode(node);
    });
  }
}

// =============================================================================
// require_cached_image_provider_error_listener
// =============================================================================

/// Flags `CachedNetworkImageProvider(...)` with no `errorListener`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// Unlike the widget, the provider form has no `errorWidget`/`errorBuilder`;
/// load failures surface only through the `errorListener` callback. Without it,
/// a failed download is swallowed silently — no fallback, no logging path. Teams
/// migrating from the widget to the provider form routinely lose all error
/// visibility. Reported at INFO because some pipelines log failures elsewhere.
///
/// **BAD:**
/// ```dart
/// final p = CachedNetworkImageProvider(url);
/// ```
///
/// **GOOD:**
/// ```dart
/// final p = CachedNetworkImageProvider(
///   url,
///   errorListener: (e) => log.warning('image load failed', e),
/// );
/// ```
class RequireCachedImageProviderErrorListenerRule extends SaropaLintRule {
  RequireCachedImageProviderErrorListenerRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns =>
      const <String>{'CachedNetworkImageProvider'};

  static const LintCode _code = LintCode(
    'require_cached_image_provider_error_listener',
    '[require_cached_image_provider_error_listener] CachedNetworkImageProvider is constructed without an errorListener. The provider form has no errorWidget or errorBuilder, so a failed image load (network error, 404, decode failure) surfaces only through the errorListener callback. Without it the failure is swallowed silently — there is no fallback widget and no logging path — which is a common regression when migrating from the CachedNetworkImage widget to the provider form. {v1}',
    correctionMessage:
        'Add an errorListener callback to log or react to image load failures, since the provider form has no errorWidget fallback.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!_isConstruction(node, 'CachedNetworkImageProvider')) return;
      if (!fileImportsPackage(node, PackageImports.cachedNetworkImage)) return;

      if (_hasNamedArg(node, 'errorListener')) return;
      reporter.atNode(node);
    });
  }
}

// =============================================================================
// avoid_inline_cache_manager_construction
// =============================================================================

/// Flags `CacheManager(...)`/`DefaultCacheManager()` built inline as a
/// `cacheManager:` argument value.
///
/// Since: v4.16.0 | Rule version: v1
///
/// A CacheManager constructed as the direct value of a `cacheManager:` argument
/// is rebuilt on every widget build. Each construction opens a fresh cache
/// database connection and registers independent file-system listeners; in a
/// `ListView.builder` this spawns one cache database per item per scroll frame.
/// The package README recommends holding the manager in a static/top-level final
/// and passing the reference. The existing `prefer_cached_image_cache_manager`
/// rule flags the OPPOSITE shape (a widget with NO cacheManager at all); this
/// rule flags the wrong WAY of supplying one.
///
/// **BAD:**
/// ```dart
/// CachedNetworkImage(
///   imageUrl: url,
///   cacheManager: DefaultCacheManager(),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// final _cacheManager = DefaultCacheManager();
/// // ...
/// CachedNetworkImage(imageUrl: url, cacheManager: _cacheManager);
/// ```
class AvoidInlineCacheManagerConstructionRule extends SaropaLintRule {
  AvoidInlineCacheManagerConstructionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'cacheManager'};

  static const LintCode _code = LintCode(
    'avoid_inline_cache_manager_construction',
    '[avoid_inline_cache_manager_construction] A CacheManager or DefaultCacheManager is constructed inline as the value of a cacheManager: argument, so a new cache manager is created on every widget build. Each construction opens a fresh cache database connection and registers its own file-system listeners; inside a ListView.builder this produces one cache database per item per scroll frame, wasting memory and I/O. Hold the manager in a static or top-level final and pass the reference instead. {v1}',
    correctionMessage:
        'Extract the CacheManager to a static final or top-level final variable and pass that reference to cacheManager: instead of constructing it inline.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addNamedExpression((NamedExpression node) {
      if (node.name.label.name != 'cacheManager') return;
      if (!fileImportsPackage(node, PackageImports.cachedNetworkImage)) return;

      // Only inline construction is the per-frame footgun; a reference to an
      // already-built manager (a SimpleIdentifier) is the correct pattern.
      final Expression expr = node.expression;
      if (expr is! InstanceCreationExpression) return;

      final String typeName = expr.constructorName.type.name.lexeme;
      if (typeName != 'CacheManager' && typeName != 'DefaultCacheManager') {
        return;
      }

      reporter.atNode(expr);
    });
  }
}
