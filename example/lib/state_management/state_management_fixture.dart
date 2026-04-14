// ignore_for_file: unused_local_variable, unused_element, prefer_const_constructors
// ignore_for_file: ambiguous_extension_member_access
// ignore_for_file: depend_on_referenced_packages, unnecessary_import
// ignore_for_file: unused_import, avoid_unused_constructor_parameters
// ignore_for_file: override_on_non_overriding_member, annotate_overrides
// ignore_for_file: duplicate_ignore, non_abstract_class_inherits_abstract_member
// ignore_for_file: extends_non_class, mixin_of_non_class
// ignore_for_file: field_initializer_outside_constructor, final_not_initialized
// ignore_for_file: super_in_invalid_context, concrete_class_with_abstract_member
// ignore_for_file: type_argument_not_matching_bounds, missing_required_argument
// ignore_for_file: undefined_named_parameter, argument_type_not_assignable
// ignore_for_file: invalid_constructor_name, super_formal_parameter_without_associated_named
// ignore_for_file: undefined_annotation, creation_with_non_type
// ignore_for_file: invalid_factory_name_not_a_class, invalid_reference_to_this
// ignore_for_file: expected_class_member, body_might_complete_normally
// ignore_for_file: not_initialized_non_nullable_instance_field, unchecked_use_of_nullable_value
// ignore_for_file: return_of_invalid_type, use_of_void_result
// ignore_for_file: missing_function_body, extra_positional_arguments
// ignore_for_file: not_enough_positional_arguments, unused_label
// ignore_for_file: unused_element_parameter, non_type_as_type_argument
// ignore_for_file: expected_identifier_but_got_keyword, expected_token
// ignore_for_file: missing_identifier, unexpected_token
// ignore_for_file: duplicate_definition, override_on_non_overriding_member
// ignore_for_file: extends_non_class, no_default_super_constructor
// ignore_for_file: extra_positional_arguments_could_be_named, missing_function_parameters
// ignore_for_file: invalid_annotation, invalid_assignment
// ignore_for_file: expected_executable, named_parameter_outside_group
// ignore_for_file: obsolete_colon_for_default_value, referenced_before_declaration
// ignore_for_file: await_in_wrong_context, non_type_in_catch_clause
// ignore_for_file: could_not_infer, uri_does_not_exist
// ignore_for_file: const_method, redirect_to_non_class
// ignore_for_file: unused_catch_clause, type_test_with_undefined_name
// ignore_for_file: undefined_identifier, undefined_function
// ignore_for_file: undefined_method, undefined_getter
// ignore_for_file: undefined_setter, undefined_class
// ignore_for_file: undefined_super_member, extraneous_modifier
// ignore_for_file: experiment_not_enabled, missing_const_final_var_or_type
// ignore_for_file: undefined_operator, dead_code
// ignore_for_file: invalid_override, not_initialized_non_nullable_variable
// ignore_for_file: list_element_type_not_assignable, assignment_to_final
// ignore_for_file: equal_elements_in_set, prefix_shadowed_by_local_declaration
// ignore_for_file: const_initialized_with_non_constant_value, non_constant_list_element
// ignore_for_file: missing_statement, unnecessary_cast
// ignore_for_file: unnecessary_null_comparison, unnecessary_type_check
// ignore_for_file: invalid_super_formal_parameter_location, assignment_to_type
// ignore_for_file: instance_member_access_from_factory, field_initializer_not_assignable
// ignore_for_file: constant_pattern_with_non_constant_expression, undefined_identifier_await
// ignore_for_file: cast_to_non_type, read_potentially_unassigned_final
// ignore_for_file: mixin_with_non_class_superclass, instantiate_abstract_class
// ignore_for_file: dead_code_on_catch_subtype, unreachable_switch_case
// ignore_for_file: new_with_undefined_constructor, assignment_to_final_local
// ignore_for_file: late_final_local_already_assigned, missing_default_value_for_parameter
// ignore_for_file: non_bool_condition, non_exhaustive_switch_expression
// ignore_for_file: illegal_async_return_type, type_test_with_non_type
// ignore_for_file: invocation_of_non_function_expression, return_of_invalid_type_from_closure
// ignore_for_file: wrong_number_of_type_arguments_constructor, definitely_unassigned_late_local_variable
// ignore_for_file: static_access_to_instance_member, const_with_undefined_constructor
// ignore_for_file: abstract_super_member_reference, equal_keys_in_map
// ignore_for_file: unused_catch_stack, non_constant_default_value
// ignore_for_file: not_a_type
// Test fixture for state management rules

import 'package:saropa_lints_example/flutter_mocks.dart';

