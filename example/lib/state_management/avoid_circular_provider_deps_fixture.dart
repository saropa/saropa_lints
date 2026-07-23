// ignore_for_file: unused_element, unused_local_variable, undefined_identifier
// ignore_for_file: undefined_class, undefined_method
// Test fixture for: avoid_circular_provider_deps
// The rule needs the whole provider graph (a cycle spans two declarations that
// may appear in either order). The `ref.watch(` usage also classifies this as a
// provider file, which the rule requires.
import 'package:saropa_lints_example/flutter_mocks.dart';

// BAD: providerA and providerB watch each other — a cycle.
// expect_lint: avoid_circular_provider_deps
final providerA = Provider((ref) {
  final b = ref.watch(providerB);
  return 'A: $b';
});

final providerB = Provider((ref) {
  final a = ref.watch(providerA);
  return 'B: $a';
});
