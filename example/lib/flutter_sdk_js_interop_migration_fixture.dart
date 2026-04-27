// ignore_for_file: argument_type_not_assignable
//
// Test fixture: dart:js_interop SDK migrations (#091–#093)
// Source: lib/src/rules/config/flutter_sdk_migration_rules.dart
//
// Imports dart:js_interop so analyzer resolution matches the real SDK. Some BAD
// lines are intentionally ill-typed vs post–Dart 3.2 signatures; the plugin
// still flags legacy shapes from static types and resolved members.

import 'dart:js_interop';

void avoidLegacyJsBooleanReturnAssumptionsBad(JSAny? o, JSFunction ctor) {
  // expect_lint: avoid_legacy_jsboolean_return_assumptions
  final _ = (o.typeofEquals('object') as dynamic).toDart;
  // expect_lint: avoid_legacy_jsboolean_return_assumptions
  final __ = (o.instanceof(ctor) as dynamic).toDart;
}

bool avoidLegacyJsBooleanReturnAssumptionsGood(JSAny? o, JSFunction ctor) {
  return o.typeofEquals('object') && o.instanceof(ctor);
}

void preferStringForTypeofEqualsBad(JSAny? o, JSString s) {
  // expect_lint: prefer_string_for_typeof_equals
  o.typeofEquals(s);
}

void preferStringForTypeofEqualsGood(JSAny? o) {
  o.typeofEquals('object');
}

void preferIntForJsarrayWithLengthBad(JSNumber n) {
  // expect_lint: prefer_int_for_jsarray_with_length
  JSArray<JSAny?>.withLength(n);
}

void preferIntForJsarrayWithLengthGood(int n) {
  JSArray<JSAny?>.withLength(n);
}
