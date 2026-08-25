// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// flutter_map package lint rules.
///
/// Catch the documented flutter_map footguns that the generic rules miss:
/// the OSM user-agent policy block, the v8 `tileSize`/`labelPlacement`
/// deprecations, the v6 `MapOptions` initial-camera rename, the silent
/// blank-map from no error/fallback tile handling, and the `fallbackUrl`
/// in-memory cache disable on `NetworkTileProvider`.
///
/// NOTE: `MapController` disposal is intentionally NOT covered here — the
/// repo's `require_field_dispose` rule lists `MapController` in its
/// `_neverDisposeTypes` set (widget_lifecycle_rules.dart) because flutter_map
/// manages the controller lifecycle through the `FlutterMap` widget. A
/// separate undisposed-controller rule would contradict that curated decision.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../fixes/common/replace_node_fix.dart';
import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

/// Tile providers that never issue network requests, so the network-oriented
/// rules (user-agent, error/fallback handling, cache disable) do not apply.
const Set<String> _offlineTileProviders = <String>{
  'AssetTileProvider',
  'FileTileProvider',
};

/// Returns the constructor type name for an instance creation (e.g. `TileLayer`).
String _typeName(InstanceCreationExpression node) =>
    node.constructorName.type.name.lexeme;

/// Returns the named argument with [name], or null if absent.
NamedExpression? _namedArg(InstanceCreationExpression node, String name) {
  for (final Expression arg in node.argumentList.arguments) {
    if (arg is NamedExpression && arg.name.label.name == name) {
      return arg;
    }
  }
  return null;
}

/// True when the `tileProvider` argument is an offline (asset/file) provider.
///
/// The network-concern rules suppress on these because they never hit the
/// tile server. Only a direct `AssetTileProvider(...)`/`FileTileProvider(...)`
/// literal is recognized — a provider hidden behind a variable is a known
/// (accepted) false negative rather than risk a false positive.
bool _hasOfflineTileProvider(InstanceCreationExpression node) {
  final NamedExpression? provider = _namedArg(node, 'tileProvider');
  if (provider == null) return false;
  final Expression value = provider.expression;
  if (value is InstanceCreationExpression) {
    return _offlineTileProviders.contains(_typeName(value));
  }
  return false;
}

bool _isTestFilePath(String path) {
  final String normalized = path.replaceAll('\\', '/');
  return normalized.endsWith('_test.dart') || normalized.contains('/test/');
}

// =============================================================================
// flutter_map_missing_user_agent
// =============================================================================

