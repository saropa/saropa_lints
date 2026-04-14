// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `require_mounted_check_after_await` lint rule.

// NOTE: require_mounted_check_after_await fires on setState() after
// await inside a class that extends State<X> without a mounted check.
//
// BAD:
// class _MyState extends State<MyWidget> {
//   Future<void> loadData() async {
//     final data = await fetchData();
//     setState(() => _data = data); // no mounted check!
//   }
// }
//
// GOOD:
// class _MyState extends State<MyWidget> {
//   Future<void> loadData() async {
//     final data = await fetchData();
//     if (!mounted) return;
//     setState(() => _data = data);
//   }
// }

void main() {}
