// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Geolocator lint rules for Flutter applications.
///
/// These rules help ensure proper location tracking with battery awareness
/// and appropriate accuracy settings.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../saropa_lint_rule.dart';

// =============================================================================
// require_geolocator_battery_awareness
// =============================================================================

/// Warns when continuous location tracking doesn't consider battery impact.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: geolocator_battery, location_accuracy_battery
///
/// High-accuracy continuous tracking drains battery. Detect location stream
/// without accuracy consideration or battery-aware configuration.
///
/// **BAD:**
/// ```dart
/// // High accuracy continuous tracking drains battery fast
/// final stream = Geolocator.getPositionStream(
///   locationSettings: LocationSettings(
///     accuracy: LocationAccuracy.best, // Maximum battery drain!
///     distanceFilter: 0, // Updates every tiny movement
///   ),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// // Battery-aware settings
/// final stream = Geolocator.getPositionStream(
///   locationSettings: LocationSettings(
///     accuracy: LocationAccuracy.balanced, // Good enough for most cases
///     distanceFilter: 100, // Only update every 100 meters
///   ),
/// );
///
/// // Or use AndroidSettings with battery optimization
/// final stream = Geolocator.getPositionStream(
///   locationSettings: AndroidSettings(
///     accuracy: LocationAccuracy.high,
///     distanceFilter: 50,
///     forceLocationManager: true,
///     intervalDuration: Duration(seconds: 10),
///   ),
/// );
/// ```
class RequireGeolocatorBatteryAwarenessRule extends SaropaLintRule {
  const RequireGeolocatorBatteryAwarenessRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_geolocator_battery_awareness',
    problemMessage:
        '[require_geolocator_battery_awareness] High-accuracy continuous '
        'location tracking without battery consideration drains battery quickly. {v2}',
    correctionMessage:
        'Use LocationAccuracy.balanced, set distanceFilter > 0, or use '
        'AndroidSettings/AppleSettings for battery-optimized tracking.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for continuous location tracking
      if (methodName != 'getPositionStream') return;

      // Check the target to ensure it's Geolocator
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Geolocator') return;

      // Check for battery-aware settings
      final String nodeSource = node.toSource();

      // Check for problematic patterns
      bool hasBestAccuracy = nodeSource.contains('LocationAccuracy.best') ||
          nodeSource.contains('LocationAccuracy.bestForNavigation');
      bool hasZeroDistanceFilter = nodeSource.contains('distanceFilter: 0') ||
          nodeSource.contains('distanceFilter:0');
      bool hasNoIntervalDuration = !nodeSource.contains('intervalDuration') &&
          !nodeSource.contains('timeLimit');

      // Check for platform-specific optimized settings
      bool hasPlatformSettings = nodeSource.contains('AndroidSettings') ||
          nodeSource.contains('AppleSettings');

      // Flag if using best accuracy without platform optimization
      if (hasBestAccuracy && !hasPlatformSettings) {
        reporter.atNode(node, code);
        return;
      }

      // Flag if zero distance filter (updates too frequently)
      if (hasZeroDistanceFilter && hasNoIntervalDuration) {
        reporter.atNode(node, code);
        return;
      }
    });

    // Also check LocationSettings creation
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;

      if (typeName != 'LocationSettings') return;

      final String nodeSource = node.toSource();

      // Check for problematic patterns
      bool hasBestAccuracy = nodeSource.contains('LocationAccuracy.best') ||
          nodeSource.contains('LocationAccuracy.bestForNavigation');
      bool hasZeroDistanceFilter = nodeSource.contains('distanceFilter: 0') ||
          nodeSource.contains('distanceFilter:0');

      if (hasBestAccuracy && hasZeroDistanceFilter) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// GEOCODING CACHE RULES
// =============================================================================

