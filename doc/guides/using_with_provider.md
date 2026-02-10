# Using saropa_lints with Provider

This guide explains how saropa_lints enhances your Provider development with specialized rules that catch common anti-patterns.

## What Provider Issues Are Caught

Provider is Flutter's recommended state management for simple apps. But it has patterns that cause unnecessary rebuilds, state loss, and memory leaks.

| Issue Type | What Happens | Rule |
|------------|--------------|------|
| Provider.of in build | Unnecessary widget rebuilds | `avoid_provider_of_in_build` |
| Recreated providers | State lost on rebuild | `avoid_provider_recreate` |
| BuildContext in providers | Lifecycle issues | `avoid_build_context_in_providers` |
| Missing dispose | Memory leaks | `require_provider_dispose` |
| Provider.of for reactivity | Use Consumer instead | `prefer_consumer_over_provider_of` |
| context.watch in async | Subscription leaks | `avoid_listen_in_async` |
| Provider.value inline | Rebuilds create new instances | `avoid_provider_value_rebuild` |
| listen:false in build | Widget won't rebuild on changes | `avoid_provider_listen_false_in_build` |

## What saropa_lints Catches

### Provider.of in Build Methods

```dart
// BAD - rebuilds entire widget tree on any change
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel>(context);  // Triggers rebuild!
    return Column(
      children: [
        ExpensiveWidget(),  // Rebuilds unnecessarily
        Text(user.name),
      ],
    );
  }
}

// GOOD - use Consumer for scoped rebuilds
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ExpensiveWidget(),  // Doesn't rebuild
        Consumer<UserModel>(
          builder: (context, user, child) => Text(user.name),
        ),
      ],
    );
  }
}

// GOOD - use context.watch() or context.select()
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userName = context.select<UserModel, String>((u) => u.name);
    return Text(userName);  // Only rebuilds when name changes
  }
}
```

**Rule**: `avoid_provider_of_in_build`

### Recreated Providers

```dart
// BAD - provider recreated on every build, loses state
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CounterModel(),  // New instance every build!
      child: CounterView(),
    );
  }
}

// GOOD - provider at stable location
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CounterModel(),  // Created once
      child: MaterialApp(
        home: CounterView(),
      ),
    );
  }
}

// GOOD - use .value for existing instances
class MyWidget extends StatelessWidget {
  final CounterModel counter;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: counter,  // Existing instance, not recreated
      child: CounterView(),
    );
  }
}
```

**Rule**: `avoid_provider_recreate`

### BuildContext in Providers

```dart
// BAD - storing BuildContext causes lifecycle issues
class MyProvider extends ChangeNotifier {
  BuildContext? _context;  // Dangerous!

  void setContext(BuildContext context) {
    _context = context;
  }

  void navigate() {
    Navigator.of(_context!).push(...);  // Context may be invalid!
  }
}

// GOOD - pass context when needed, don't store it
class MyProvider extends ChangeNotifier {
  void navigate(BuildContext context) {
    Navigator.of(context).push(...);
  }
}

// GOOD - use callbacks for navigation
class MyProvider extends ChangeNotifier {
  final void Function(String route) onNavigate;

  MyProvider({required this.onNavigate});

  void goToDetails() {
    onNavigate('/details');
  }
}
```

**Rule**: `avoid_build_context_in_providers`

### Missing Dispose

```dart
// BAD - resources never cleaned up
class DataProvider extends ChangeNotifier {
  StreamSubscription? _subscription;
  Timer? _refreshTimer;

  void init() {
    _subscription = dataStream.listen((data) {
      notifyListeners();
    });
    _refreshTimer = Timer.periodic(
      Duration(minutes: 5),
      (_) => refresh(),
    );
  }

  // Missing dispose()!
}

// GOOD - proper cleanup
class DataProvider extends ChangeNotifier {
  StreamSubscription? _subscription;
  Timer? _refreshTimer;

  void init() {
    _subscription = dataStream.listen((data) {
      notifyListeners();
    });
    _refreshTimer = Timer.periodic(
      Duration(minutes: 5),
      (_) => refresh(),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }
}
```

**Rule**: `require_provider_dispose`

### Consumer vs Provider.of

