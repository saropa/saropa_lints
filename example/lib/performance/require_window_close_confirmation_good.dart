// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_identifier, undefined_method, undefined_class
// ignore_for_file: annotate_overrides, non_abstract_class_inherits_abstract_member
// Compliant example for require_window_close_confirmation, kept in its own
// (desktop-named) file. The rule is whole-file: a didRequestAppExit override
// anywhere clears the flag, so this must not share a file with the BAD fixture.
import 'package:saropa_lints_example/flutter_mocks.dart';

// GOOD: the observer overrides didRequestAppExit to confirm before closing.
class AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  Future<bool> didRequestAppExit() async {
    if (hasUnsavedChanges) {
      return showSaveDialog();
    }
    return true;
  }
}