/// Warns when reverse geocoding is called without caching results.
///
/// Since: v4.15.0 | Rule version: v1
///
/// Reverse geocoding (converting coordinates to an address) costs API
/// calls and is rate-limited. The same coordinates almost always resolve
/// to the same address. Without caching, each call incurs network latency
/// and API quota usage. Cache results locally using a Map or local database.
///
/// **BAD:**
/// ```dart
/// final placemarks = await placemarkFromCoordinates(lat, lng);
/// ```
///
/// **GOOD:**
/// ```dart
/// final cacheKey = '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';
/// final cached = _geocodeCache[cacheKey];
/// if (cached != null) return cached;
/// final placemarks = await placemarkFromCoordinates(lat, lng);
/// _geocodeCache[cacheKey] = placemarks;
/// ```
class PreferGeocodingCacheRule extends SaropaLintRule {
  const PreferGeocodingCacheRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_geocoding_cache',
    problemMessage:
        '[prefer_geocoding_cache] Reverse geocoding call without evident caching. Reverse geocoding (coordinates to address) incurs API calls, network latency, and rate limits. The same coordinates almost always resolve to the same address, so caching results dramatically reduces API usage and improves response time. Store results in a local Map or persistent cache keyed by rounded coordinates. {v1}',
    correctionMessage:
        'Cache geocoding results using a Map<String, List<Placemark>> keyed by rounded coordinates (e.g., 3 decimal places ≈ 110m precision).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Method names that indicate reverse geocoding.
  static const Set<String> _geocodingMethods = <String>{
    'placemarkFromCoordinates',
    'getAddressFromCoordinates',
    'reverseGeocode',
    'reverseGeocoding',
    'getPlacemark',
    'locationFromAddress',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!_geocodingMethods.contains(node.methodName.name)) return;

      // Check if there's a cache lookup nearby in the enclosing function
      AstNode? current = node.parent;
      while (current != null) {
        if (current is FunctionBody) {
          final String bodySource = current.toSource();
          // Look for cache patterns
          if (bodySource.contains('cache') ||
              bodySource.contains('Cache') ||
              bodySource.contains('_geocode') ||
              bodySource.contains('_placemark') ||
              bodySource.contains('cached')) {
            return; // Has cache, OK
          }
          break;
        }
        current = current.parent;
      }

      reporter.atNode(node, code);
    });
  }
}

// =============================================================================
// CONTINUOUS LOCATION UPDATE RULES
// =============================================================================

/// Warns when continuous location updates are used without need.
///
/// Since: v4.15.0 | Rule version: v1
///
/// Continuous GPS polling (getPositionStream, watchPosition) drains
/// battery rapidly. Most apps don't need real-time location — use
/// significant location changes, geofencing, or one-shot position
/// requests instead.
///
/// **BAD:**
/// ```dart
/// Geolocator.getPositionStream().listen((position) {
///   updateMap(position);
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// Geolocator.getPositionStream(
///   locationSettings: LocationSettings(distanceFilter: 100),
/// ).listen((position) {
///   updateMap(position);
/// });
/// ```
class AvoidContinuousLocationUpdatesRule extends SaropaLintRule {
  const AvoidContinuousLocationUpdatesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_continuous_location_updates',
    problemMessage:
        '[avoid_continuous_location_updates] Continuous location stream without distance filter. GPS polling drains battery rapidly — a typical app consumes 10-15% battery per hour with continuous updates. Most use cases (ride tracking, delivery, fitness) work well with a distance filter (50-100m) that only fires when the user moves significantly. Use getPositionStream with a distanceFilter or switch to geofencing for area-based triggers. {v1}',
    correctionMessage:
        'Add a LocationSettings with distanceFilter (e.g., 50-100 meters) to reduce battery drain, or use getCurrentPosition() for one-shot requests.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Methods that start continuous location streams.
  static const Set<String> _streamMethods = <String>{
    'getPositionStream',
    'watchPosition',
    'requestLocationUpdates',
    'onLocationChanged',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!_streamMethods.contains(node.methodName.name)) return;

      // Check if locationSettings or distanceFilter is specified
      final String argsSource = node.argumentList.toSource();
      if (argsSource.contains('distanceFilter') ||
          argsSource.contains('locationSettings') ||
          argsSource.contains('LocationSettings') ||
          argsSource.contains('significantChanges')) {
        return; // Has filtering, OK
      }

      reporter.atNode(node, code);
    });
  }
}