```dart
// BAD - Provider.of triggers rebuild of entire widget
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel>(context);
    return Column(
      children: [
        ExpensiveWidget(),  // Rebuilds unnecessarily!
        Text(user.name),
      ],
    );
  }
}

// GOOD - Consumer scopes rebuilds to just what needs it
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ExpensiveWidget(),  // Doesn't rebuild
        Consumer<UserModel>(
          builder: (context, user, _) => Text(user.name),
        ),
      ],
    );
  }
}
```

**Rule**: `prefer_consumer_over_provider_of`

### context.watch() in Async Callbacks

```dart
// BAD - context.watch in async callback causes subscription leaks
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        await Future.delayed(Duration(seconds: 1));
        final user = context.watch<UserModel>();  // Subscription leak!
        print(user.name);
      },
      child: Text('Load'),
    );
  }
}

// GOOD - use context.read in callbacks
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        await Future.delayed(Duration(seconds: 1));
        final user = context.read<UserModel>();  // Safe - no subscription
        print(user.name);
      },
      child: Text('Load'),
    );
  }
}
```

**Rule**: `avoid_listen_in_async`

## Recommended Setup

### 1. Update pubspec.yaml

```yaml
dependencies:
  provider: ^6.1.0

dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
```

### 2. Generate configuration

```bash
# Generate analysis_options.yaml with recommended tier
dart run saropa_lints:init --tier recommended

# Or use essential tier for legacy projects
dart run saropa_lints:init --tier essential
```

This generates explicit rule configuration that works reliably with custom_lint.

### 3. Run the linter

```bash
dart run custom_lint
```

## Rule Summary

| Rule | Tier | What It Catches |
|------|------|-----------------|
| `avoid_provider_of_in_build` | essential | Provider.of causing unnecessary rebuilds |
| `avoid_provider_recreate` | essential | Providers recreated in build methods |
| `avoid_listen_in_async` | essential | context.watch in async callbacks |
| `avoid_build_context_in_providers` | recommended | BuildContext stored in ChangeNotifier |
| `require_provider_dispose` | recommended | Missing dispose in ChangeNotifier |
| `prefer_consumer_over_provider_of` | recommended | Provider.of instead of Consumer |
| `avoid_provider_listen_false_in_build` | recommended | listen:false in build() suppresses rebuilds (v4.12.0) |

## Common Patterns

### MultiProvider Setup

```dart
// GOOD - all providers at app root
void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProxyProvider<AuthProvider, UserProvider>(
          create: (_) => UserProvider(),
          update: (_, auth, user) => user!..updateAuth(auth),
        ),
      ],
      child: MyApp(),
    ),
  );
}
```

### Selector for Granular Rebuilds

```dart
// Only rebuilds when specific field changes
class UserAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final avatarUrl = context.select<UserModel, String?>((u) => u.avatarUrl);
    return CircleAvatar(
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
    );
  }
}
```

### Read vs Watch

```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // context.watch - rebuilds when provider changes
    final user = context.watch<UserModel>();

    // context.read - doesn't rebuild, use in callbacks
    return ElevatedButton(
      onPressed: () {
        context.read<CartModel>().addItem(user.favoriteItem);
      },
      child: Text('Add to cart'),
    );
  }
}
```

### Lazy Initialization

```dart
class DataProvider extends ChangeNotifier {
  List<Item>? _items;
  bool _isLoading = false;

  List<Item> get items => _items ?? [];
  bool get isLoading => _isLoading;

  Future<void> loadIfNeeded() async {
    if (_items != null || _isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      _items = await fetchItems();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
```

## Provider vs Other State Management

| Library | Best For | saropa_lints Rules |
|---------|----------|-------------------|
| **Provider** | Simple apps, learning Flutter | 4 rules |
| **Riverpod** | Type-safe, testable, compile-time safety | 8 rules |
| **GetX** | Rapid development, all-in-one solution | 3 rules |
| **Bloc** | Enterprise, strict separation of concerns | 8 rules |

See our other guides:
- [Using with Riverpod](using_with_riverpod.md)
- [Using with GetX](using_with_getx.md)
- [Using with Bloc](using_with_bloc.md)

## Contributing

Have ideas for more Provider rules? Found a pattern we should catch? Contributions are welcome!

See [CONTRIBUTING.md](https://github.com/saropa/saropa_lints/blob/main/CONTRIBUTING.md) for guidelines on adding new rules.

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)
- [Provider Documentation](https://pub.dev/packages/provider)

---

Questions about Provider rules? Open an issue - we're happy to help.
