// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_future_in_build` lint rule.

// NOTE: avoid_future_in_build fires on Future creation passed to
// FutureBuilder(future: fetchData()) inside a widget build() method.
// Requires widget class with properly typed FutureBuilder usage.
//
// BAD:
// Widget build(BuildContext context) {
//   return FutureBuilder(future: fetchData(), ...); // re-creates Future
// }
//
// GOOD:
// late final _future = fetchData(); // in initState
// Widget build(BuildContext context) {
//   return FutureBuilder(future: _future, ...); // stored Future
// }

void main() {}
