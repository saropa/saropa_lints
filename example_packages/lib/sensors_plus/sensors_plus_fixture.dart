// ignore_for_file: unused_local_variable, unused_element, avoid_print

/// Fixtures for sensors_plus lint rules.
///
/// Rules covered:
///   - prefer_sensors_event_stream         (LINT / OK)
///   - sensors_plus_no_sampling_period     (LINT / OK)
///   - sensors_plus_fastest_interval       (LINT / OK)
///   - sensors_plus_missing_on_error       (LINT / OK)
library;

import 'package:sensors_plus/sensors_plus.dart';

// =============================================================================
// Mock stubs — only the symbols exercised in this fixture file.
// The real sensors_plus types are not available in the example tree.
// =============================================================================

// ignore_for_file: one_member_abstracts
abstract class AccelerometerEvent {
  double get x;
}

abstract class GyroscopeEvent {
  double get z;
}

class SensorInterval {
  static const SensorInterval normalInterval = SensorInterval._('normalInterval');
  static const SensorInterval fastestInterval = SensorInterval._('fastestInterval');
  static const SensorInterval gameInterval = SensorInterval._('gameInterval');

  const SensorInterval._(String _);
}

Stream<AccelerometerEvent> accelerometerEvents = const Stream.empty();
Stream<GyroscopeEvent> gyroscopeEvents = const Stream.empty();
Stream<AccelerometerEvent> userAccelerometerEvents = const Stream.empty();
Stream<GyroscopeEvent> magnetometerEvents = const Stream.empty();

Stream<AccelerometerEvent> accelerometerEventStream({
  SensorInterval samplingPeriod = const SensorInterval._('normalInterval'),
}) =>
    const Stream.empty();

Stream<GyroscopeEvent> gyroscopeEventStream({
  SensorInterval samplingPeriod = const SensorInterval._('normalInterval'),
}) =>
    const Stream.empty();

Stream<AccelerometerEvent> userAccelerometerEventStream({
  SensorInterval samplingPeriod = const SensorInterval._('normalInterval'),
}) =>
    const Stream.empty();

Stream<GyroscopeEvent> magnetometerEventStream({
  SensorInterval samplingPeriod = const SensorInterval._('normalInterval'),
}) =>
    const Stream.empty();

Stream<Object> barometerEventStream({
  SensorInterval samplingPeriod = const SensorInterval._('normalInterval'),
}) =>
    const Stream.empty();

// =============================================================================
// prefer_sensors_event_stream
// =============================================================================

void badPreferEventStream() {
  // expect_lint: prefer_sensors_event_stream
  accelerometerEvents.listen((e) => print(e.x));

  // expect_lint: prefer_sensors_event_stream
  gyroscopeEvents.listen((e) => print(e.z));

  // expect_lint: prefer_sensors_event_stream
  userAccelerometerEvents.listen((_) {});

  // expect_lint: prefer_sensors_event_stream
  magnetometerEvents.listen((_) {});
}

void goodPreferEventStream() {
  // The new function-call form must NOT trigger the migration rule.
  accelerometerEventStream().listen(
    (e) => print(e.x),
    onError: (Object err) => print(err),
  );

  gyroscopeEventStream(
    samplingPeriod: SensorInterval.normalInterval,
  ).listen(
    (e) => print(e.z),
    onError: (Object err) => print(err),
  );
}

// =============================================================================
// sensors_plus_no_sampling_period
// =============================================================================

void badNoSamplingPeriod() {
  // expect_lint: sensors_plus_no_sampling_period
  accelerometerEventStream().listen((_) {});

  // expect_lint: sensors_plus_no_sampling_period
  gyroscopeEventStream().listen((_) {});

  // expect_lint: sensors_plus_no_sampling_period
  barometerEventStream().listen((_) {});
}

void goodNoSamplingPeriod() {
  // samplingPeriod present — no lint.
  accelerometerEventStream(
    samplingPeriod: SensorInterval.normalInterval,
  ).listen(
    (_) {},
    onError: (Object err) => print(err),
  );

  gyroscopeEventStream(
    samplingPeriod: SensorInterval.gameInterval,
  ).listen(
    (_) {},
    onError: (Object err) => print(err),
  );
}

// =============================================================================
// sensors_plus_fastest_interval
// =============================================================================

void badFastestInterval() {
  // expect_lint: sensors_plus_fastest_interval
  accelerometerEventStream(
    samplingPeriod: SensorInterval.fastestInterval,
  ).listen((_) {});
}

void goodFastestInterval() {
  // gameInterval — preferred high-frequency alternative, no lint.
  accelerometerEventStream(
    samplingPeriod: SensorInterval.gameInterval,
  ).listen((_) {});

  // normalInterval — no lint.
  accelerometerEventStream(
    samplingPeriod: SensorInterval.normalInterval,
  ).listen((_) {});
}

// =============================================================================
// sensors_plus_missing_on_error
// =============================================================================

void badMissingOnError() {
  // expect_lint: sensors_plus_missing_on_error
  accelerometerEventStream(
    samplingPeriod: SensorInterval.normalInterval,
  ).listen((_) {});

  // expect_lint: sensors_plus_missing_on_error
  gyroscopeEventStream(
    samplingPeriod: SensorInterval.normalInterval,
  ).listen((_) {});
}

void goodMissingOnError() {
  // onError present — no lint.
  accelerometerEventStream(
    samplingPeriod: SensorInterval.normalInterval,
  ).listen(
    (_) {},
    onError: (Object error) {
      // handle PlatformException for unavailable sensor
      print('Sensor error: $error');
    },
    cancelOnError: true,
  );
}
