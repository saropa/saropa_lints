// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Geolocator lint rules for Flutter applications.
///
/// These rules help ensure proper location tracking with battery awareness
/// and appropriate accuracy settings.
library;

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';

import '../../android_manifest_utils.dart';
import '../../info_plist_utils.dart';
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
  RequireGeolocatorBatteryAwarenessRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_geolocator_battery_awareness',
    '[require_geolocator_battery_awareness] High-accuracy continuous '
        'location tracking without battery consideration drains battery quickly. {v2}',
    correctionMessage:
        'Use LocationAccuracy.balanced, set distanceFilter > 0, or use '
        'AndroidSettings/AppleSettings for battery-optimized tracking.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for continuous location tracking
      if (methodName != 'getPositionStream') return;

      // Check the target to ensure it's Geolocator
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Geolocator') return;

      // Check for battery-aware settings
      final String nodeSource = node.toSource();

      // Check for problematic patterns (word-boundary / literal)
      bool hasBestAccuracy =
          RegExp(r'LocationAccuracy\.best\b').hasMatch(nodeSource) ||
          RegExp(r'LocationAccuracy\.bestForNavigation').hasMatch(nodeSource);
      bool hasZeroDistanceFilter = RegExp(
        r'distanceFilter:\s*0',
      ).hasMatch(nodeSource);
      bool hasNoIntervalDuration =
          !RegExp(r'\bintervalDuration\b').hasMatch(nodeSource) &&
          !RegExp(r'\btimeLimit\b').hasMatch(nodeSource);

      // Check for platform-specific optimized settings
      bool hasPlatformSettings =
          RegExp(r'\bAndroidSettings\b').hasMatch(nodeSource) ||
          RegExp(r'\bAppleSettings\b').hasMatch(nodeSource);

      // Flag if using best accuracy without platform optimization
      if (hasBestAccuracy && !hasPlatformSettings) {
        reporter.atNode(node);
        return;
      }

      // Flag if zero distance filter (updates too frequently)
      if (hasZeroDistanceFilter && hasNoIntervalDuration) {
        reporter.atNode(node);
        return;
      }
    });

    // Also check LocationSettings creation
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

      if (typeName != 'LocationSettings') return;

      final String nodeSource = node.toSource();

      // Check for problematic patterns
      bool hasBestAccuracy =
          RegExp(r'LocationAccuracy\.best\b').hasMatch(nodeSource) ||
          RegExp(r'LocationAccuracy\.bestForNavigation').hasMatch(nodeSource);
      bool hasZeroDistanceFilter = RegExp(
        r'distanceFilter:\s*0',
      ).hasMatch(nodeSource);

      if (hasBestAccuracy && hasZeroDistanceFilter) {
        reporter.atNode(node);
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
  PreferGeocodingCacheRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_geocoding_cache',
    '[prefer_geocoding_cache] Reverse geocoding call without evident caching. Reverse geocoding (coordinates to address) incurs API calls, network latency, and rate limits. The same coordinates almost always resolve to the same address, so caching results dramatically reduces API usage and improves response time. Store results in a local Map or persistent cache keyed by rounded coordinates. {v1}',
    correctionMessage:
        'Cache geocoding results using a Map<String, List<Placemark>> keyed by rounded coordinates (e.g., 3 decimal places ≈ 110m precision).',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_geocodingMethods.contains(node.methodName.name)) return;

      // Check if there's a cache lookup nearby in the enclosing function
      AstNode? current = node.parent;
      while (current != null) {
        if (current is FunctionBody) {
          final String bodySource = current.toSource();
          // Look for cache patterns
          if (RegExp(r'\bcache\b').hasMatch(bodySource) ||
              RegExp(r'\bCache\b').hasMatch(bodySource) ||
              RegExp(r'_geocode').hasMatch(bodySource) ||
              RegExp(r'_placemark').hasMatch(bodySource) ||
              RegExp(r'\bcached\b').hasMatch(bodySource)) {
            return; // Has cache, OK
          }
          break;
        }
        current = current.parent;
      }

      reporter.atNode(node);
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
  AvoidContinuousLocationUpdatesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_continuous_location_updates',
    '[avoid_continuous_location_updates] Continuous location stream without distance filter. GPS polling drains battery rapidly — a typical app consumes 10-15% battery per hour with continuous updates. Most use cases (ride tracking, delivery, fitness) work well with a distance filter (50-100m) that only fires when the user moves significantly. Use getPositionStream with a distanceFilter or switch to geofencing for area-based triggers. {v1}',
    correctionMessage:
        'Add a LocationSettings with distanceFilter (e.g., 50-100 meters) to reduce battery drain, or use getCurrentPosition() for one-shot requests.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_streamMethods.contains(node.methodName.name)) return;

      // Check if locationSettings or distanceFilter is specified
      final String argsSource = node.argumentList.toSource();
      if (RegExp(
        r'\b(distanceFilter|locationSettings|LocationSettings|significantChanges)\b',
      ).hasMatch(argsSource)) {
        return; // Has filtering, OK
      }

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// avoid_geolocator_background_without_config
// =============================================================================

