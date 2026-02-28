// Fixture for 12 roadmap-detail rules (avoid_unnecessary_containers, prefer_adjacent_strings, etc.)
// ignore_for_file: unused_local_variable, unused_element, prefer_const_declarations
// ignore_for_file: avoid_unnecessary_containers, prefer_adjacent_strings, prefer_adjective_bool_getters
// ignore_for_file: prefer_asserts_in_initializer_lists, prefer_const_constructors_in_immutables
// ignore_for_file: prefer_const_declarations, prefer_const_literals_to_create_immutables
// ignore_for_file: prefer_constructors_first, prefer_extension_methods, prefer_extension_over_utility_class
// ignore_for_file: prefer_extension_type_for_wrapper, prefer_final_fields

import 'package:flutter/material.dart';

// ========== avoid_unnecessary_containers (widget files only) ==========
// BAD: Container with only child — expect_lint in widget
Widget badContainerOnlyChild() {
  return Container(
      child: Text('Hi')); // expect_lint: avoid_unnecessary_containers
}

Widget goodContainerWithPadding() {
  return Container(padding: EdgeInsets.all(8), child: Text('Hi'));
}

// ========== prefer_adjacent_strings ==========
void adjacentStrings() {
  final bad = 'a' + 'b'; // expect_lint: prefer_adjacent_strings
  final good = 'a' 'b';
}

// ========== prefer_adjective_bool_getters ==========
class BadBoolGetters {
  bool get validate => true; // expect_lint: prefer_adjective_bool_getters
  bool get load => false; // expect_lint: prefer_adjective_bool_getters
}

class GoodBoolGetters {
  bool get isValid => true;
  bool get isLoading => false;
}

// ========== prefer_asserts_in_initializer_lists ==========
class BadAssertInBody {
  BadAssertInBody(this.x) {
    assert(x > 0); // expect_lint: prefer_asserts_in_initializer_lists
  }
  final int x;
}

class GoodAssertInInitializer {
  GoodAssertInInitializer(this.x) : assert(x > 0);
  final int x;
}

// ========== prefer_const_constructors_in_immutables ==========
@immutable
class BadImmutableNoConst {
  BadImmutableNoConst(
      {required this.url}); // expect_lint: prefer_const_constructors_in_immutables
  final String url;
}

@immutable
class GoodImmutableWithConst {
  const GoodImmutableWithConst({required this.url});
  final String url;
}

// ========== prefer_const_declarations ==========
void constDeclarations() {
  final pi = 3.14; // expect_lint: prefer_const_declarations
  final greeting = 'x'; // expect_lint: prefer_const_declarations
  const ok = 1;
}

// ========== prefer_const_literals_to_create_immutables (widget) ==========
Widget constLiterals() {
  return Column(
    children: [
      Text('a'),
      Text('b')
    ], // expect_lint: prefer_const_literals_to_create_immutables
  );
}

// ========== prefer_constructors_first ==========
class BadConstructorAfterMethod {
  void doWork() {}
  BadConstructorAfterMethod(this.x); // expect_lint: prefer_constructors_first
  final int x;
}

class GoodConstructorFirst {
  GoodConstructorFirst(this.x);
  final int x;
  void doWork() {}
}

// ========== prefer_extension_methods ==========
String formatDateTime(DateTime dt) =>
    dt.toIso8601String(); // expect_lint: prefer_extension_methods

// ========== prefer_extension_over_utility_class ==========
class StringUtils {
  StringUtils._();
  static String cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
  static bool blank(String s) => s.trim().isEmpty;
}
// Class above triggers prefer_extension_over_utility_class (reported on class name)

// ========== prefer_extension_type_for_wrapper ==========
class UserId {
  final int value;
  const UserId(this.value); // expect_lint: prefer_extension_type_for_wrapper
}

// ========== prefer_final_fields ==========
class BadMutableNeverAssigned {
  String name; // expect_lint: prefer_final_fields
  BadMutableNeverAssigned(this.name);
}

class GoodFinalField {
  final String name;
  GoodFinalField(this.name);
}

// ========== False positives: should NOT trigger ==========
class NoLintBoolGetters {
  bool get empty => true; // adjective, not verb
  bool get isActive => true;
}

class NoLintAssertUsesMethod {
  NoLintAssertUsesMethod(this.x) {
    assert(_check(x)); // instance method — cannot move
  }
  final int x;
  bool _check(int v) => v > 0;
}

void noLintConcatenationWithVariable() {
  final a = 'a';
  final s = a + 'b'; // variable + literal — not prefer_adjacent_strings
}
