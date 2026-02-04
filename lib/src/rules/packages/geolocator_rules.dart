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
        'location tracking without battery consideration drains battery quickly.',
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
