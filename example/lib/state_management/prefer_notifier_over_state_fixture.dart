// ignore_for_file: unused_element, unused_local_variable, undefined_identifier
// ignore_for_file: undefined_class, undefined_method, undefined_getter
// Test fixture for: prefer_notifier_over_state
// The rule reports a StateProvider whose `.notifier.state` is mutated at 3+
// sites (a sign it should be a Notifier). It needs the whole file to count the
// mutations. `ref.watch(` also classifies this as a provider file.
import 'package:saropa_lints_example/flutter_mocks.dart';

// ---------------------------------------------------------------------------
// BAD: unnamed constructor — mutated from many sites.
// ---------------------------------------------------------------------------
// expect_lint: prefer_notifier_over_state
final counterProvider = StateProvider((ref) => 0);

void incrementCounter() {
  counterProvider.notifier.state = counterProvider.notifier.state + 1;
  counterProvider.notifier.state = 0;
  counterProvider.notifier.state = 100;
}

// ---------------------------------------------------------------------------
// BAD: autoDispose factory — still a StateProvider, still over-mutated.
// ---------------------------------------------------------------------------
// expect_lint: prefer_notifier_over_state
final autoDisposeProvider = StateProvider.autoDispose((ref) => 0);

void incrementAutoDispose() {
  autoDisposeProvider.notifier.state = autoDisposeProvider.notifier.state + 1;
  autoDisposeProvider.notifier.state = 0;
  autoDisposeProvider.notifier.state = 100;
}

// ---------------------------------------------------------------------------
// GOOD (false-positive guard): a variable whose NAME contains
// "StateProvider" but whose initializer is NOT a StateProvider call.
// The old .toSource().contains('StateProvider') would wrongly collect this.
// ---------------------------------------------------------------------------
final myStateProviderConfig = 'some unrelated string';

// ---------------------------------------------------------------------------
// GOOD (false-positive guard): StateNotifierProvider is a different type.
// ---------------------------------------------------------------------------
// final stateNotifierProv = StateNotifierProvider((ref) => MyNotifier());

// A ref.watch so the file is classified as a provider file.
final derived = Provider((ref) => ref.watch(counterProvider));