/// Flags `TileLayer(...)` with no `userAgentPackageName` argument.
///
/// Since: v4.16.0 | Rule version: v1
///
/// OpenStreetMap identifies app traffic via the HTTP User-Agent header. When
/// `userAgentPackageName` is omitted, flutter_map sends `flutter_map (unknown)`;
/// OSM blocked all `unknown`-identified traffic in 2025, so tiles silently fail
/// in production on non-web platforms. Suppressed for asset/file providers.
///
/// **BAD:**
/// ```dart
/// TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
/// ```
///
/// **GOOD:**
/// ```dart
/// TileLayer(
///   urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
///   userAgentPackageName: 'com.example.app',
/// );
/// ```
class FlutterMapMissingUserAgentRule extends SaropaLintRule {
  FlutterMapMissingUserAgentRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'TileLayer'};

  static const LintCode _code = LintCode(
    'flutter_map_missing_user_agent',
    '[flutter_map_missing_user_agent] A flutter_map TileLayer is created without a userAgentPackageName argument. OpenStreetMap identifies application traffic through the HTTP User-Agent header; without userAgentPackageName, flutter_map sends "flutter_map (unknown)", and OSM blocked all unknown-identified tile traffic in 2025. Omitting it causes tiles to silently fail to load in production on non-web platforms. {v1}',
    correctionMessage:
        'Add userAgentPackageName: <your app bundle id> to the TileLayer (e.g. \'com.example.app\').',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (_typeName(node) != 'TileLayer') return;
      if (!fileImportsPackage(node, PackageImports.flutterMap)) return;

      // Asset/file providers never make HTTP requests, so the OSM policy does
      // not apply — suppress to avoid a guaranteed false positive.
      if (_hasOfflineTileProvider(node)) return;

      if (_namedArg(node, 'userAgentPackageName') != null) return;

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// flutter_map_deprecated_tile_size
// =============================================================================

/// Flags `TileLayer(tileSize: ...)` — deprecated in v8.0 for `tileDimension`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `TileLayer.tileSize` (a double) was deprecated in v8.0.0 in favor of
/// `tileDimension` (an int) to enforce integer tile pixel dimensions. The fix
/// renames the label and converts a `double` literal to its `int` form.
///
/// **BAD:**
/// ```dart
/// TileLayer(tileSize: 256.0);
/// ```
///
/// **GOOD:**
/// ```dart
/// TileLayer(tileDimension: 256);
/// ```
class FlutterMapDeprecatedTileSizeRule extends SaropaLintRule {
  FlutterMapDeprecatedTileSizeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'tileSize'};

  static const LintCode _code = LintCode(
    'flutter_map_deprecated_tile_size',
    '[flutter_map_deprecated_tile_size] A flutter_map TileLayer uses the deprecated tileSize argument. tileSize (a double) was deprecated in v8.0.0 and replaced by tileDimension (an int) to enforce integer tile pixel dimensions. tileSize still compiles but emits a deprecation warning and will be removed in a future release. {v1}',
    correctionMessage:
        'Rename tileSize to tileDimension and use an int value (e.g. tileDimension: 256).',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _RenameTileSizeFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (_typeName(node) != 'TileLayer') return;
      if (!fileImportsPackage(node, PackageImports.flutterMap)) return;

      final NamedExpression? arg = _namedArg(node, 'tileSize');
      if (arg == null) return;

      reporter.atNode(arg);
    });
  }
}

/// Quick fix: rename `tileSize:` to `tileDimension:` and integerize a double.
class _RenameTileSizeFix extends ReplaceNodeFix {
  _RenameTileSizeFix({required super.context});

  @override
  FixKind get fixKind => FixKind(
    'saropa.fix.renameTileSize',
    80,
    'Rename tileSize to tileDimension',
  );

  @override
  String computeReplacement(AstNode node) {
    if (node is NamedExpression) {
      final Expression value = node.expression;
      // A double literal (e.g. 256.0) becomes its int form; arbitrary
      // expressions keep their source so the developer can adjust the type.
      if (value is DoubleLiteral) {
        return 'tileDimension: ${value.value.toInt()}';
      }
      return 'tileDimension: ${value.toSource()}';
    }
    return node.toSource();
  }
}

// =============================================================================
// flutter_map_legacy_map_options_center
// =============================================================================

/// Flags removed `MapOptions(center:/zoom:/bounds:/rotation:)` arguments.
///
/// Since: v4.16.0 | Rule version: v1
///
/// v6.0.0 removed `center`, `zoom`, `bounds`, and `rotation` from `MapOptions`
/// in favor of `initialCenter`, `initialZoom`, `initialCameraFit`, and
/// `initialRotation`. The old labels fail to compile on v6+. The fix renames
/// `center`/`zoom`/`rotation`; `bounds` is left for manual `CameraFit` wrapping.
///
/// **BAD:**
/// ```dart
/// MapOptions(center: LatLng(0, 0), zoom: 5);
/// ```
///
/// **GOOD:**
/// ```dart
/// MapOptions(initialCenter: LatLng(0, 0), initialZoom: 5);
/// ```
class FlutterMapLegacyMapOptionsCenterRule extends SaropaLintRule {
  FlutterMapLegacyMapOptionsCenterRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'MapOptions'};

  /// Removed label → its v6 replacement label.
  static const Map<String, String> _renames = <String, String>{
    'center': 'initialCenter',
    'zoom': 'initialZoom',
    'rotation': 'initialRotation',
    'bounds': 'initialCameraFit',
  };

  static const LintCode _code = LintCode(
    'flutter_map_legacy_map_options_center',
    '[flutter_map_legacy_map_options_center] A flutter_map MapOptions uses a constructor argument removed in v6.0.0 (center, zoom, bounds, or rotation). These were replaced by initialCenter, initialZoom, initialCameraFit, and initialRotation; the old labels fail to compile on flutter_map v6 and later. This commonly appears in copy-pasted pre-v6 tutorial code during an upgrade. {v1}',
    correctionMessage:
        'Rename center/zoom/rotation to initialCenter/initialZoom/initialRotation; wrap a bounds value in CameraFit.bounds() for initialCameraFit.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _RenameMapOptionsArgFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (_typeName(node) != 'MapOptions') return;
      if (!fileImportsPackage(node, PackageImports.flutterMap)) return;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression &&
            _renames.containsKey(arg.name.label.name)) {
          reporter.atNode(arg);
        }
      }
    });
  }
}

