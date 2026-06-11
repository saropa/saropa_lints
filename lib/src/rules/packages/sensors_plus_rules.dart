// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// sensors_plus lint rules: migration from deprecated getter API + best practices.
///
/// Covers four rules:
///   1. `prefer_sensors_event_stream`   — flags deprecated top-level getters,
///      replaces them with the 4.x function-call form (quick fix).
///   2. `sensors_plus_no_sampling_period` — flags `*EventStream()` calls with
///      no `samplingPeriod:` arg; inserts `SensorInterval.normalInterval` (fix).
///   3. `sensors_plus_fastest_interval`  — flags `samplingPeriod: SensorInterval
///      .fastestInterval`; replaces with `SensorInterval.gameInterval` (fix).
///   4. `sensors_plus_missing_on_error`  — flags `.listen()` on sensors streams
///      with no `onError:` arg; report-only (no quick fix — a no-op stub is the
///      banned TODO-insert fix shape).
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../fixes/common/replace_node_fix.dart';
import '../../import_utils.dart';
import '../../native/saropa_fix.dart';
import '../../saropa_lint_rule.dart';

// =============================================================================
// Shared constants
// =============================================================================

/// Import guard: only run sensors_plus rules on files that import the package.
const Set<String> _sensorsImport = PackageImports.sensorsPlus;

/// The four deprecated top-level getter names (sensors_plus < 4.0.0 API).
const Set<String> _deprecatedGetters = <String>{
  'accelerometerEvents',
  'userAccelerometerEvents',
  'gyroscopeEvents',
  'magnetometerEvents',
};

/// The five `*EventStream()` function names introduced in sensors_plus 4.0.0.
const Set<String> _eventStreamFunctions = <String>{
  'accelerometerEventStream',
  'userAccelerometerEventStream',
  'gyroscopeEventStream',
  'magnetometerEventStream',
  'barometerEventStream',
};

/// Maps each deprecated getter name to its replacement function-call text.
const Map<String, String> _getterToStreamCall = <String, String>{
  'accelerometerEvents': 'accelerometerEventStream()',
  'userAccelerometerEvents': 'userAccelerometerEventStream()',
  'gyroscopeEvents': 'gyroscopeEventStream()',
  'magnetometerEvents': 'magnetometerEventStream()',
};

// =============================================================================
// prefer_sensors_event_stream
// =============================================================================

/// Flags the four top-level event-stream getters deprecated in sensors_plus 4.0.0.
///
/// Since: v5.6.0 | Rule version: v1
///
/// sensors_plus 4.0.0 deprecated the bare getter API in favor of functions that
/// accept an optional `samplingPeriod` argument. The getters still compile,
/// so their presence is invisible to the analyzer — this rule is the only nudge.
/// Gated to the `sensors_plus_4` rule pack (sensors_plus >= 4.0.0).
///
/// **BAD:**
/// ```dart
/// import 'package:sensors_plus/sensors_plus.dart';
///
/// accelerometerEvents.listen((e) => print(e.x));
/// gyroscopeEvents.listen((e) => print(e.z));
/// ```
///
/// **GOOD:**
/// ```dart
/// import 'package:sensors_plus/sensors_plus.dart';
///
/// accelerometerEventStream().listen((e) => print(e.x));
/// gyroscopeEventStream().listen((e) => print(e.z));
/// ```
class PreferSensorsEventStreamRule extends SaropaLintRule {
  PreferSensorsEventStreamRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  // Perf: skip files that never reference any deprecated getter name.
  @override
  Set<String>? get requiredPatterns => _deprecatedGetters;

