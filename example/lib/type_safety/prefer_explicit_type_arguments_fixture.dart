// ignore_for_file: unused_local_variable, unused_element, prefer_final_locals
// Test fixture for prefer_explicit_type_arguments rule
//
// This rule warns when generic types lack explicit type arguments.
// It's especially important for empty literals where the type is ambiguous.

import 'dart:async';

/// Tests prefer_explicit_type_arguments rule.
///
/// NOTE: This is a stylistic rule that conflicts with avoid_inferrable_type_arguments.
/// Only enable one or the other, not both.
void testPreferExplicitTypeArguments() {
  // =========================================================================
  // BAD: Empty list literals (type is ambiguous)
  // These SHOULD trigger the rule
  // =========================================================================

  // BAD - type is completely ambiguous (infers List<dynamic>)
  final emptyList = [];

  // BAD - literal has no type args even though variable is typed
  List<String> typedEmptyList = [];

  // =========================================================================
  // BAD: Empty set/map literals (type is ambiguous)
  // These SHOULD trigger the rule
  // =========================================================================

  // BAD - type is ambiguous
  final emptyMap = {};

  // BAD - literal has no type args
  Map<String, int> typedEmptyMap = {};

  // =========================================================================
  // BAD: Generic constructor calls without explicit type arguments
  // These SHOULD trigger the rule
  // =========================================================================

  // BAD - type is inferred from value but not explicit
  final future = Future.value(42);

  // BAD - type defaults to dynamic
  final completer = Completer();

  // BAD - type defaults to dynamic
  final streamController = StreamController();

  // =========================================================================
  // GOOD: Explicit type arguments on list literals
  // These should NOT trigger the rule
  // =========================================================================

  final explicitEmptyList = <String>[];
  final explicitList = <int>[1, 2, 3];

  // =========================================================================
  // GOOD: Explicit type arguments on set/map literals
  // These should NOT trigger the rule
  // =========================================================================

  final explicitEmptySet = <String>{};
  final explicitSet = <int>{1, 2, 3};
  final explicitEmptyMap = <String, int>{};
  final explicitMap = <String, int>{'a': 1, 'b': 2};

  // =========================================================================
  // GOOD: Explicit type arguments on generic constructors
  // These should NOT trigger the rule
  // =========================================================================

  final explicitFuture = Future<int>.value(42);
  final explicitCompleter = Completer<String>();
  final explicitStreamController = StreamController<int>();

  // =========================================================================
  // EDGE CASES: Non-empty literals with inferrable types
  // Current implementation only flags EMPTY literals
  // =========================================================================

  // OK in current implementation - type inferred from elements
  final inferredList = [1, 2, 3];
  final inferredMap = {'a': 1};
}

/// Test with class fields
class TypeArgumentsTestClass {
  // BAD - literal has no type args
  final List<String> items = [];

  // GOOD - explicit type on literal
  final List<String> explicitItems = <String>[];
}