/// Quick fix: rename a removed MapOptions argument label to its v6 equivalent.
///
/// `bounds` is intentionally label-renamed only (to `initialCameraFit`) — its
/// value type also changed (`LatLngBounds` → `CameraFit`), so wrapping the
/// value is left to the developer to avoid mangling the expression.
class _RenameMapOptionsArgFix extends ReplaceNodeFix {
  _RenameMapOptionsArgFix({required super.context});

  static const Map<String, String> _renames =
      FlutterMapLegacyMapOptionsCenterRule._renames;

  @override
  FixKind get fixKind => FixKind(
    'saropa.fix.renameMapOptionsArg',
    80,
    'Rename to the v6 initial-camera argument',
  );

  @override
  String computeReplacement(AstNode node) {
    if (node is NamedExpression) {
      final String? replacement = _renames[node.name.label.name];
      if (replacement != null) {
        return '$replacement: ${node.expression.toSource()}';
      }
    }
    return node.toSource();
  }
}

// =============================================================================
// flutter_map_missing_error_tile_callback
// =============================================================================

/// Flags `TileLayer(...)` with no `errorTileCallback` or `fallbackUrl`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// When a tile request fails, flutter_map calls `errorTileCallback` if set;
/// otherwise the error is swallowed and the user sees a blank tile grid. INFO
/// and pedantic-tiered because most apps legitimately set neither. Suppressed
/// for asset/file providers and test files.
///
/// **BAD:**
/// ```dart
/// TileLayer(urlTemplate: tpl, userAgentPackageName: 'com.example.app');
/// ```
///
/// **GOOD:**
/// ```dart
/// TileLayer(
///   urlTemplate: tpl,
///   userAgentPackageName: 'com.example.app',
///   errorTileCallback: (tile, error, stack) => logTileError(error),
/// );
/// ```
class FlutterMapMissingErrorTileCallbackRule extends SaropaLintRule {
  FlutterMapMissingErrorTileCallbackRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'TileLayer'};

  static const LintCode _code = LintCode(
    'flutter_map_missing_error_tile_callback',
    '[flutter_map_missing_error_tile_callback] A flutter_map TileLayer is created with neither an errorTileCallback nor a fallbackUrl. When a tile request fails (timeout, 404, server error) flutter_map invokes errorTileCallback if provided; without it the failure is swallowed and the user sees a blank tile grid — a common confusing production bug on mobile networks. Reported at INFO because many apps legitimately omit both. {v1}',
    correctionMessage:
        'Add an errorTileCallback to log/handle failures, or a fallbackUrl secondary tile server.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (_typeName(node) != 'TileLayer') return;
      if (!fileImportsPackage(node, PackageImports.flutterMap)) return;
      if (_isTestFilePath(context.filePath)) return;

      // Offline providers have a different failure model (no network request),
      // so neither errorTileCallback nor fallbackUrl is relevant.
      if (_hasOfflineTileProvider(node)) return;

      if (_namedArg(node, 'errorTileCallback') != null) return;
      if (_namedArg(node, 'fallbackUrl') != null) return;

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// flutter_map_deprecated_polygon_label_placement
// =============================================================================

/// Flags `Polygon(labelPlacement: ...)` — deprecated in v8.2.
///
/// Since: v4.16.0 | Rule version: v1
///
/// v8.2.0 deprecated `Polygon.labelPlacement` (the `PolygonLabelPlacement`
/// enum) in favor of `labelPlacementCalculator` (a `PolygonLabelPlacementCalculator`).
/// The enum still compiles but will be removed. No automated fix — the new
/// calculator API requires matching the enum value to the right calculator
/// constructor, which is best confirmed against the target version.
///
/// **BAD:**
/// ```dart
/// Polygon(points: pts, labelPlacement: PolygonLabelPlacement.centroid);
/// ```
///
/// **GOOD:**
/// ```dart
/// Polygon(points: pts, labelPlacementCalculator: const PolygonLabelPlacementCalculator.centroid());
/// ```
class FlutterMapDeprecatedPolygonLabelPlacementRule extends SaropaLintRule {
  FlutterMapDeprecatedPolygonLabelPlacementRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'labelPlacement'};

  static const LintCode _code = LintCode(
    'flutter_map_deprecated_polygon_label_placement',
    '[flutter_map_deprecated_polygon_label_placement] A flutter_map Polygon uses the deprecated labelPlacement argument. v8.2.0 deprecated Polygon.labelPlacement (the PolygonLabelPlacement enum) in favor of labelPlacementCalculator (a PolygonLabelPlacementCalculator), which uses an improved signed-area centroid algorithm and is extensible. The enum still compiles but is annotated for removal. {v1}',
    correctionMessage:
        'Replace labelPlacement: with labelPlacementCalculator: and the matching PolygonLabelPlacementCalculator constructor.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (_typeName(node) != 'Polygon') return;
      if (!fileImportsPackage(node, PackageImports.flutterMap)) return;

      final NamedExpression? arg = _namedArg(node, 'labelPlacement');
      if (arg == null) return;

      reporter.atNode(arg);
    });
  }
}

