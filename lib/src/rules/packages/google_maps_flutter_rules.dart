// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// google_maps_flutter package lint rules (new coverage only).
///
/// The repo already classifies `GoogleMapController` as a never-dispose type in
/// `widget_lifecycle_rules.dart` (`_neverDisposeTypes`), so controller / Completer
/// disposal is intentionally NOT flagged here — adding a disposal rule would
/// contradict that shipped policy. These rules cover the gaps that policy and the
/// generic rules leave open: per-frame Set rebuilds in `build()`, the deprecated
/// `cloudMapId:` argument, the deprecated `setMapStyle` API, per-frame
/// BitmapDescriptor construction, unchecked `UnknownMapObjectIDError` info-window
/// calls, and camera animation issued from `build()`.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../fixes/common/replace_node_fix.dart';
import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

/// The four declarative map-object Set parameters on the `GoogleMap` widget.
/// Their element types live in `package:google_maps_flutter`.
const Set<String> _mapObjectTypes = <String>{
  'Marker',
  'Polyline',
  'Polygon',
  'Circle',
};

/// Info-window controller methods that throw `UnknownMapObjectIDError` since 2.0
/// when the MarkerId is not a currently-rendered marker.
const Set<String> _infoWindowMethods = <String>{
  'showMarkerInfoWindow',
  'hideMarkerInfoWindow',
  'isMarkerInfoWindowShown',
};

/// Imperative camera methods that must run from an event handler, never `build()`.
const Set<String> _cameraMoveMethods = <String>{'animateCamera', 'moveCamera'};

/// True when [node] sits inside a `build(BuildContext ...)` method body. Camera
/// and allocation rules narrow to `build` because that is the per-frame hot path;
/// the same call in `initState` / an event handler is correct.
bool _isInsideBuildMethod(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is MethodDeclaration) {
      if (current.name.lexeme != 'build') return false;
      final FormalParameterList? params = current.parameters;
      if (params == null) return false;
      // A real Flutter build takes a single BuildContext parameter; this guards
      // against unrelated methods that happen to be named "build".
      return params.parameters.any((FormalParameter p) {
        final TypeAnnotation? type = _parameterType(p);
        return type is NamedType && type.name.lexeme == 'BuildContext';
      });
    }
    // Stop at any function boundary that is not a method (closures, top-level
    // functions) so we do not walk out of the build method into an enclosing one.
    if (current is FunctionDeclaration) return false;
    current = current.parent;
  }
  return false;
}

/// Unwraps a (possibly defaulted) formal parameter to its declared type.
TypeAnnotation? _parameterType(FormalParameter param) {
  FormalParameter inner = param;
  if (inner is DefaultFormalParameter) inner = inner.parameter;
  if (inner is SimpleFormalParameter) return inner.type;
  return null;
}

/// Nearest enclosing try-statement within the current function body (stops at the
/// function boundary so an unrelated outer try is not credited).
bool _isInsideTry(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is TryStatement) return true;
    if (current is FunctionBody) return false;
    current = current.parent;
  }
  return false;
}

/// Named argument with label [name] on a constructor/method call, or null.
NamedExpression? _namedArgExpression(ArgumentList args, String name) {
  for (final Expression arg in args.arguments) {
    if (arg is NamedExpression && arg.name.label.name == name) {
      return arg;
    }
  }
  return null;
}

// =============================================================================
// google_maps_markers_rebuilt_in_build
// =============================================================================

/// Flags a non-const `Set<Marker|Polyline|Polygon|Circle>` literal built inside
/// `build()`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// The `markers` / `polylines` / `polygons` / `circles` parameters take a `Set`.
/// A set literal built inline in `build()` allocates a brand-new `Set` every
/// frame; the platform-channel diff then compares old vs new by value equality,
/// iterating the whole set — for hundreds of objects this blocks the UI thread.
/// Hold the set in `State` and mutate it only when the underlying data changes.
///
/// **BAD:**
/// ```dart
/// GoogleMap(markers: {Marker(markerId: id)}); // inside build()
/// ```
///
/// **GOOD:**
/// ```dart
/// GoogleMap(markers: _markers); // _markers is a State field
/// ```
class GoogleMapsMarkersRebuiltInBuildRule extends SaropaLintRule {
  GoogleMapsMarkersRebuiltInBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns => const <String>{'build'};