// =========================================================================
// prefer_change_notifier_proxy
// =========================================================================
// Warns when Provider.of is used without listen: false in callbacks.

void badProviderOfInCallback() {
  // expect_lint: prefer_change_notifier_proxy
  ChangeNotifierProvider(
    create: (context) => MyNotifier(
      Provider.of<OtherNotifier>(context, listen: false),
    ),
  );
}

void goodProxyProvider() {
  ChangeNotifierProxyProvider<OtherNotifier, MyNotifier>(
    create: (_) => MyNotifier(null),
    update: (_, other, my) => my!..updateWith(other),
  );
}

// =========================================================================
// prefer_selector_widget
// =========================================================================
// Warns when Consumer rebuilds on any change when only using one field.

void badConsumerFullRebuild() {
  // expect_lint: prefer_selector_widget
  Consumer<UserModel>(
    builder: (_, user, __) => Text(user.name), // Only uses name!
  );
}

void goodSelector() {
  Selector<UserModel, String>(
    selector: (_, user) => user.name,
    builder: (_, name, __) => Text(name), // Only rebuilds when name changes
  );
}

// =========================================================================
// require_bloc_event_sealed
// =========================================================================
// Warns when Bloc event classes are not sealed.

// BAD - Not exhaustive
// expect_lint: require_bloc_event_sealed
abstract class CounterEvent {}

class Increment extends CounterEvent {}

class Decrement extends CounterEvent {}

// GOOD - Exhaustive pattern matching
sealed class GoodCounterEvent {}

class GoodIncrement extends GoodCounterEvent {}

class GoodDecrement extends GoodCounterEvent {}

// =========================================================================
// require_bloc_repository_abstraction
// =========================================================================
// Warns when Bloc has concrete repository dependencies.

// BAD - Concrete dependency
class BadBloc extends Bloc<Object, Object> {
  // expect_lint: require_bloc_repository_abstraction
  final FirebaseUserRepository _repo; // Concrete!

  BadBloc(this._repo) : super(Object());
}

// GOOD - Abstract dependency
class GoodBloc extends Bloc<Object, Object> {
  final UserRepository _repo; // Abstract interface

  GoodBloc(this._repo) : super(Object());
}

abstract class UserRepository {}

class FirebaseUserRepository implements UserRepository {}

// =========================================================================
// avoid_getx_global_state
// =========================================================================
// Warns when Get.put/Get.find are used for global state.

void badGetxGlobalState() {
  // expect_lint: avoid_getx_global_state
  Get.put(MyController());

  // expect_lint: avoid_getx_global_state
  final controller = Get.find<MyController>();
}

void goodGetxBinding() {
  // Use bindings for scoped injection
  GetPage(
    name: '/home',
    page: () => HomePage(),
    binding: HomeBinding(),
  );
}

// =========================================================================
// prefer_bloc_transform
// =========================================================================
// Warns when search events don't use debounce/throttle transformer.

class BadSearchBloc extends Bloc<SearchEvent, SearchState> {
  BadSearchBloc() : super(SearchInitial()) {
    // expect_lint: prefer_bloc_transform
    on<SearchQueryChanged>((event, emit) async {
      await Future.delayed(Duration(milliseconds: 300)); // Manual debounce
      // ... search logic
    });
  }
}

class GoodSearchBloc extends Bloc<SearchEvent, SearchState> {
  GoodSearchBloc() : super(SearchInitial()) {
    on<SearchQueryChanged>(
      _onSearch,
      transformer: debounce(Duration(milliseconds: 300)), // Proper transformer
    );
  }

  void _onSearch(SearchQueryChanged event, Emitter<SearchState> emit) {
    // ... search logic
  }
}

// =========================================================================
// Mock classes for testing
// =========================================================================

class MyNotifier extends ChangeNotifier {
  MyNotifier(OtherNotifier? other);
  void updateWith(OtherNotifier? other) {}
}

class OtherNotifier extends ChangeNotifier {}

class UserModel {
  final String name;
  UserModel(this.name);
}

class MyController {}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container();
}

class HomeBinding extends Bindings {
  @override
  void dependencies() {}
}

// Bloc mocks
sealed class SearchEvent {}

class SearchQueryChanged extends SearchEvent {
  final String query;
  SearchQueryChanged(this.query);
}

sealed class SearchState {}

class SearchInitial extends SearchState {}

EventTransformer<T> debounce<T>(Duration duration) {
  return (events, mapper) => events;
}

// =========================================================================
// State Management Rules
// =========================================================================

class AuthService extends ChangeNotifier {}

