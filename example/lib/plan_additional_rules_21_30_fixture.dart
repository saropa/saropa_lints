// Fixture: plan_additional_rules_21_through_30 (compile-time shape / record rules).
// ignore_for_file: unused_element, unused_field, unused_local_variable, dead_code

import 'package:meta/meta.dart';

extension _Plan2130Ext on int {
  void m() {}
}

// ========== duplicate_constructor ==========
class _DupCtor {
  _DupCtor(); // expect_lint: duplicate_constructor
  _DupCtor(); // expect_lint: duplicate_constructor
}

// ========== conflicting_constructor_and_static_member ==========
class _CtorStaticConflict {
  _CtorStaticConflict.foo(); // expect_lint: conflicting_constructor_and_static_member
  static void foo() {} // expect_lint: conflicting_constructor_and_static_member
}

// ========== duplicate_field_name ==========
void _dupRecordField() {
  final bad = (a: 1, a: 2); // expect_lint: duplicate_field_name
  final good = (x: 1, y: 2);
}

// ========== field_initializer_redirecting_constructor ==========
class _RedirectField {
  final int x;
  _RedirectField()
      : x = 1,
        this.named(); // expect_lint: field_initializer_redirecting_constructor
  _RedirectField.named() : x = 0;
}

// ========== invalid_super_formal_parameter_location ==========
class _SuperParent {
  _SuperParent(int a);
}

class _SuperBad extends _SuperParent {
  factory _SuperBad.named(super.a) =
      _SuperBad._; // expect_lint: invalid_super_formal_parameter_location
  _SuperBad._() : super(0);
}

// ========== illegal_concrete_enum_member ==========
enum _BadEnumMember {
  v;

  final int index = 0; // expect_lint: illegal_concrete_enum_member
}

// ========== invalid_extension_argument_count ==========
void _badExtensionOverride() {
  _Plan2130Ext().m(); // expect_lint: invalid_extension_argument_count
}

// ========== invalid_literal_annotation ==========
class _BadLiteral {
  @literal
  _BadLiteral(); // expect_lint: invalid_literal_annotation
}

// ========== invalid_non_virtual_annotation ==========
class _BadNonVirtual {
  @nonVirtual
  static void s() {} // expect_lint: invalid_non_virtual_annotation
}

// invalid_field_name: keyword record labels are rejected by the parser, so no BAD line here.

// ========== GOOD / false-positive guards (no expect_lint on these declarations) ==========

class _SingleCtorOk {
  _SingleCtorOk();
}

class _CtorStaticNoConflict {
  _CtorStaticNoConflict.bar();
  static void baz() {}
}

typedef _RecordOk = ({int a, int b});

void _recordLiteralOk() {
  final ({int left, int right}) ok = (left: 1, right: 2);
  if (ok.left + ok.right == 0) {
    throw StateError('unreachable');
  }
}

class _RedirectOk {
  _RedirectOk() : this.named(0);
  _RedirectOk.named(int x);
}

class _SuperParentOk {
  _SuperParentOk(int a);
}

class _SuperChildOk extends _SuperParentOk {
  _SuperChildOk(super.a);
}

enum _EnumOk {
  one,
  two;

  int extra() => 1;
}

void _extensionOverrideOk() {
  _Plan2130Ext(42).m();
}

class _LiteralOk {
  @literal
  const _LiteralOk();
}

class _NonVirtualOk {
  @nonVirtual
  void instanceMethod() {}
}