  static const LintCode _code = LintCode(
    'google_maps_markers_rebuilt_in_build',
    '[google_maps_markers_rebuilt_in_build] A Set of map objects (Marker / Polyline / Polygon / Circle) is built with a set literal directly inside build(). build() runs on every frame, so this allocates a fresh Set each time; google_maps_flutter then diffs old vs new sets by value equality, iterating the whole collection on the UI thread — for hundreds of markers this causes visible jank and flicker. Hold the Set in State and mutate it only when the data changes. {v1}',
    correctionMessage:
        'Move the Set into a State field (or ValueNotifier) and rebuild it only when the marker data changes, not on every build().',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSetOrMapLiteral((SetOrMapLiteral node) {
      // Only set literals (not maps) and only non-const ones allocate per frame.
      if (node.isMap) return;
      if (node.constKeyword != null) return;
      if (!fileImportsPackage(node, PackageImports.googleMapsFlutter)) return;
      if (!_isInsideBuildMethod(node)) return;

      // Element type must resolve to a google_maps_flutter map object. Using the
      // type-argument name (e.g. <Marker>{...}) keeps this AST-only and avoids
      // matching unrelated sets that merely sit in a build() method.
      final TypeArgumentList? typeArgs = node.typeArguments;
      if (typeArgs == null) return;
      final NamedType? first = typeArgs.arguments
          .whereType<NamedType>()
          .firstOrNull;
      if (first == null) return;
      if (!_mapObjectTypes.contains(first.name.lexeme)) return;

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// google_maps_cloud_map_id_deprecated
// =============================================================================

/// Flags the deprecated `cloudMapId:` argument on the `GoogleMap` widget.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `GoogleMap(cloudMapId: ...)` was deprecated in favor of `GoogleMap(mapId: ...)`;
/// the old getter simply returns the new value. `cloudMapId` will be removed in a
/// future major. The migration is a mechanical label rename.
///
/// **BAD:**
/// ```dart
/// GoogleMap(initialCameraPosition: p, cloudMapId: 'abc');
/// ```
///
/// **GOOD:**
/// ```dart
/// GoogleMap(initialCameraPosition: p, mapId: 'abc');
/// ```
class GoogleMapsCloudMapIdDeprecatedRule extends SaropaLintRule {
  GoogleMapsCloudMapIdDeprecatedRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'cloudMapId'};

  static const LintCode _code = LintCode(
    'google_maps_cloud_map_id_deprecated',
    '[google_maps_cloud_map_id_deprecated] The GoogleMap widget is constructed with the deprecated cloudMapId: argument. cloudMapId was deprecated in the 2.x series in favor of mapId: (the old getter just returns mapId\'s value) and will be removed in a future major version; mixing both in one call is asserted against at runtime. Rename the argument to mapId:. {v1}',
    correctionMessage: 'Rename cloudMapId: to mapId: (the value is unchanged).',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _RenameCloudMapIdFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (node.constructorName.type.name.lexeme != 'GoogleMap') return;
      if (!fileImportsPackage(node, PackageImports.googleMapsFlutter)) return;

      final NamedExpression? arg = _namedArgExpression(
        node.argumentList,
        'cloudMapId',
      );
      if (arg == null) return;

      reporter.atNode(arg);
    });
  }
}

/// Quick fix: rename `cloudMapId:` to `mapId:`, preserving the value expression.
class _RenameCloudMapIdFix extends ReplaceNodeFix {
  _RenameCloudMapIdFix({required super.context});

  @override
  FixKind get fixKind =>
      FixKind('saropa.fix.renameCloudMapId', 80, 'Rename cloudMapId to mapId');

