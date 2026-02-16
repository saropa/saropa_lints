// ignore_for_file: unused_local_variable, unused_element, avoid_print
// ignore_for_file: depend_on_referenced_packages, prefer_const_constructors
// ignore_for_file: unnecessary_import, unused_import
// ignore_for_file: avoid_unused_constructor_parameters, override_on_non_overriding_member
// ignore_for_file: annotate_overrides, duplicate_ignore
// ignore_for_file: non_abstract_class_inherits_abstract_member, extends_non_class
// ignore_for_file: mixin_of_non_class, field_initializer_outside_constructor
// ignore_for_file: final_not_initialized, super_in_invalid_context
// ignore_for_file: concrete_class_with_abstract_member, type_argument_not_matching_bounds
// ignore_for_file: missing_required_argument, undefined_named_parameter
// ignore_for_file: argument_type_not_assignable, invalid_constructor_name
// ignore_for_file: super_formal_parameter_without_associated_named, undefined_annotation
// ignore_for_file: creation_with_non_type, invalid_factory_name_not_a_class
// ignore_for_file: invalid_reference_to_this, expected_class_member
// ignore_for_file: body_might_complete_normally, not_initialized_non_nullable_instance_field
// ignore_for_file: unchecked_use_of_nullable_value, return_of_invalid_type
// ignore_for_file: use_of_void_result, missing_function_body
// ignore_for_file: extra_positional_arguments, not_enough_positional_arguments
// ignore_for_file: unused_label, unused_element_parameter
// ignore_for_file: non_type_as_type_argument, expected_identifier_but_got_keyword
// ignore_for_file: expected_token, missing_identifier
// ignore_for_file: unexpected_token, duplicate_definition
// ignore_for_file: override_on_non_overriding_member, extends_non_class
// ignore_for_file: no_default_super_constructor, extra_positional_arguments_could_be_named
// ignore_for_file: missing_function_parameters, invalid_annotation
// ignore_for_file: invalid_assignment, expected_executable
// ignore_for_file: named_parameter_outside_group, obsolete_colon_for_default_value
// ignore_for_file: referenced_before_declaration, await_in_wrong_context
// ignore_for_file: non_type_in_catch_clause, could_not_infer
// ignore_for_file: uri_does_not_exist, const_method
// ignore_for_file: redirect_to_non_class, unused_catch_clause
// ignore_for_file: type_test_with_undefined_name, undefined_identifier
// ignore_for_file: undefined_function, undefined_method
// ignore_for_file: undefined_getter, undefined_setter
// ignore_for_file: undefined_class, undefined_super_member
// ignore_for_file: extraneous_modifier, experiment_not_enabled
// ignore_for_file: missing_const_final_var_or_type, undefined_operator
// ignore_for_file: dead_code, invalid_override
// ignore_for_file: not_initialized_non_nullable_variable, list_element_type_not_assignable
// ignore_for_file: assignment_to_final, equal_elements_in_set
// ignore_for_file: prefix_shadowed_by_local_declaration, const_initialized_with_non_constant_value
// ignore_for_file: non_constant_list_element, missing_statement
// ignore_for_file: unnecessary_cast, unnecessary_null_comparison
// ignore_for_file: unnecessary_type_check, invalid_super_formal_parameter_location
// ignore_for_file: assignment_to_type, instance_member_access_from_factory
// ignore_for_file: field_initializer_not_assignable, constant_pattern_with_non_constant_expression
// ignore_for_file: undefined_identifier_await, cast_to_non_type
// ignore_for_file: read_potentially_unassigned_final, mixin_with_non_class_superclass
// ignore_for_file: instantiate_abstract_class, dead_code_on_catch_subtype
// ignore_for_file: unreachable_switch_case, new_with_undefined_constructor
// ignore_for_file: assignment_to_final_local, late_final_local_already_assigned
// ignore_for_file: missing_default_value_for_parameter, non_bool_condition
// ignore_for_file: non_exhaustive_switch_expression, illegal_async_return_type
// ignore_for_file: type_test_with_non_type, invocation_of_non_function_expression
// ignore_for_file: return_of_invalid_type_from_closure, wrong_number_of_type_arguments_constructor
// ignore_for_file: definitely_unassigned_late_local_variable, static_access_to_instance_member
// ignore_for_file: const_with_undefined_constructor, abstract_super_member_reference
// ignore_for_file: equal_keys_in_map, unused_catch_stack
// ignore_for_file: non_constant_default_value, not_a_type
// Test fixture for testing rules

import 'package:saropa_lints_example/flutter_mocks.dart';

// =========================================================================
// prefer_test_find_by_key
// =========================================================================
// Warns when find.byType is used instead of find.byKey for interactions.

void badTestFindByType() {
  testWidgets('should tap button', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MyWidget()));
    // expect_lint: prefer_test_find_by_key
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
  });
}

void goodTestFindByKey() {
  testWidgets('should tap button', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MyWidget()));
    await tester.tap(find.byKey(Key('submit_button'))); // Good - stable
    await tester.pump();
  });
}

// =========================================================================
// prefer_setup_teardown
// =========================================================================
// Warns when test setup is duplicated across multiple tests.