class UserNotifier extends ChangeNotifier {
  void updateAuth(AuthService auth) {}
}

void testChangeNotifierProxyProvider(BuildContext context) {
  // expect_lint: prefer_change_notifier_proxy_provider
  ChangeNotifierProvider(
    create: (context) {
      final auth = context.read<AuthService>();
      return UserNotifier()..updateAuth(auth);
    },
    child: Container(),
  );

  // GOOD: Using ProxyProvider
  ChangeNotifierProxyProvider<AuthService, UserNotifier>(
    create: (_) => UserNotifier(),
    update: (_, auth, previous) => previous!..updateAuth(auth),
    child: Container(),
  );
}

class ChangeNotifierProvider<T extends ChangeNotifier> {
  ChangeNotifierProvider({required this.create, this.child});
  final T Function(BuildContext) create;
  final Widget? child;
}

class ChangeNotifierProxyProvider<A, T extends ChangeNotifier> {
  ChangeNotifierProxyProvider({
    required this.create,
    required this.update,
    this.child,
  });
  final T Function(BuildContext) create;
  final T Function(BuildContext, A, T?) update;
  final Widget? child;
}

extension BuildContextRead on BuildContext {
  T read<T>() => throw UnimplementedError();
}

// =========================================================================
// State Management Rules (continued)
// =========================================================================

// BAD: Riverpod used only for network client
// expect_lint: avoid_riverpod_for_network_only
final apiProvider = ProviderDemo((ref) => ApiClientDemo());

// GOOD: Riverpod with actual state management
final userProvider = ProviderDemo((ref) {
  final api = ref.watch(apiProvider);
  return UserServiceDemo(api);
});

// BAD: Large Bloc with too many handlers
// expect_lint: avoid_large_bloc
class KitchenSinkBloc extends Bloc<AppEvent, AppState> {
  KitchenSinkBloc() : super(AppState()) {
    on<LoadUser>(_onLoadUser);
    on<UpdateProfile>(_onUpdateProfile);
    on<LoadOrders>(_onLoadOrders);
    on<ProcessPayment>(_onProcessPayment);
    on<SendNotification>(_onSendNotification);
    on<UpdateSettings>(_onUpdateSettings);
    on<RefreshData>(_onRefreshData);
    on<SyncData>(_onSyncData);
  }

  void _onLoadUser(LoadUser event, Emitter<AppState> emit) {}
  void _onUpdateProfile(UpdateProfile event, Emitter<AppState> emit) {}
  void _onLoadOrders(LoadOrders event, Emitter<AppState> emit) {}
  void _onProcessPayment(ProcessPayment event, Emitter<AppState> emit) {}
  void _onSendNotification(SendNotification event, Emitter<AppState> emit) {}
  void _onUpdateSettings(UpdateSettings event, Emitter<AppState> emit) {}
  void _onRefreshData(RefreshData event, Emitter<AppState> emit) {}
  void _onSyncData(SyncData event, Emitter<AppState> emit) {}
}

// GOOD: Focused Bloc
class FocusedUserBloc extends Bloc<UserEvent, UserState> {
  FocusedUserBloc() : super(UserState()) {
    on<LoadUserEvent>(_onLoadUser);
    on<UpdateUserEvent>(_onUpdateUser);
  }

  void _onLoadUser(LoadUserEvent event, Emitter<UserState> emit) {}
  void _onUpdateUser(UpdateUserEvent event, Emitter<UserState> emit) {}
}

// BAD: GetX static context usage
void navigateWithGetX() {
  // expect_lint: avoid_getx_static_context
  GetDemo.offNamed('/home');

  // expect_lint: avoid_getx_static_context
  GetDemo.dialog(Container());
}

// Mock classes for v417 state management
class ProviderDemo<T> {
  final T Function(dynamic ref) create;
  ProviderDemo(this.create);
}

class ApiClientDemo {}

class UserServiceDemo {
  UserServiceDemo(ApiClientDemo api);
}

class AppEvent {}

class LoadUser extends AppEvent {}

class UpdateProfile extends AppEvent {}

class LoadOrders extends AppEvent {}

class ProcessPayment extends AppEvent {}

class SendNotification extends AppEvent {}

class UpdateSettings extends AppEvent {}

class RefreshData extends AppEvent {}

class SyncData extends AppEvent {}

class AppState {}

class UserEvent {}

class LoadUserEvent extends UserEvent {}

class UpdateUserEvent extends UserEvent {}

class UserState {}

typedef Emitter<S> = void Function(S);

class GetDemo {
  static void offNamed(String route) {}
  static void dialog(Widget widget) {}
}