  @override
  String computeReplacement(AstNode node) {
    if (node is NamedExpression) {
      // Keep the original value source; only the label changes.
      return 'mapId: ${node.expression.toSource()}';
    }
    return node.toSource();
  }
}

// =============================================================================
// google_maps_set_map_style_deprecated
// =============================================================================

/// Flags `GoogleMapController.setMapStyle(...)`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `setMapStyle(json)` was deprecated in 2.6.0 in favor of passing `style:` to the
/// `GoogleMap` widget, which avoids the brief flash of the default style during map
/// init. Report-only: migrating may require touching a `GoogleMap` in another file
/// and handling dynamic theme toggling, which a mechanical fix cannot do safely.
///
/// **BAD:**
/// ```dart
/// await controller.setMapStyle(jsonString);
/// ```
///
/// **GOOD:**
/// ```dart
/// GoogleMap(initialCameraPosition: p, style: jsonString);
/// ```
class GoogleMapsSetMapStyleDeprecatedRule extends SaropaLintRule {
  GoogleMapsSetMapStyleDeprecatedRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'setMapStyle'};

  static const LintCode _code = LintCode(
    'google_maps_set_map_style_deprecated',
    '[google_maps_set_map_style_deprecated] GoogleMapController.setMapStyle(...) is called. setMapStyle was deprecated in google_maps_flutter 2.6.0 in favor of passing the style: parameter directly to the GoogleMap widget, which avoids the brief flash of the default style during map initialization. Continued use is migration debt that becomes a breaking change in a future major. Move the JSON to GoogleMap(style: ...). {v1}',
    correctionMessage:
        'Pass the style JSON to GoogleMap(style: ...) instead of calling controller.setMapStyle(...).',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      // Require a receiver (controller.setMapStyle), not a bare call, so an
      // unrelated top-level setMapStyle is not matched.
      if (node.methodName.name != 'setMapStyle') return;
      if (node.realTarget == null) return;
      if (!fileImportsPackage(node, PackageImports.googleMapsFlutter)) return;

      reporter.atNode(node.methodName);
    });
  }
}

// =============================================================================
// google_maps_bitmap_descriptor_in_build
// =============================================================================

/// Flags `BitmapDescriptor.fromAssetImage(...)` / `.fromBytes(...)` inside
/// `build()`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// These synchronous factories copy data and allocate a new `BitmapDescriptor`.
/// Calling them in `build()` produces a new marker icon every frame, forcing the
/// platform to re-decode the icon and causing a marker flicker. Build descriptors
/// once in `initState` or cache them in a `static final`.
///
/// **BAD:**
/// ```dart
/// final icon = BitmapDescriptor.fromBytes(bytes); // inside build()
/// ```
///
/// **GOOD:**
/// ```dart
/// final icon = _cachedIcon; // built once in initState
/// ```
class GoogleMapsBitmapDescriptorInBuildRule extends SaropaLintRule {
  GoogleMapsBitmapDescriptorInBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns => const <String>{'BitmapDescriptor'};

  static const LintCode _code = LintCode(
    'google_maps_bitmap_descriptor_in_build',
    '[google_maps_bitmap_descriptor_in_build] BitmapDescriptor.fromAssetImage / fromBytes is called inside build(). These synchronous factories copy image data and allocate a new BitmapDescriptor on every rebuild, so the map platform channel receives a fresh marker icon each frame, re-decodes it natively, and the marker flickers. Create the descriptor once in initState() or cache it in a static final field. {v1}',
    correctionMessage:
        'Build the BitmapDescriptor once in initState() (or cache it in a static final) and reuse it across builds.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String method = node.methodName.name;
      if (method != 'fromAssetImage' && method != 'fromBytes') return;

      // Receiver must be the BitmapDescriptor class, not an arbitrary object that
      // happens to expose fromBytes.
      final Expression? target = node.realTarget;
      if (target is! SimpleIdentifier || target.name != 'BitmapDescriptor') {
        return;
      }
      if (!fileImportsPackage(node, PackageImports.googleMapsFlutter)) return;
      if (!_isInsideBuildMethod(node)) return;

      reporter.atNode(node.methodName);
    });
  }
}