void badRepeatedSetup() {
  test('test 1', () {
    // expect_lint: prefer_setup_teardown
    final repo = MockRepository();
    final bloc = MyBloc(repo);
    // ... test logic
  });

  test('test 2', () {
    // expect_lint: prefer_setup_teardown
    final repo = MockRepository();
    final bloc = MyBloc(repo);
    // ... test logic
  });

  test('test 3', () {
    // expect_lint: prefer_setup_teardown
    final repo = MockRepository();
    final bloc = MyBloc(repo);
    // ... test logic
  });
}

void goodWithSetUp() {
  late MockRepository repo;
  late MyBloc bloc;

  setUp(() {
    repo = MockRepository();
    bloc = MyBloc(repo);
  });

  test('test 1', () {
    // ... test logic
  });
}

// OK: Assertion/verification calls should not be treated as setup code.
// expect(), verify(), fail() etc. are test body, not initialization.
void goodRepeatedAssertions() {
  group('documented behavior', () {
    test('case A', () {
      expect(true, isTrue, reason: 'Verified via code review');
    });

    test('case B', () {
      expect(true, isTrue, reason: 'Verified via code review');
    });

    test('case C', () {
      expect(true, isTrue, reason: 'Verified via code review');
    });
  });
}

// OK: Repeated await expectLater() should also not trigger.
void goodRepeatedAwaitAssertions() {
  group('stream tests', () {
    test('stream A', () async {
      await expectLater(stream, emitsInOrder([1, 2]));
    });

    test('stream B', () async {
      await expectLater(stream, emitsInOrder([1, 2]));
    });

    test('stream C', () async {
      await expectLater(stream, emitsInOrder([1, 2]));
    });
  });
}

// OK: Tests in different groups should not count toward the same threshold.
void goodCrossGroupNotCounted() {
  group('group A', () {
    test('test 1', () {
      final repo = MockRepository();
    });
  });

  group('group B', () {
    test('test 2', () {
      final repo = MockRepository();
    });
  });

  group('group C', () {
    test('test 3', () {
      final repo = MockRepository();
    });
  });
}

// OK: Independent primitive locals should not trigger prefer_setup_teardown.
// Each test declares its own counter/constant — these are not shared setup.
void goodRepeatedPrimitiveLocals() {
  test('default probability', () {
    int trueCount = 0;
    const int iterations = 1000;
    // ... loop and assertions
  });

  test('low probability', () {
    int trueCount = 0;
    const int iterations = 1000;
    // ... loop and assertions
  });

  test('high probability', () {
    int trueCount = 0;
    const int iterations = 1000;
    // ... loop and assertions
  });
}

// =========================================================================
// require_test_description_convention
// =========================================================================
// Warns when test descriptions are vague.

void badVagueTestNames() {
  // expect_lint: require_test_description_convention
  test('test 1', () {});

  // expect_lint: require_test_description_convention
  test('it works', () {});

  // expect_lint: require_test_description_convention
  test('MyBloc', () {});
}

void goodDescriptiveTestNames() {
  test('should emit Loading then Success when fetch succeeds', () {});
  test('returns null when user not found', () {});
}

// =========================================================================
// prefer_bloc_test_package
// =========================================================================
// Warns when Bloc is tested manually instead of using blocTest().

void badManualBlocTest() {
  test('MyBloc emits states', () async {
    // expect_lint: prefer_bloc_test_package
    final bloc = MyBloc();
    bloc.add(MyEvent());
    await expectLater(
      bloc.stream,
      emitsInOrder([MyState()]),
    );
  });
}

void goodBlocTestPackage() {
  blocTest<MyBloc, MyState>(
    'emits [Loading, Success] when MyEvent added',
    build: () => MyBloc(),
    act: (bloc) => bloc.add(MyEvent()),
    expect: () => [Loading(), Success()],
  );
}

// =========================================================================
// prefer_mock_verify
// =========================================================================
// Warns when mocks are set up with when() but never verified.

void badNoVerify() {
  test('creates user', () async {
    // expect_lint: prefer_mock_verify
    final mockRepo = MockUserRepository();
    when(mockRepo.create(any)).thenAnswer((_) async => User());
    await useCase.execute(userData);
    // Missing: verify(mockRepo.create(any)).called(1);
  });
}

void goodWithVerify() {
  test('creates user', () async {
    final mockRepo = MockUserRepository();
    when(mockRepo.create(any)).thenAnswer((_) async => User());
    await useCase.execute(userData);
    verify(mockRepo.create(any)).called(1); // Good - verified
  });
}

// =========================================================================
// Mock classes for testing
// =========================================================================

class MockRepository {}

class MockUserRepository {
  Future<User> create(dynamic data) async => User();
}

class MyBloc {
  MyBloc([MockRepository? repo]);
  void add(dynamic event) {}
  Stream<dynamic> get stream => Stream.empty();
}

class MyEvent {}

class MyState {}

class Loading extends MyState {}

class Success extends MyState {}

class User {}

class UseCase {
  Future<void> execute(dynamic data) async {}
}

final useCase = UseCase();
final userData = {};
