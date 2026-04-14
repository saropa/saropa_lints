// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_di_in_widgets` lint rule.

// NOTE: avoid_di_in_widgets only fires in widget files (FileType.widget).
// In a widget context:
//
// BAD:
// class BadWidget extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final svc = GetIt.I<UserService>(); // direct GetIt access in widget
//     return Container();
//   }
// }
//
// GOOD:
// class GoodWidget extends StatelessWidget {
//   const GoodWidget(this._service, {super.key});
//   final UserService _service; // injected via constructor
//   @override
//   Widget build(BuildContext context) => Container();
// }

void main() {}
