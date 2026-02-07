# Using saropa_lints with GetX

This guide explains how saropa_lints enhances your GetX development with specialized rules that catch common anti-patterns.

## What GetX Issues Are Caught

GetX is powerful but has patterns that fail silently. Standard linters see valid Dart code. saropa_lints understands GetX lifecycle and reactivity.

| Issue Type | What Happens | Rule |
|------------|--------------|------|
| Static Get.find() calls | Hidden dependencies, untestable | `avoid_getx_static_get` |
| Undisposed controllers | Memory leaks, stale state | `require_getx_controller_dispose` |
| .obs outside controllers | Lifecycle issues, memory leaks | `avoid_obs_outside_controller` |
| Missing super calls | Broken lifecycle | `proper_getx_super_calls` |
| Unassigned workers | Memory leaks | `always_remove_getx_listener` |
| .obs in build method | Memory leaks | `avoid_getx_rx_inside_build` |
| Rx reassignment | Broken reactivity | `avoid_mutable_rx_variables` |
| Undisposed Worker fields | Memory leaks | `dispose_getx_fields` |
| .obs without Obx wrapper | UI doesn't react to changes | `prefer_getx_builder` |
| Get.put in build | Poor lifecycle management | `require_getx_binding` |

## What saropa_lints Catches

### Undisposed Controller Resources

```dart
// BAD - resources never cleaned up
class MyController extends GetxController {
  final textController = TextEditingController();
  final scrollController = ScrollController();
  StreamSubscription? _subscription;

  @override
  void onInit() {
    super.onInit();
    _subscription = someStream.listen((data) {});
  }

  // Missing onClose()!
}

// GOOD - proper cleanup in onClose
class MyController extends GetxController {
  final textController = TextEditingController();
  final scrollController = ScrollController();
  StreamSubscription? _subscription;

  @override
  void onInit() {
    super.onInit();
    _subscription = someStream.listen((data) {});
  }

  @override
  void onClose() {
    textController.dispose();
    scrollController.dispose();
    _subscription?.cancel();
    super.onClose();
  }
}
```

**Rule**: `require_getx_controller_dispose`

### Observable State Outside Controllers

```dart
// BAD - .obs outside GetxController causes memory leaks
class MyWidget extends StatelessWidget {
  final count = 0.obs;  // No lifecycle management!

  @override
  Widget build(BuildContext context) {
    return Obx(() => Text('${count.value}'));
  }
}

// BAD - .obs in StatefulWidget state
class _MyWidgetState extends State<MyWidget> {
  final items = <String>[].obs;  // Leaks when widget disposed!
}

// GOOD - .obs in GetxController
class MyController extends GetxController {
  final count = 0.obs;
  final items = <String>[].obs;
}

class MyWidget extends StatelessWidget {
  final controller = Get.find<MyController>();

  @override
  Widget build(BuildContext context) {
    return Obx(() => Text('${controller.count.value}'));
  }
}
```

**Rule**: `avoid_obs_outside_getx`

### Missing Reactive Wrappers

```dart
// BAD - changes won't trigger rebuild
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MyController>();
    return Text('${controller.count.value}');  // Static! Won't update
  }
}

// GOOD - Obx rebuilds on changes
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MyController>();
    return Obx(() => Text('${controller.count.value}'));
  }
}

// GOOD - GetBuilder for non-observable state
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetBuilder<MyController>(
      builder: (controller) => Text('${controller.someValue}'),
    );
  }
}
```

**Rule**: `require_getx_reactive_wrapper`

### .obs Property Without Obx Wrapper

```dart
// BAD - accessing .obs property without reactive wrapper
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MyController>();
    // UI won't update when count changes!
    return Text('Count: ${controller.count.value}');
  }
}

// GOOD - wrap with Obx for reactivity
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MyController>();
    return Obx(() => Text('Count: ${controller.count.value}'));
  }
}
```

**Rule**: `prefer_getx_builder`

### Get.put() in Widget Build

