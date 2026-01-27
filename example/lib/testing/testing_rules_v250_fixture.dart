// ignore_for_file: unused_local_variable, unused_element, avoid_print
// Test fixture for testing rules added in v2.5.0

import '../flutter_mocks.dart';

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