  static const LintCode _code = LintCode(
    'prefer_sensors_event_stream',
    '[prefer_sensors_event_stream] One of the top-level event-stream getters deprecated in sensors_plus 4.0.0 is still in use: accelerometerEvents, userAccelerometerEvents, gyroscopeEvents, or magnetometerEvents. These getters were replaced by function-call equivalents (accelerometerEventStream(), etc.) that accept an optional samplingPeriod argument, making polling intent explicit. The getters compile on sensors_plus >= 4.0 but are deprecated and may be removed in a future major. Migrate to the function form to silence deprecation warnings and allow callers to control the delivery rate. {v1}',
    correctionMessage:
        'Replace the deprecated getter with its function-call equivalent: accelerometerEvents → accelerometerEventStream(), userAccelerometerEvents → userAccelerometerEventStream(), gyroscopeEvents → gyroscopeEventStream(), magnetometerEvents → magnetometerEventStream(). Pass samplingPeriod: SensorInterval.normalInterval to preserve the existing 200 ms default.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _ReplaceDeprecatedGetterFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Match the bare identifier form: `accelerometerEvents.listen(...)` — the
    // getter appears as a SimpleIdentifier whose parent is a MethodInvocation
    // (or any other expression consuming the stream).
    context.addSimpleIdentifier((SimpleIdentifier node) {
      if (!_deprecatedGetters.contains(node.name)) return;
      if (!fileImportsPackage(node, _sensorsImport)) return;

      // Exclude the declaration site (e.g. inside sensors_plus itself if it
      // somehow appears in the analysis root). A declaration has a parent that
      // is VariableDeclaration or TopLevelVariableDeclaration.
      final parent = node.parent;
      if (parent is VariableDeclaration) return;
      if (parent is AssignmentExpression && parent.leftHandSide == node) return;

      // Skip the getter identifier when it is already the method name of a
      // function call — that would mean the new form e.g. `accelerometerEvents()`
      // which should not exist in the 4.x API, but be conservative.
      if (parent is MethodInvocation && parent.methodName == node) return;

      reporter.atNode(node);
    });

    // Also match the prefixed form: `sensors.accelerometerEvents` where the
    // library is imported with a prefix.
    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (!_deprecatedGetters.contains(node.identifier.name)) return;
      if (!fileImportsPackage(node, _sensorsImport)) return;

      reporter.atNode(node.identifier);
    });
  }
}

/// Quick fix for [PreferSensorsEventStreamRule]: replace the deprecated getter
/// identifier with the corresponding `*EventStream()` function-call text.
class _ReplaceDeprecatedGetterFix extends ReplaceNodeFix {
  _ReplaceDeprecatedGetterFix({required super.context});

  @override
  FixKind get fixKind => FixKind(
    'saropa.fix.replaceDeprecatedSensorsGetter',
    80,
    'Replace deprecated getter with EventStream() function call',
  );

  @override
  String computeReplacement(AstNode node) {
    final name = node is SimpleIdentifier ? node.name : node.toSource();
    return _getterToStreamCall[name] ?? '${name}Stream()';
  }
}

// =============================================================================
// sensors_plus_no_sampling_period
// =============================================================================

/// Flags `*EventStream()` calls that omit the `samplingPeriod:` argument.
///
/// Since: v5.6.0 | Rule version: v1
///
/// All five `*EventStream()` functions default to `SensorInterval.normalInterval`
/// (200 ms) when `samplingPeriod` is omitted, but the omission makes the caller's
/// intent invisible. A reviewer cannot tell whether 200 ms was a deliberate
/// choice or an oversight. Nudging callers to be explicit also makes it easier
/// to tune battery usage later.
///
/// **BAD:**
/// ```dart
/// accelerometerEventStream().listen((e) => setState(() => _x = e.x));
/// ```
///
/// **GOOD:**
/// ```dart
/// accelerometerEventStream(
///   samplingPeriod: SensorInterval.normalInterval,
/// ).listen((e) => setState(() => _x = e.x));
/// ```
class SensorsPlusNoSamplingPeriodRule extends SaropaLintRule {
  SensorsPlusNoSamplingPeriodRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'sensors_plus_no_sampling_period',
    '[sensors_plus_no_sampling_period] A sensors_plus EventStream function is called without a samplingPeriod argument. All five stream functions (accelerometerEventStream, userAccelerometerEventStream, gyroscopeEventStream, magnetometerEventStream, barometerEventStream) default to SensorInterval.normalInterval (200 ms) when samplingPeriod is omitted, but the omission makes the polling intent invisible to reviewers and profilers. Omitting it also makes it harder to tune battery use later. Be explicit about your desired delivery rate. {v1}',
    correctionMessage:
        'Add samplingPeriod: SensorInterval.normalInterval to preserve the existing behavior while making intent explicit. Use a slower interval (uiInterval ~66 ms, gameInterval 20 ms) only when you genuinely need higher throughput, and prefer normalInterval (200 ms) for most UI use cases.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _InsertSamplingPeriodFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_eventStreamFunctions.contains(node.methodName.name)) return;
      if (!fileImportsPackage(node, _sensorsImport)) return;

      // Already has a samplingPeriod: arg — compliant.
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'samplingPeriod') {
          return;
        }
      }

      reporter.atNode(node.methodName);
    });
  }
}

