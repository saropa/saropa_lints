# Using saropa_lints with Bloc

This guide explains how saropa_lints enhances your Bloc/Cubit development with specialized rules that catch common anti-patterns.

## What Bloc Issues Are Caught

Bloc enforces strict separation of concerns, but has subtle patterns that cause bugs, memory leaks, and state corruption.

| Issue Type | What Happens | Rule |
|------------|--------------|------|
| Events in constructor | Race conditions, missed events | `avoid_bloc_event_in_constructor` |
| Mutable state | Unpredictable behavior | `require_immutable_bloc_state` |
| Unclosed Blocs | Memory leaks | `require_bloc_close` |
| Mutable events | State corruption | `avoid_bloc_event_mutation` |
| BlocListener in build | Callback leaks | `avoid_bloc_listen_in_build` |
| Nested Blocs | Tight coupling | `avoid_bloc_in_bloc` |
| Missing transformer | Event flooding | `require_bloc_transformer` |
| Missing BlocObserver | No debugging visibility | `require_bloc_observer` |

## What saropa_lints Catches

### Events in Constructor

```dart
// BAD - event may be processed before listeners attached
class UserBloc extends Bloc<UserEvent, UserState> {
  UserBloc() : super(UserInitial()) {
    on<LoadUser>(_onLoadUser);
    add(LoadUser());  // Called in constructor!
  }
}

// GOOD - add event after Bloc is fully constructed
class UserBloc extends Bloc<UserEvent, UserState> {
  UserBloc() : super(UserInitial()) {
    on<LoadUser>(_onLoadUser);
  }
}

// In widget:
BlocProvider(
  create: (context) => UserBloc()..add(LoadUser()),  // After construction
  child: UserView(),
)
```

**Rule**: `avoid_bloc_event_in_constructor`

### Mutable State

```dart
// BAD - mutable state causes unpredictable behavior
class UserState {
  List<User> users;  // Mutable!
  bool isLoading;

  UserState({required this.users, required this.isLoading});
}

// State can be modified outside Bloc
final state = bloc.state;
state.users.add(newUser);  // Mutation! Breaks Bloc pattern

// GOOD - immutable state with Equatable
class UserState extends Equatable {
  final List<User> users;
  final bool isLoading;

  const UserState({required this.users, required this.isLoading});

  @override
  List<Object?> get props => [users, isLoading];

  UserState copyWith({List<User>? users, bool? isLoading}) {
    return UserState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
```

**Rule**: `require_immutable_bloc_state`

### Unclosed Blocs

```dart
// BAD - Bloc never closed, streams leak
class _MyWidgetState extends State<MyWidget> {
  late final UserBloc _userBloc;

  @override
  void initState() {
    super.initState();
    _userBloc = UserBloc();
  }

  // Missing dispose()!
}

// GOOD - close Bloc in dispose
class _MyWidgetState extends State<MyWidget> {
  late final UserBloc _userBloc;

  @override
  void initState() {
    super.initState();
    _userBloc = UserBloc();
  }

  @override
  void dispose() {
    _userBloc.close();
    super.dispose();
  }
}

// BETTER - use BlocProvider (handles lifecycle automatically)
BlocProvider(
  create: (context) => UserBloc(),
  child: UserView(),
)
```

**Rule**: `require_bloc_close`

### Mutable Events

```dart
// BAD - mutable events can be modified after dispatch
class AddItem extends CartEvent {
  List<String> tags;  // Mutable!

  AddItem(this.tags);
}

// Event can be modified after being added
final event = AddItem(['sale']);
bloc.add(event);
event.tags.add('featured');  // Mutation! Corrupts event

// GOOD - immutable events
class AddItem extends CartEvent {
  final List<String> tags;

  const AddItem(this.tags);

  @override
  List<Object?> get props => [tags];
}
```

**Rule**: `avoid_bloc_event_mutation`

### BlocListener in Build

```dart
// BAD - listener recreated on every build
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // Listener may be called multiple times!
      },
      child: buildContent(),
    );
  }
}

// GOOD - use BlocConsumer or wrap in stable widget
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          showSnackBar(context, state.message);
        }
      },
      builder: (context, state) {
        return buildContent(state);
      },
    );
  }
}
```

**Rule**: `avoid_bloc_listen_in_build`

### Nested Blocs

```dart
// BAD - Bloc depending on another Bloc creates tight coupling
class OrderBloc extends Bloc<OrderEvent, OrderState> {
  final UserBloc userBloc;  // Tight coupling!

  OrderBloc(this.userBloc) : super(OrderInitial()) {
    on<PlaceOrder>((event, emit) async {
      final userId = userBloc.state.user?.id;  // Direct access
      // ...
    });
  }
}

// GOOD - pass data via events, not Bloc references
class OrderBloc extends Bloc<OrderEvent, OrderState> {
  OrderBloc() : super(OrderInitial()) {
    on<PlaceOrder>((event, emit) async {
      final userId = event.userId;  // Data in event
      // ...
    });
  }
}

class PlaceOrder extends OrderEvent {
  final String userId;
  const PlaceOrder({required this.userId});
}
```