// =============================================================================
// flutter_map_fallback_url_disables_cache
// =============================================================================

/// Flags `TileLayer(fallbackUrl: ...)` on a NetworkTileProvider.
///
/// Since: v4.16.0 | Rule version: v1
///
/// flutter_map documents that specifying ANY `fallbackUrl` (even unused)
/// disables in-memory tile caching for `NetworkTileProvider`, doubling network
/// traffic and slowing rendering. Fires when `tileProvider` is absent (default
/// is NetworkTileProvider) or an explicit `NetworkTileProvider`. INFO.
///
/// **BAD:**
/// ```dart
/// TileLayer(urlTemplate: tpl, fallbackUrl: alt, userAgentPackageName: 'com.example.app');
/// ```
///
/// **GOOD:**
/// ```dart
/// TileLayer(urlTemplate: tpl, userAgentPackageName: 'com.example.app');
/// ```
class FlutterMapFallbackUrlDisablesCacheRule extends SaropaLintRule {
  FlutterMapFallbackUrlDisablesCacheRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'fallbackUrl'};

  static const LintCode _code = LintCode(
    'flutter_map_fallback_url_disables_cache',
    '[flutter_map_fallback_url_disables_cache] A flutter_map TileLayer specifies fallbackUrl while using NetworkTileProvider (the default). flutter_map documents that specifying any fallbackUrl, even when it is never used, disables in-memory tile caching for NetworkTileProvider. This is a non-obvious performance footgun: adding fallbackUrl for resilience silently doubles network traffic and increases render latency on slow connections. {v1}',
    correctionMessage:
        'Remove fallbackUrl, or accept that in-memory tile caching is disabled for NetworkTileProvider when it is present.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (_typeName(node) != 'TileLayer') return;
      if (!fileImportsPackage(node, PackageImports.flutterMap)) return;

      final NamedExpression? fallback = _namedArg(node, 'fallbackUrl');
      if (fallback == null) return;

      // The cache-disable only affects NetworkTileProvider. An explicit
      // asset/file provider is exempt; an absent provider defaults to
      // NetworkTileProvider, so the concern applies (do not suppress).
      if (_hasOfflineTileProvider(node)) return;

      // An explicit non-network, non-offline provider (e.g. a custom one) is
      // out of scope: only flag the default or an explicit NetworkTileProvider.
      final NamedExpression? provider = _namedArg(node, 'tileProvider');
      if (provider != null) {
        final Expression value = provider.expression;
        if (value is InstanceCreationExpression &&
            _typeName(value) != 'NetworkTileProvider') {
          return;
        }
      }

      reporter.atNode(fallback);
    });
  }
}
