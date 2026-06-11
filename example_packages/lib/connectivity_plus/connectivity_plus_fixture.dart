// ignore_for_file: unused_local_variable, unused_element, dead_code

/// Fixture for connectivity_plus rules:
///   - avoid_pre_v6_single_connectivity_result (WARNING, gated <6.0.0)
///   - connectivity_satellite_missing (WARNING)
library;

import 'package:connectivity_plus/connectivity_plus.dart';

// =============================================================================
// Mock stubs — the package is not on the pub cache in this repo; declare the
// minimum surface needed to make the fixture parseable without a pub get.
// =============================================================================

// ignore: avoid_classes_with_only_static_members
class _ConnectivityStub {
  Future<ConnectivityResult> checkConnectivity() async =>
      ConnectivityResult.none;
}

// =============================================================================
// BAD examples — avoid_pre_v6_single_connectivity_result
// =============================================================================

Future<void> badSingleEqualityCheck() async {
  final connectivity = _ConnectivityStub();
  final r = await connectivity.checkConnectivity();

  // expect_lint: avoid_pre_v6_single_connectivity_result
  if (r == ConnectivityResult.none) {
    // no-op
  }

  // expect_lint: avoid_pre_v6_single_connectivity_result
  if (r != ConnectivityResult.wifi) {
    // no-op
  }

  // expect_lint: avoid_pre_v6_single_connectivity_result
  if (r == ConnectivityResult.mobile) {
    // no-op
  }
}

/// Enum literal on the left side — also flagged.
Future<void> badEnumOnLeft() async {
  final connectivity = _ConnectivityStub();
  final r = await connectivity.checkConnectivity();

  // expect_lint: avoid_pre_v6_single_connectivity_result
  if (ConnectivityResult.none == r) {
    // no-op
  }
}

// =============================================================================
// GOOD examples — avoid_pre_v6_single_connectivity_result
// =============================================================================

/// Already uses the v6 List<ConnectivityResult> API — must NOT trigger.
Future<void> goodContainsCheck(List<ConnectivityResult> results) async {
  // OK: .contains() is the correct v6 form.
  if (results.contains(ConnectivityResult.none)) {
    // no-op
  }

  // OK: negated contains form.
  if (!results.contains(ConnectivityResult.wifi)) {
    // no-op
  }
}

/// Unrelated enum comparison — must NOT trigger.
void goodUnrelatedEnum() {
  const x = AxisDirection.down;

  // OK: not a ConnectivityResult, unrelated enum.
  if (x == AxisDirection.up) {
    // no-op
  }
}

// =============================================================================
// BAD examples — connectivity_satellite_missing
// =============================================================================

/// If-else chain covering wifi/mobile/ethernet but missing satellite.
void badIfElseChainMissingSatellite(ConnectivityResult r) {
  // expect_lint: connectivity_satellite_missing
  if (r == ConnectivityResult.wifi) {
    // wifi
  } else if (r == ConnectivityResult.mobile) {
    // mobile
  } else if (r == ConnectivityResult.ethernet) {
    // ethernet — >=3 values covered, satellite missing → lint fires
  }
}

/// Larger chain with 4 values but still no satellite.
void badLargeChainMissingSatellite(ConnectivityResult r) {
  // expect_lint: connectivity_satellite_missing
  if (r == ConnectivityResult.wifi) {
    // wifi
  } else if (r == ConnectivityResult.mobile) {
    // mobile
  } else if (r == ConnectivityResult.ethernet) {
    // ethernet
  } else if (r == ConnectivityResult.vpn) {
    // vpn — 4 values, satellite still missing
  }
}

// =============================================================================
// GOOD examples — connectivity_satellite_missing
// =============================================================================

/// Chain includes satellite explicitly — must NOT trigger.
void goodChainWithSatellite(ConnectivityResult r) {
  // OK: satellite is present.
  if (r == ConnectivityResult.wifi) {
    // wifi
  } else if (r == ConnectivityResult.mobile) {
    // mobile
  } else if (r == ConnectivityResult.ethernet) {
    // ethernet
  } else if (r == ConnectivityResult.satellite) {
    // satellite — explicitly handled
  }
}

/// Single-value check — below the 3-value threshold, must NOT trigger.
void goodSingleValueCheck(ConnectivityResult r) {
  // OK: only one value tested — not an exhaustive enumeration attempt.
  if (r == ConnectivityResult.none) {
    // offline
  }
}

/// Two-value check — still below threshold, must NOT trigger.
void goodTwoValueCheck(ConnectivityResult r) {
  // OK: two values — still below the minimum-3 threshold.
  if (r == ConnectivityResult.wifi) {
    // wifi
  } else if (r == ConnectivityResult.mobile) {
    // mobile
  }
}

// =============================================================================
// Placeholder to keep the 'connectivity_plus' import used
// =============================================================================

// Enum value reference that satisfies the import without triggering any rule.
final ConnectivityResult _sentinel = ConnectivityResult.other;

// Placeholder: AxisDirection is from dart:ui / Flutter framework.
// It is referenced in goodUnrelatedEnum() above to demonstrate that the rule
// does not fire for non-ConnectivityResult enums. In a test/CI context this
// file is in example_packages which is excluded from analysis, so the
// reference is for human readers only.
enum AxisDirection { up, down, left, right }