**Rule**: `avoid_bloc_in_bloc`

### Missing Event Transformer

```dart
// BAD - rapid events can flood the Bloc
on<SearchTextChanged>((event, emit) async {
  final results = await search(event.query);  // Called for every keystroke!
  emit(SearchResults(results));
});

// GOOD - use transformer to debounce
on<SearchTextChanged>(
  (event, emit) async {
    final results = await search(event.query);
    emit(SearchResults(results));
  },
  transformer: debounce(const Duration(milliseconds: 300)),
);

// Or use restartable for search-as-you-type
on<SearchTextChanged>(
  (event, emit) async {
    final results = await search(event.query);
    emit(SearchResults(results));
  },
  transformer: restartable(),
);
```

**Rule**: `require_bloc_transformer`

### Missing BlocObserver

```dart
// BAD - no visibility into Bloc events/transitions
void main() {
  runApp(MyApp());
}

// GOOD - BlocObserver for debugging and monitoring
void main() {
  Bloc.observer = AppBlocObserver();
  runApp(MyApp());
}

class AppBlocObserver extends BlocObserver {
  @override
  void onEvent(Bloc bloc, Object? event) {
    super.onEvent(bloc, event);
    debugPrint('${bloc.runtimeType} $event');
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    // Log to error tracking service
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    debugPrint('${bloc.runtimeType} $transition');
  }
}
```

**Rule**: `require_bloc_observer`

## Recommended Setup

### 1. Update pubspec.yaml

```yaml
dependencies:
  flutter_bloc: ^8.1.0
  equatable: ^2.0.0

dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^1.3.0
  bloc_test: ^9.1.0
```

### 2. Update analysis_options.yaml

```yaml
analyzer:
  plugins:
    - custom_lint

custom_lint:
  saropa_lints:
    tier: recommended  # essential | recommended | professional | comprehensive | insanity
```

### 3. Run the linter

```bash
dart run custom_lint
```

## Rule Summary

| Rule | Tier | What It Catches |
|------|------|-----------------|
| `avoid_bloc_event_in_constructor` | essential | Events added in Bloc constructor |
| `require_bloc_close` | essential | Blocs not closed in dispose |
| `require_immutable_bloc_state` | recommended | Mutable state classes |
| `avoid_bloc_event_mutation` | recommended | Mutable event classes |
| `avoid_bloc_listen_in_build` | recommended | BlocListener in build method |
| `avoid_bloc_in_bloc` | professional | Bloc referencing another Bloc |
| `require_bloc_transformer` | professional | Missing event transformer |
| `require_bloc_observer` | comprehensive | Missing BlocObserver in main |

## Common Patterns

### Freezed for Immutable State

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_state.freezed.dart';

@freezed
class UserState with _$UserState {
  const factory UserState.initial() = UserInitial;
  const factory UserState.loading() = UserLoading;
  const factory UserState.loaded(User user) = UserLoaded;
  const factory UserState.error(String message) = UserError;
}
```

### Bloc Testing

```dart
blocTest<CounterBloc, int>(
  'emits [1] when Increment is added',
  build: () => CounterBloc(),
  act: (bloc) => bloc.add(Increment()),
  expect: () => [1],
);

blocTest<UserBloc, UserState>(
  'emits [loading, loaded] when LoadUser is added',
  build: () => UserBloc(userRepository: mockUserRepository),
  act: (bloc) => bloc.add(LoadUser(id: '123')),
  expect: () => [
    UserLoading(),
    UserLoaded(testUser),
  ],
);
```

### Event Transformers

```dart
import 'package:bloc_concurrency/bloc_concurrency.dart';

// Debounce - wait for pause in events
on<SearchChanged>(
  _onSearchChanged,
  transformer: debounce(Duration(milliseconds: 300)),
);

// Restartable - cancel previous, start new
on<FetchData>(
  _onFetchData,
  transformer: restartable(),
);

// Sequential - process one at a time
on<SubmitForm>(
  _onSubmitForm,
  transformer: sequential(),
);

// Droppable - ignore while processing
on<ButtonPressed>(
  _onButtonPressed,
  transformer: droppable(),
);
```

## Bloc vs Other State Management

| Library | Best For | saropa_lints Rules |
|---------|----------|-------------------|
| **Bloc** | Enterprise, strict separation of concerns | 8 rules |
| **Riverpod** | Type-safe, testable, compile-time safety | 8 rules |
| **Provider** | Simple apps, learning Flutter | 4 rules |
| **GetX** | Rapid development, all-in-one solution | 3 rules |

See our other guides:
- [Using with Riverpod](using_with_riverpod.md)
- [Using with Provider](using_with_provider.md)
- [Using with GetX](using_with_getx.md)

## Contributing

Have ideas for more Bloc rules? Found a pattern we should catch? Contributions are welcome!

See [CONTRIBUTING.md](https://github.com/saropa/saropa_lints/blob/main/CONTRIBUTING.md) for guidelines on adding new rules.

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)
- [Bloc Documentation](https://bloclibrary.dev/)

---

Questions about Bloc rules? Open an issue - we're happy to help.
