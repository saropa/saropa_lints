// ignore_for_file: unused_local_variable, unused_element, prefer_const_constructors
// Test fixture for state management rules added in v2.5.0

import '../flutter_mocks.dart';

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
// State Management Rules (from v4.1.4)
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
// State Management Rules (from v4.1.7)
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