/// Quick fix for [SensorsPlusNoSamplingPeriodRule]: insert
/// `samplingPeriod: SensorInterval.normalInterval` as the first argument.
class _InsertSamplingPeriodFix extends SaropaFixProducer {
  _InsertSamplingPeriodFix({required super.context});

  @override
  FixKind get fixKind => FixKind(
    'saropa.fix.insertSensorsSamplingPeriod',
    75,
    "Add 'samplingPeriod: SensorInterval.normalInterval'",
  );

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Walk up to the MethodInvocation so we can find the argument list.
    AstNode? target = node;
    while (target != null && target is! MethodInvocation) {
      target = target.parent;
    }
    if (target is! MethodInvocation) return;
    if (file.isEmpty) return;

    final argList = target.argumentList;
    final args = argList.arguments;

    // Insertion point: before the first existing arg, or at the start of the
    // empty arg list (after the opening paren).
    final int offset;
    final String insertion;
    if (args.isEmpty) {
      // `stream()` → `stream(samplingPeriod: SensorInterval.normalInterval)`
      offset = argList.leftParenthesis.end;
      insertion = 'samplingPeriod: SensorInterval.normalInterval';
    } else {
      // `stream(otherArg)` → `stream(samplingPeriod: …, otherArg)`
      offset = args.first.offset;
      insertion = 'samplingPeriod: SensorInterval.normalInterval, ';
    }

    try {
      await builder.addDartFileEdit(file, (b) {
        b.addSimpleInsertion(offset, insertion);
      });
    } catch (_) {
      // Edit failure — IDE will fall back silently.
    }
  }
}

// =============================================================================
// sensors_plus_fastest_interval
// =============================================================================

/// Flags `samplingPeriod: SensorInterval.fastestInterval` on any stream call.
///
/// Since: v5.6.0 | Rule version: v1
///
/// `SensorInterval.fastestInterval` is `Duration.zero` — it requests the
/// hardware's absolute maximum delivery rate with no throttling. On Android
/// this maps to `SENSOR_DELAY_FASTEST`, which burns the battery at the highest
/// possible rate and is almost never the right choice outside of hardware
/// calibration or benchmarking. `SensorInterval.gameInterval` (20 ms, 50 Hz) is
/// the high-frequency alternative that still leaves headroom for the system.
///
/// **BAD:**
/// ```dart
/// accelerometerEventStream(
///   samplingPeriod: SensorInterval.fastestInterval, // LINT
/// ).listen(calibrate);
/// ```
///
/// **GOOD:**
/// ```dart
/// accelerometerEventStream(
///   samplingPeriod: SensorInterval.gameInterval,
/// ).listen(calibrate);
/// ```
class SensorsPlusFastestIntervalRule extends SaropaLintRule {
  SensorsPlusFastestIntervalRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  // Perf: skip files that never mention the constant.
  @override
  Set<String>? get requiredPatterns => const <String>{'fastestInterval'};

  static const LintCode _code = LintCode(
    'sensors_plus_fastest_interval',
    '[sensors_plus_fastest_interval] samplingPeriod: SensorInterval.fastestInterval requests the hardware\'s absolute maximum sensor delivery rate (Duration.zero — SENSOR_DELAY_FASTEST on Android). This runs the sensor stack at its highest possible rate with no OS throttling, which drains the battery at the maximum rate achievable by the hardware. Outside of hardware calibration or benchmarking it is almost never the right choice. Prefer SensorInterval.gameInterval (20 ms / 50 Hz) for high-frequency use cases, or a slower interval for typical UI work. {v1}',
    correctionMessage:
        'Replace SensorInterval.fastestInterval with SensorInterval.gameInterval (20 ms, 50 Hz) for high-frequency needs, or with SensorInterval.normalInterval (200 ms) for typical UI. Note: this is a behavior change — verify your use case warrants the highest available rate before suppressing.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _ReplaceFastestIntervalFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addNamedExpression((NamedExpression node) {
      // Only match `samplingPeriod:` arguments.
      if (node.name.label.name != 'samplingPeriod') return;
      if (!fileImportsPackage(node, _sensorsImport)) return;

      // Value must reference SensorInterval.fastestInterval syntactically.
      // We match the prefixed-identifier form `SensorInterval.fastestInterval`.
      final value = node.expression;
      if (value is! PrefixedIdentifier) return;
      if (value.prefix.name != 'SensorInterval') return;
      if (value.identifier.name != 'fastestInterval') return;

      reporter.atNode(node);
    });
  }
}

