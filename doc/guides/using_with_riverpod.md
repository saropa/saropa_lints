# Using saropa_lints with Riverpod

This guide explains how saropa_lints enhances your Riverpod development with specialized rules that catch common anti-patterns.

## Why Use Both?

| Aspect | riverpod_lint | saropa_lints |
|--------|--------------|--------------|
| **Focus** | Riverpod-specific syntax | Cross-cutting concerns |
| **Rule count** | ~20 rules | 1450+ rules (8+ Riverpod-specific) |
| **Catches** | Provider syntax issues | Memory leaks, lifecycle bugs, architecture |

**Key insight**: These packages are *complementary*. Use both for comprehensive coverage.

## What saropa_lints Catches

### Circular Provider Dependencies

```dart
// BAD - circular dependency causes stack overflow
final userProvider = Provider((ref) {
  final settings = ref.watch(settingsProvider);  // settings depends on user
  return User(settings);
});

final settingsProvider = Provider((ref) {
  final user = ref.watch(userProvider);  // user depends on settings
  return Settings(user);
});
```

**Rule**: `avoid_circular_provider_deps`

### ref.read() in Build Methods

```dart
// BAD - ref.read() doesn't set up reactivity
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.read(userProvider);  // Won't rebuild when user changes!
    return Text(user.name);
  }
}

// GOOD - ref.watch() rebuilds on changes
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);  // Rebuilds when user changes
    return Text(user.name);
  }
}
```

**Rule**: `avoid_ref_read_in_build`

### Missing ProviderScope

```dart
// BAD - crashes at runtime
void main() {
  runApp(MyApp());  // No ProviderScope!
}

// GOOD - ProviderScope at root
void main() {
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}
```

**Rule**: `require_provider_scope`

### Providers Inside Widget Classes

```dart
// BAD - recreated on every rebuild, loses state
class MyWidget extends ConsumerWidget {
  final counterProvider = StateProvider((ref) => 0);  // Inside class!

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Text('${ref.watch(counterProvider)}');
  }
}

// GOOD - declared at top level
final counterProvider = StateProvider((ref) => 0);

class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Text('${ref.watch(counterProvider)}');
  }
}
```

**Rule**: `avoid_provider_in_widget`

### Missing autoDispose

```dart
// BAD - provider stays in memory forever
final userDataProvider = FutureProvider((ref) async {
  return await fetchUserData();
});

// GOOD - disposed when no longer used
final userDataProvider = FutureProvider.autoDispose((ref) async {
  return await fetchUserData();
});

// Or with code generation:
@riverpod
Future<UserData> userData(Ref ref) async {
  return await fetchUserData();
}
```

**Rule**: `prefer_auto_dispose_providers`

### ref Access During Dispose

```dart
// BAD - ref is invalid during dispose
@riverpod
class MyNotifier extends _$MyNotifier {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    ref.read(loggerProvider).log('Disposed');  // ref invalid here!
    super.dispose();
  }
}
```

**Rule**: `avoid_ref_in_dispose`

### Assigning to Notifier Variables

```dart
// BAD - breaks provider contract
myNotifier = SomeNotifier();  // Direct assignment
userNotifier = anotherNotifier;  // Reassignment

// GOOD - use provider's own lifecycle
ref.read(myProvider.notifier).updateState(newValue);

// Flutter ValueNotifier in initState is OK (not flagged)
@override
void initState() {
  super.initState();
  _textNotifier = ValueNotifier<String>('');  // OK - Flutter type
}
```

**Rule**: `avoid_assigning_notifiers`

### Global Providers Without Scoping

```dart
// WARNING - consider if this should be scoped
final globalCounter = StateProvider((ref) => 0);

// BETTER - explicitly document why it's global, or scope it
final globalCounter = StateProvider((ref) => 0);  // ignore: avoid_global_riverpod_providers

// Or scope to a subtree
ProviderScope(
  overrides: [counterProvider.overrideWith((ref) => 0)],
  child: FeatureWidget(),
)
```

