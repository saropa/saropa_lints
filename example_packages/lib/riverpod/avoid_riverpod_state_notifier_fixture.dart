// ignore_for_file: unused_local_variable, unused_element, undefined_class
// ignore_for_file: non_constant_identifier_names

/// Fixture for `avoid_riverpod_state_notifier` lint rule.
///
/// riverpod 3.0 deprecated `StateNotifier` / `StateNotifierProvider` (moved to
/// legacy.dart). The rule flags the legacy types in riverpod files. Gated to the
/// `riverpod_3` pack.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

// BAD: legacy base class deprecated in riverpod 3.0.
class CounterNotifier extends StateNotifier<int> {
  // LINT: StateNotifier is legacy in riverpod 3.0 — use Notifier
  CounterNotifier() : super(0);
}

// BAD: legacy provider type deprecated in riverpod 3.0.
final counter = StateNotifierProvider<CounterNotifier, int>(
  // LINT: StateNotifierProvider is legacy in riverpod 3.0 — use NotifierProvider
  (ref) => CounterNotifier(),
);

// GOOD: the riverpod 3.0 Notifier API does not trigger.
class GoodCounter extends Notifier<int> {
  @override
  int build() => 0;
}

final goodProvider = NotifierProvider<GoodCounter, int>(GoodCounter.new);