// =============================================================================
// google_maps_unknown_map_id_error_unchecked
// =============================================================================

/// Flags info-window controller calls not wrapped in a try/catch.
///
/// Since: v4.16.0 | Rule version: v1
///
/// Since 2.0, `showMarkerInfoWindow` / `hideMarkerInfoWindow` /
/// `isMarkerInfoWindowShown` throw `UnknownMapObjectIDError` when the MarkerId is
/// not a currently-rendered marker (removed, updated, or not yet added). Code that
/// stores MarkerId references and calls these without a guard crashes at runtime.
/// INFO — an outer guard may exist; verify before suppressing.
///
/// **BAD:**
/// ```dart
/// await controller.showMarkerInfoWindow(markerId);
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   await controller.showMarkerInfoWindow(markerId);
/// } on UnknownMapObjectIDError { ... }
/// ```
class GoogleMapsUnknownMapIdErrorUncheckedRule extends SaropaLintRule {
  GoogleMapsUnknownMapIdErrorUncheckedRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'google_maps_unknown_map_id_error_unchecked',
    '[google_maps_unknown_map_id_error_unchecked] An info-window controller call (showMarkerInfoWindow / hideMarkerInfoWindow / isMarkerInfoWindowShown) is not wrapped in a try/catch. Since google_maps_flutter 2.0 these throw UnknownMapObjectIDError when the MarkerId is not a currently-rendered marker (removed, updated, or not yet added) instead of silently doing nothing; pre-2.0 code that stores MarkerId references and calls them unguarded crashes at runtime. Reported at INFO because an outer guard may exist. {v1}',
    correctionMessage:
        'Wrap the call in try { ... } on UnknownMapObjectIDError { ... }, or verify the marker is in the current markers set first.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_infoWindowMethods.contains(node.methodName.name)) return;
      // Require a receiver (controller.showMarkerInfoWindow) to avoid bare-name
      // collisions with unrelated helpers.
      if (node.realTarget == null) return;
      if (!fileImportsPackage(node, PackageImports.googleMapsFlutter)) return;
      if (_isInsideTry(node)) return;

      reporter.atNode(node.methodName);
    });
  }
}

// =============================================================================
// google_maps_animate_camera_in_build
// =============================================================================

/// Flags `controller.animateCamera(...)` / `moveCamera(...)` inside `build()`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `build()` runs many times per second; issuing `animateCamera` on each call
/// queues rapid-fire platform-channel calls, producing severe jank and a possible
/// PlatformException on queue overflow. Camera moves belong in event handlers or
/// lifecycle callbacks, never in `build()`.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   controller.animateCamera(update); // fires every frame
///   return GoogleMap(...);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// onPressed: () => controller.animateCamera(update),
/// ```
class GoogleMapsAnimateCameraInBuildRule extends SaropaLintRule {
  GoogleMapsAnimateCameraInBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'google_maps_animate_camera_in_build',
    '[google_maps_animate_camera_in_build] controller.animateCamera(...) or moveCamera(...) is called synchronously inside build(). build() may run many times per second on every setState, layout, or parent rebuild; issuing a camera move on each call queues rapid-fire platform-channel calls that pile up, causing severe jank and a possible PlatformException when the queue overflows. Move camera manipulation to an event handler, onMapCreated, or initState. {v1}',
    correctionMessage:
        'Call animateCamera / moveCamera from an event handler or lifecycle callback (onMapCreated, a button onPressed), never from build().',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_cameraMoveMethods.contains(node.methodName.name)) return;
      // Require a receiver so a same-named local function does not match.
      if (node.realTarget == null) return;
      if (!fileImportsPackage(node, PackageImports.googleMapsFlutter)) return;
      if (!_isInsideBuildMethod(node)) return;

      reporter.atNode(node.methodName);
    });
  }
}