**Rule**: `avoid_global_riverpod_providers`

### AsyncValue.when Parameter Order

```dart
// BAD - non-standard parameter order confuses readers
asyncValue.when(
  loading: () => CircularProgressIndicator(),
  error: (e, s) => ErrorWidget(e),  // Wrong order
  data: (d) => DataWidget(d),
);

// GOOD - consistent order: data, error, loading
asyncValue.when(
  data: (d) => DataWidget(d),
  error: (e, s) => ErrorWidget(e),
  loading: () => CircularProgressIndicator(),
);
```

**Rule**: `require_async_value_order`

### context.watch Without select

```dart
// BAD - rebuilds on any UserNotifier change
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider).user;  // Rebuilds on any change
    return Text(user.name);
  }
}

// GOOD - use select for targeted rebuilds
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = ref.watch(
      userProvider.select((notifier) => notifier.user.name),
    );
    return Text(userName);  // Only rebuilds when name changes
  }
}
```

**Rule**: `prefer_selector`

## Recommended Setup

### 1. Update pubspec.yaml

```yaml
dependencies:
  flutter_riverpod: ^2.4.0

dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
  riverpod_lint: ^2.3.0      # Official Riverpod lints
  riverpod_generator: ^2.3.0  # If using code generation
```

### 2. Generate configuration

```bash
# Generate analysis_options.yaml with recommended tier
dart run saropa_lints:init --tier recommended

# Or use essential tier for legacy projects
dart run saropa_lints:init --tier essential
```

This generates explicit rule configuration that works reliably with custom_lint.

### 3. Run both analyzers

```bash
# saropa_lints + riverpod_lint (via custom_lint)
dart run custom_lint
```

## Rule Summary

| Rule | Tier | What It Catches |
|------|------|-----------------|
| `require_provider_scope` | essential | Missing ProviderScope at app root |
| `avoid_ref_read_in_build` | essential | ref.read() instead of ref.watch() in build |
| `avoid_assigning_notifiers` | essential | Direct assignment to notifier variables |
| `avoid_circular_provider_deps` | recommended | Providers that depend on each other |
| `avoid_provider_in_widget` | recommended | Providers declared inside widget classes |
| `require_async_value_order` | recommended | Non-standard AsyncValue.when order |
| `prefer_auto_dispose_providers` | professional | Providers without autoDispose modifier |
| `avoid_ref_in_dispose` | professional | Using ref during disposal |
| `prefer_selector` | professional | context.watch without select |
| `avoid_global_riverpod_providers` | comprehensive | Unscoped global providers |
| `require_riverpod_lint` | comprehensive | Missing riverpod_lint in project |
| `prefer_riverpod_auto_dispose` | professional | Providers without autoDispose modifier (v2.6.0) |
| `prefer_riverpod_family_for_params` | professional | StateProvider used for parameterized data (v2.6.0) |

## Common Patterns

### Converting to Consumer for Scoped Rebuilds

```dart
// Instead of entire widget rebuilding:
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);  // Entire widget rebuilds
    return Column(
      children: [
        ExpensiveWidget(),
        Text('Count: $count'),
      ],
    );
  }
}

// Scope rebuilds with Consumer:
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ExpensiveWidget(),  // Doesn't rebuild
        Consumer(
          builder: (context, ref, child) {
            final count = ref.watch(counterProvider);
            return Text('Count: $count');  // Only this rebuilds
          },
        ),
      ],
    );
  }
}
```

**Rule**: `prefer_consumer_widget_for_performance`

## Contributing

Have ideas for more Riverpod rules? Found a pattern we should catch? Contributions are welcome!

See [CONTRIBUTING.md](https://github.com/saropa/saropa_lints/blob/main/CONTRIBUTING.md) for guidelines on adding new rules.

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)
- [Riverpod Documentation](https://riverpod.dev/)

---

Questions about Riverpod rules? Open an issue - we're happy to help.
