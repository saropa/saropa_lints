// ignore_for_file: unused_local_variable, prefer_const_constructors
// ignore_for_file: unused_element, avoid_print
// Test fixture for BlocProvider rules

import '../flutter_mocks.dart';

// Mock Bloc classes for testing
class AuthBloc extends Bloc<Object, Object> {
  AuthBloc() : super(Object());
}

class UserBloc extends Bloc<Object, Object> {
  UserBloc() : super(Object());
}

void testPreferMultiBlocProvider() {
  // BAD: Nested BlocProviders
  // expect_lint: prefer_multi_bloc_provider
  final bad1 = BlocProvider<AuthBloc>(
    create: (_) => AuthBloc(),
    child: BlocProvider<UserBloc>(
      create: (_) => UserBloc(),
      child: Container(),
    ),
  );

  // GOOD: Using MultiBlocProvider
  final good1 = MultiBlocProvider(
    providers: [
      BlocProvider<AuthBloc>(create: (_) => AuthBloc()),
      BlocProvider<UserBloc>(create: (_) => UserBloc()),
    ],
    child: Container(),
  );
}

void testAvoidInstantiatingInBlocValueProvider() {
  // BAD: Creating new instance in BlocProvider.value
  final bad1 = BlocProvider.value(
    // expect_lint: avoid_instantiating_in_bloc_value_provider
    value: AuthBloc(), // New instance - won't be closed!
    child: Container(),
  );

  final existingBloc = AuthBloc();

  // GOOD: Using existing instance in value
  final good1 = BlocProvider.value(
    value: existingBloc,
    child: Container(),
  );

  // GOOD: Creating new instance with create
  final good2 = BlocProvider<AuthBloc>(
    create: (_) => AuthBloc(),
    child: Container(),
  );
}

void testAvoidExistingInstancesInBlocProvider() {
  final existingBloc = AuthBloc();

  // BAD: Returning existing variable from create
  final bad1 = BlocProvider<AuthBloc>(
    // expect_lint: avoid_existing_instances_in_bloc_provider
    create: (_) => existingBloc, // Will close existing bloc!
    child: Container(),
  );

  // GOOD: Creating new instance in create
  final good1 = BlocProvider<AuthBloc>(
    create: (_) => AuthBloc(),
    child: Container(),
  );

  // GOOD: Using existing instance with value
  final good2 = BlocProvider.value(
    value: existingBloc,
    child: Container(),
  );
}

class TestWidget extends StatelessWidget {
  const TestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // BAD: Using context.read in create
    // expect_lint: prefer_correct_bloc_provider
    return BlocProvider<AuthBloc>(
      create: (_) => context.read<AuthBloc>(),
      child: Container(),
    );
  }
}

class GoodTestWidget extends StatelessWidget {
  const GoodTestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // GOOD: Using value for existing bloc from context
    return BlocProvider.value(
      value: context.read<AuthBloc>(),
      child: Container(),
    );
  }
}