/// Quick fix for [SensorsPlusFastestIntervalRule]: replace
/// `SensorInterval.fastestInterval` with `SensorInterval.gameInterval`.
class _ReplaceFastestIntervalFix extends ReplaceNodeFix {
  _ReplaceFastestIntervalFix({required super.context});

  @override
  FixKind get fixKind => FixKind(
    'saropa.fix.replaceFastestInterval',
    60,
    'Replace fastestInterval with gameInterval (behavior change)',
  );

  @override
  AstNode? findTargetNode(AstNode node) {
    // The covering node may be a SimpleIdentifier ('fastestInterval') or the
    // full NamedExpression. Navigate to the PrefixedIdentifier value to replace
    // exactly `SensorInterval.fastestInterval`.
    AstNode? current = node;
    while (current != null) {
      if (current is PrefixedIdentifier &&
          current.identifier.name == 'fastestInterval') {
        return current;
      }
      current = current.parent;
    }
    return node;
  }

  @override
  String computeReplacement(AstNode node) => 'SensorInterval.gameInterval';
}

// =============================================================================
// sensors_plus_missing_on_error
// =============================================================================

/// Flags `.listen(...)` on a sensors_plus stream that omits `onError:`.
///
/// Since: v5.6.0 | Rule version: v1 | No quick fix
///
/// The official sensors_plus README states: "Some low-end or old Android devices
/// don't have all sensors available … it is highly recommended to add onError()."
/// Without `onError:`, an unavailable sensor delivers an unhandled platform
/// exception to the stream. Depending on the zone configuration this either
/// crashes the app or is silently swallowed, neither of which is acceptable.
/// The README's own example pairs `onError: (error) { … }` with
/// `cancelOnError: true`.
///
/// No quick fix: inserting a no-op `onError: (_) {}` stub would be the exact
/// banned TODO-insert pattern (it silences the error rather than handling it).
/// The developer must choose a meaningful error handler.
///
/// **BAD:**
/// ```dart
/// accelerometerEventStream().listen(
///   (event) => _update(event),
///   // no onError: — sensor unavailable errors are unhandled
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// accelerometerEventStream().listen(
///   (event) => _update(event),
///   onError: (Object error) {
///     // handle PlatformException for unavailable sensor
///     debugPrint('Sensor error: $error');
///   },
///   cancelOnError: true,
/// );
/// ```
class SensorsPlusMissingOnErrorRule extends SaropaLintRule {
  SensorsPlusMissingOnErrorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'sensors_plus_missing_on_error',
    '[sensors_plus_missing_on_error] A .listen() call on a sensors_plus event stream does not supply an onError: handler. The official README states that some low-end or older Android devices lack certain sensors, and that it is highly recommended to add onError(). Without it, an unavailable sensor fires an unhandled PlatformException into the stream. Depending on the zone setup the app may crash or silently swallow the failure, making it impossible to show the user a meaningful message or fall back gracefully. Pair onError with cancelOnError: true as shown in the README example. {v1}',
    correctionMessage:
        'Add an onError: handler to the .listen() call. Inspect the error object for PlatformException to detect sensor unavailability, show the user an appropriate message or disable the feature, and consider passing cancelOnError: true to stop receiving further errors from the same stream.',
    severity: DiagnosticSeverity.INFO,
  );

  // Report-only: no quick fix — a no-op stub is the banned TODO-insert shape.

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'listen') return;
      if (!fileImportsPackage(node, _sensorsImport)) return;

      // Only flag `.listen()` calls whose receiver is a call to one of the
      // five `*EventStream()` functions — avoids false positives on unrelated
      // stream listen calls in files that merely import sensors_plus.
      final receiver = node.realTarget;
      if (!_isEventStreamCall(receiver)) return;

      // Already has onError: — compliant.
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'onError') {
          return;
        }
      }

      reporter.atNode(node.methodName);
    });
  }

  /// Returns true when [node] is a call to one of the five `*EventStream()`
  /// functions (syntactic check — the import guard already scopes the file).
  bool _isEventStreamCall(Expression? node) {
    if (node is MethodInvocation) {
      return _eventStreamFunctions.contains(node.methodName.name);
    }
    // Also accept `prefix.accelerometerEventStream()`.
    if (node is PrefixedIdentifier) {
      return _eventStreamFunctions.contains(node.identifier.name);
    }
    return false;
  }
}