```dart
// BAD - controller lifecycle not managed properly
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MyController());  // In build!
    return Obx(() => Text('${controller.value}'));
  }
}

// GOOD - use Bindings for proper lifecycle management
class MyBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MyController>(() => MyController());
  }
}

// In route
GetPage(
  name: '/my',
  page: () => MyPage(),
  binding: MyBinding(),
)
```

**Rule**: `require_getx_binding`

## Recommended Setup

### 1. Update pubspec.yaml

```yaml
dependencies:
  get: ^4.6.6

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
| `require_getx_controller_dispose` | essential | Controllers with undisposed resources |
| `avoid_obs_outside_controller` | essential | .obs used outside GetxController |
| `proper_getx_super_calls` | essential | Missing super.onInit/onClose calls |
| `always_remove_getx_listener` | recommended | Workers not assigned for cleanup |
| `avoid_getx_rx_inside_build` | recommended | .obs created in build() method |
| `avoid_mutable_rx_variables` | recommended | Rx variable reassignment breaking reactivity |
| `dispose_getx_fields` | recommended | Worker fields not disposed in onClose |
| `prefer_getx_builder` | recommended | .obs property access without Obx wrapper |
| `require_getx_binding` | professional | Get.put() in widget build method |
| `avoid_getx_global_navigation` | professional | Get.to/Get.off global navigation (v2.6.0) |
| `require_getx_binding_routes` | professional | GetPage without binding parameter (v2.6.0) |
| `avoid_getx_static_get` | professional | Get.find() creating hidden dependencies (v4.12.0) |

## Common Patterns

### Proper Controller Setup

```dart
class UserController extends GetxController {
  // Reactive state
  final user = Rxn<User>();
  final isLoading = false.obs;
  final error = Rxn<String>();

  // Non-reactive state (use GetBuilder)
  List<User> cachedUsers = [];

  // Resources that need cleanup
  late final StreamSubscription _authSubscription;
  final searchController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    _authSubscription = authService.userStream.listen((u) {
      user.value = u;
    });
  }

  @override
  void onClose() {
    _authSubscription.cancel();
    searchController.dispose();
    super.onClose();
  }

  Future<void> fetchUser(String id) async {
    isLoading.value = true;
    error.value = null;
    try {
      user.value = await userRepository.get(id);
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}
```

### Binding Pattern for Dependency Injection

```dart
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(() => HomeController());
    Get.lazyPut<UserController>(() => UserController());
  }
}

// In routes
GetPage(
  name: '/home',
  page: () => HomePage(),
  binding: HomeBinding(),
)
```

### Workers for Reactive Side Effects

```dart
class SearchController extends GetxController {
  final query = ''.obs;
  final results = <SearchResult>[].obs;

  @override
  void onInit() {
    super.onInit();

    // Debounce search queries
    debounce(
      query,
      (_) => performSearch(),
      time: const Duration(milliseconds: 300),
    );

    // React to changes
    ever(query, (q) => print('Query changed: $q'));
  }

  Future<void> performSearch() async {
    if (query.value.isEmpty) {
      results.clear();
      return;
    }
    results.value = await searchService.search(query.value);
  }
}
```

## GetX vs Other State Management

saropa_lints has rules for multiple state management libraries. Choose based on your needs:

| Library | Best For | saropa_lints Rules |
|---------|----------|-------------------|
| **GetX** | Rapid development, all-in-one solution | 3 rules |
| **Riverpod** | Type-safe, testable, compile-time safety | 8 rules |
| **Provider** | Simple apps, Flutter team supported | 4 rules |
| **Bloc** | Enterprise, strict separation of concerns | 8 rules |

See our other guides:
- [Using with Riverpod](using_with_riverpod.md)
- [Using with Isar](using_with_isar.md)

## Contributing

Have ideas for more GetX rules? Found a pattern we should catch? Contributions are welcome!

See [CONTRIBUTING.md](https://github.com/saropa/saropa_lints/blob/main/CONTRIBUTING.md) for guidelines on adding new rules.

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)
- [GetX Documentation](https://pub.dev/packages/get)

---

Questions about GetX rules? Open an issue - we're happy to help.
