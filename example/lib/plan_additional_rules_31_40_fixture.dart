// Fixture: plan/history/20260323/plan_additional_rules_31_through_40.md
// ignore_for_file: unused_element, dead_code, body_might_complete_normally

import 'dart:ffi';

// ========== abstract_field_initializer ==========
abstract class _AbstractFieldInit {
  abstract int badAbstractInit = 0; // expect_lint: abstract_field_initializer
}

// ========== non_constant_map_element ==========
bool _nonConstFlag = true;

void _badNonConstMap() {
  const _badMap = {
    if (_nonConstFlag) 1: 2,
  }; // expect_lint: non_constant_map_element
}

// ========== return_in_generator ==========
Stream<int> _badReturnInGen() async* {
  return 1; // expect_lint: return_in_generator
}

// ========== yield_in_non_generator ==========
Future<void> _badYieldInAsync() async {
  yield 1; // expect_lint: yield_in_non_generator
}

// ========== subtype_of_disallowed_type ==========
class _BadSubtype extends int {} // expect_lint: subtype_of_disallowed_type

// ========== undefined_enum_constructor ==========
enum _EnumCtor {
  a(1);

  const _EnumCtor(int _);
}

void _badEnumCtor() {
  _EnumCtor.missing(1); // expect_lint: undefined_enum_constructor
}

// ========== annotate_redeclares ==========
class _RedeclareParent {
  void redeclareMe() {}
}

class _RedeclareChild extends _RedeclareParent {
  void redeclareMe() {} // expect_lint: annotate_redeclares
}

// ========== deprecated_new_in_comment_reference ==========
/// See [new Object] in docs. // expect_lint: deprecated_new_in_comment_reference
class _DeprecatedNewDoc {}

// ========== document_ignores ==========
// expect_lint: document_ignores
// ignore: dead_code
void _bareIgnore() {
  return;
  print(1);
}

// ========== abi_specific_integer_invalid ==========
@AbiSpecificIntegerMapping({Abi.windowsX64: Int8()})
final class _BadAbiInteger extends AbiSpecificInteger {
  // expect_lint: abi_specific_integer_invalid
  const _BadAbiInteger();
  const _BadAbiInteger.named();
}

// ========== GOOD / false-positive guards (no expect_lint below) ==========

abstract class _AbstractFieldOk {
  abstract final int x;
}

void _goodConstMap() {
  const _goodMap = {if (true) 1: 2};
}

Stream<int> _goodGen() async* {
  yield 1;
}

class _GoodSubtype extends Object {}

enum _GoodEnum { b }

void _goodEnumUse() {
  final _ = _GoodEnum.b;
}

class _GoodRedeclareParent {
  void okRedeclare() {}
}

class _GoodRedeclareChild extends _GoodRedeclareParent {
  @override
  void okRedeclare() {}
}

/// Uses [Object] without new.
class _GoodNewDoc {}

// ignore: dead_code -- unreachable debug path
void _documentedIgnore() {
  return;
  print(1);
}

@AbiSpecificIntegerMapping({Abi.windowsX64: Int8()})
final class _GoodAbi extends AbiSpecificInteger {
  const _GoodAbi();
}