/// Cross-checks platform config for background-capable Geolocator streaming.
///
/// Since: v12.5.0 | Rule version: v1
///
/// Continuous position streams often need background location on iOS
/// (`UIBackgroundModes` `location`) and `ACCESS_BACKGROUND_LOCATION` on
/// Android. Detection is limited to `Geolocator.getPositionStream`.
class AvoidGeolocatorBackgroundWithoutConfigRule extends SaropaLintRule {
  AvoidGeolocatorBackgroundWithoutConfigRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages', 'flutter', 'platform'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_geolocator_background_without_config',
    '[avoid_geolocator_background_without_config] Geolocator.getPositionStream is used but platform config is missing background location entries (iOS UIBackgroundModes location and/or Android ACCESS_BACKGROUND_LOCATION). Updates may stop when the app is backgrounded. {v1}',
    correctionMessage:
        'Declare UIBackgroundModes location in Info.plist and ACCESS_BACKGROUND_LOCATION in AndroidManifest when background streams are required.',
    // SEV-01 (downgraded from ERROR): deployment-config issue, updates degrade not crash.
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final projectInfo = ProjectContext.getProjectInfo(context.filePath);
    if (projectInfo == null || !projectInfo.isFlutterProject) return;
    if (!ProjectContext.hasDependency(context.filePath, 'geolocator')) return;

    final root = ProjectContext.findProjectRoot(context.filePath);
    if (root == null) return;

    final hasIos = Directory('$root/ios').existsSync();
    final hasAndroid = Directory('$root/android').existsSync();
    final plist = InfoPlistChecker.forFile(context.filePath);
    final manifest = AndroidManifestChecker.forFile(context.filePath);

    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'getPositionStream') return;
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Geolocator') return;

      final iosMisconfigured =
          hasIos &&
          plist != null &&
          plist.hasInfoPlist &&
          !plist.hasIosBackgroundLocationConfigured;
      final androidMisconfigured =
          hasAndroid &&
          manifest != null &&
          manifest.hasManifest &&
          !manifest.hasPermission('ACCESS_BACKGROUND_LOCATION');

      if (iosMisconfigured || androidMisconfigured) {
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// prefer_geolocation_coarse_location / prefer_geolocator_coarse_location
// =============================================================================

/// Prefer coarse location when high accuracy is not needed (battery and privacy).
///
/// Warns when `Geolocator.getCurrentPosition` or `Geolocator.getPositionStream`
/// is used with `LocationAccuracy.best` or `LocationAccuracy.high` without
/// a clear need. Use `LocationAccuracy.low` or `LocationAccuracy.medium`
/// when fine location is not required.
///
/// **BAD:**
/// ```dart
/// final pos = await Geolocator.getCurrentPosition(
///   locationSettings: LocationSettings(accuracy: LocationAccuracy.best),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// final pos = await Geolocator.getCurrentPosition(
///   locationSettings: LocationSettings(accuracy: LocationAccuracy.low),
/// );
/// ```
class PreferGeolocationCoarseLocationRule extends SaropaLintRule {
  PreferGeolocationCoarseLocationRule() : super(code: _code);

  @override
  List<String> get configAliases => const <String>[
    'prefer_geolocator_coarse_location',
  ];

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_geolocation_coarse_location',
    '[prefer_geolocation_coarse_location] Prefer LocationAccuracy.low or '
        'balanced when high accuracy is not required to save battery and '
        'respect privacy.',
    correctionMessage:
        'Use LocationAccuracy.low or .balanced when fine location is not needed.',
    severity: DiagnosticSeverity.INFO,
  );

  static final RegExp _bestOrHighAccuracy = RegExp(
    r'LocationAccuracy\.(?:best|high)\b',
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'getCurrentPosition' &&
          methodName != 'getPositionStream') {
        return;
      }
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Geolocator') return;

      final String argsSource = node.argumentList.toSource();
      if (!_bestOrHighAccuracy.hasMatch(argsSource)) return;

      reporter.atNode(node);
    });

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (node.constructorName.type.name.lexeme != 'LocationSettings') return;
      final String source = node.argumentList.toSource();
      if (!_bestOrHighAccuracy.hasMatch(source)) return;
      reporter.atNode(node);
    });
  }
}

