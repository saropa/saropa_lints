// ignore_for_file: unused_element, avoid_print
// `prefer_no_blank_line_inside_blocks` applies only to Bloc/Cubit files.

import '../flutter_mocks.dart';

/// Fixture for `prefer_no_blank_line_inside_blocks`.

class DemoBloc extends Bloc<int, int> {
  DemoBloc() : super(0);

  void badBody() {
    // LINT: leading blank inside block
    print(0);

    // LINT: trailing blank before closing brace
  }

  void goodBody() {
    print(0);
  }
}
