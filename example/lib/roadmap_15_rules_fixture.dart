// Test fixture for v6.0.8 ROADMAP 15 rules (11 implemented; 4 deferred)
// ignore_for_file: unused_local_variable, unused_element, prefer_const_declarations
// ignore_for_file: avoid_print_in_release, prefer_no_commented_out_code
// ignore_for_file: unused_import, depend_on_referenced_packages

import 'flutter_mocks.dart';

// =============================================================================
// avoid_escaping_inner_quotes
// =============================================================================

void badEscaping() {
  // expect_lint: avoid_escaping_inner_quotes
  final s = "He said \"hello\"";
}

void goodEscaping() {
  final s = 'He said "hello"';
}

// =============================================================================
// avoid_single_cascade_in_expression_statements
// =============================================================================

void badSingleCascade() {
  final b = StringBuffer();
  // expect_lint: avoid_single_cascade_in_expression_statements
  b..write('x');
}

void goodCascade() {
  final b = StringBuffer();
  b
    ..write('a')
    ..write('b');
}

// =============================================================================
// avoid_function_literals_in_foreach_calls
// =============================================================================

void badForEach() {
  final list = <int>[1, 2, 3];
  // expect_lint: avoid_function_literals_in_foreach_calls
  list.forEach((e) => print(e));
}

void goodForLoop() {
  final list = <int>[1, 2, 3];
  for (final e in list) print(e);
}

// =============================================================================
// avoid_classes_with_only_static_members
// =============================================================================

// expect_lint: avoid_classes_with_only_static_members
class BadStaticOnly {
  static int get one => 1;
  static void doWork() {}
}

class GoodWithInstance {
  int get one => 1;
  static void util() {}
}

// =============================================================================
// avoid_bool_in_widget_constructors
// =============================================================================

Widget badBoolWidget(bool flag) {
  // expect_lint: avoid_bool_in_widget_constructors
  return Text(flag ? 'a' : 'b');
}

Widget goodNamedBoolWidget({required bool enabled}) {
  return Text(enabled ? 'a' : 'b');
}

// =============================================================================
// avoid_double_and_int_checks
// =============================================================================

void badDoubleCheck(Object x) {
  // expect_lint: avoid_double_and_int_checks
  if (x is int) {}
}

void goodNumCheck(num n) {
  if (n is int) {}
}

// =============================================================================
// avoid_field_initializers_in_const_classes
// =============================================================================

class BadConstWithFieldInit {
  // expect_lint: avoid_field_initializers_in_const_classes
  final int x = 1;
  const BadConstWithFieldInit();
}

class GoodConstNoFieldInit {
  final int x;
  const GoodConstNoFieldInit(this.x);
}

// =============================================================================
// avoid_positional_boolean_parameters
// =============================================================================

void badPositionalBool(bool visible) {
  // expect_lint: avoid_positional_boolean_parameters
  badPositionalBool(true);
}

void goodNamedBool({required bool visible}) {
  goodNamedBool(visible: true);
}

// =============================================================================
// avoid_setters_without_getters
// =============================================================================

class BadSetterOnly {
  // expect_lint: avoid_setters_without_getters
  set value(int v) {}
}

class GoodSetterAndGetter {
  int _v = 0;
  int get value => _v;
  set value(int v) => _v = v;
}

// =============================================================================
// avoid_js_rounded_ints (fixture only; VM-only or small ints do not trigger)
// =============================================================================

void goodSmallInt() {
  const n = 9007199254740991; // within JS safe range
}

// =============================================================================
// avoid_private_typedef_functions
// =============================================================================

// expect_lint: avoid_private_typedef_functions
typedef _BadPrivateCallback = void Function();

typedef GoodPublicCallback = void Function();