/// Warns when Geolocator location stream doesn't specify distanceFilter.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v2
///
/// Without distanceFilter, the location stream fires on every tiny GPS update,
/// which drains battery and may cause performance issues. Setting a reasonable
/// distanceFilter reduces updates to only meaningful location changes.
///
/// **BAD:**
/// ```dart
/// // Fires constantly, even for 1-meter movements - battery drain!
/// Geolocator.getPositionStream().listen((position) {
///   updateMap(position);
/// });
///
/// Geolocator.getPositionStream(
///   locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
/// ).listen((position) {});
/// ```
///
/// **GOOD:**
/// ```dart
/// // Only fires when user moves 10+ meters
/// Geolocator.getPositionStream(
///   locationSettings: LocationSettings(
///     accuracy: LocationAccuracy.high,
///     distanceFilter: 10, // meters
///   ),
/// ).listen((position) {
///   updateMap(position);
/// });
/// ```
class PreferGeolocatorDistanceFilterRule extends SaropaLintRule {
  PreferGeolocatorDistanceFilterRule() : super(code: _code);

  /// High impact - affects battery life significantly.
  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_geolocator_distance_filter',
    '[prefer_geolocator_distance_filter] Location stream subscription without a distanceFilter fires continuous GPS updates at the maximum sensor rate regardless of actual movement. This causes excessive battery drain, unnecessary network requests to location services, and high CPU usage from processing redundant position updates that provide no new information. {v2}',
    correctionMessage:
        'Add distanceFilter to LocationSettings (e.g., distanceFilter: 10) to receive updates only when the user moves a meaningful distance, reducing battery and CPU usage.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'getPositionStream') return;

      // Check if it's a Geolocator call
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (!RegExp(r'\bGeolocator\b').hasMatch(targetSource)) {
        return;
      }

      // Look for locationSettings parameter
      Expression? locationSettingsArg;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression &&
            arg.name.label.name == 'locationSettings') {
          locationSettingsArg = arg.expression;
          break;
        }
      }

      // No locationSettings - definitely missing distanceFilter
      if (locationSettingsArg == null) {
        reporter.atNode(node.methodName, code);
        return;
      }

      // Check if LocationSettings has distanceFilter
      if (locationSettingsArg is InstanceCreationExpression) {
        final bool hasDistanceFilter = locationSettingsArg
            .argumentList
            .arguments
            .any((arg) {
              if (arg is NamedExpression) {
                return arg.name.label.name == 'distanceFilter';
              }
              return false;
            });

        if (!hasDistanceFilter) {
          reporter.atNode(locationSettingsArg);
        }
      }
    });

    // Also check for direct LocationSettings construction
    context.addInstanceCreationExpression((node) {
      final String typeName = node.constructorName.type.name.lexeme;

      // Check for various LocationSettings types from geolocator
      if (typeName != 'LocationSettings' &&
          typeName != 'AndroidSettings' &&
          typeName != 'AppleSettings') {
        return;
      }

      // Check if parent context is a getPositionStream call
      AstNode? current = node.parent;
      bool inPositionStream = false;
      while (current != null) {
        if (current is MethodInvocation) {
          if (current.methodName.name == 'getPositionStream') {
            inPositionStream = true;
            break;
          }
        }
        if (current is FunctionBody) break;
        current = current.parent;
      }

      if (!inPositionStream) return;

      // Check for distanceFilter parameter
      final bool hasDistanceFilter = node.argumentList.arguments.any((arg) {
        if (arg is NamedExpression) {
          return arg.name.label.name == 'distanceFilter';
        }
        return false;
      });

      if (!hasDistanceFilter) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}
