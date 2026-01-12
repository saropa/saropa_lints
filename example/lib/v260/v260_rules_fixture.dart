// ignore_for_file: unused_local_variable, unused_element, unused_field
// ignore_for_file: avoid_catches_without_on_clauses, prefer_const_declarations
// ignore_for_file: prefer_void_callback, prefer_final_locals
// Test fixture for rules added in v2.6.0

// =========================================================================
// prefer_returning_conditional_expressions
// =========================================================================
// Warns when if/else blocks only contain return statements.

// BAD: If/else with single returns
bool badConditionalReturn(bool condition) {
  // expect_lint: prefer_returning_conditional_expressions
  if (condition) {
    return true;
  } else {
    return false;
  }
}

// BAD: Another if/else with returns
String badConditionalReturnString(bool flag) {
  // expect_lint: prefer_returning_conditional_expressions
  if (flag) {
    return 'yes';
  } else {
    return 'no';
  }
}

// GOOD: Direct boolean return
bool goodBooleanReturn(bool condition) {
  return condition;
}

// GOOD: Ternary expression
String goodTernaryReturn(bool flag) {
  return flag ? 'yes' : 'no';
}

// GOOD: Complex logic in branches (not just returns)
String goodComplexBranches(bool flag) {
  if (flag) {
    print('Processing true case');
    return 'yes';
  } else {
    print('Processing false case');
    return 'no';
  }
}

// =========================================================================
// require_finally_cleanup
// =========================================================================
// Warns when cleanup code is in catch block instead of finally.

// BAD: Cleanup in catch block only
Future<void> badCleanupInCatch() async {
  late final Object file;
  // expect_lint: require_finally_cleanup
  try {
    file = await openFile('test.txt');
    await processFile(file);
  } catch (e) {
    await closeFile(file); // May not run!
  }
}

// BAD: Dispose in catch block
Future<void> badDisposeInCatch() async {
  late final Object controller;
  // expect_lint: require_finally_cleanup
  try {
    controller = createController();
    await useController(controller);
  } catch (e) {
    disposeController(controller); // May not run!
  }
}

// GOOD: Cleanup in finally block
Future<void> goodCleanupInFinally() async {
  late final Object file;
  try {
    file = await openFile('test.txt');
    await processFile(file);
  } catch (e) {
    print('Error: $e');
  } finally {
    await closeFile(file); // Always runs
  }
}

// GOOD: Dispose in finally block
Future<void> goodDisposeInFinally() async {
  late final Object controller;
  try {
    controller = createController();
    await useController(controller);
  } finally {
    disposeController(controller); // Always runs
  }
}

// =========================================================================
// require_deep_equality_collections
// =========================================================================
// Warns when List/Set/Map in Equatable props are compared by reference.

// BAD: List in Equatable props without deep equality
class BadEquatableWithList extends Equatable {
  const BadEquatableWithList(this.items);
  // expect_lint: require_deep_equality_collections
  final List<String> items;

  @override
  List<Object?> get props => [items]; // Reference comparison!
}

// BAD: Map in Equatable props
class BadEquatableWithMap extends Equatable {
  const BadEquatableWithMap(this.data);
  // expect_lint: require_deep_equality_collections
  final Map<String, int> data;

  @override
  List<Object?> get props => [data];
}

// GOOD: Using DeepCollectionEquality wrapper
class GoodEquatableWithDeepEquality extends Equatable {
  const GoodEquatableWithDeepEquality(this.items);
  final List<String> items;

  @override
  List<Object?> get props => [DeepCollectionEquality().equals(items, items)];
}

// =========================================================================
// avoid_equatable_datetime
// =========================================================================
// Warns when DateTime is in Equatable props.

// BAD: DateTime in Equatable props
class BadEquatableWithDateTime extends Equatable {
  const BadEquatableWithDateTime(this.createdAt);
  // expect_lint: avoid_equatable_datetime
  final DateTime createdAt;

  @override
  List<Object?> get props => [createdAt]; // Flaky equality!
}

// GOOD: Using millisecondsSinceEpoch for stable comparison
class GoodEquatableWithEpoch extends Equatable {
  const GoodEquatableWithEpoch(this.createdAt);
  final DateTime createdAt;

  @override
  List<Object?> get props => [createdAt.millisecondsSinceEpoch];
}

// =========================================================================
// prefer_image_picker_multi_selection
// =========================================================================
// Warns when pickImage is called in a loop.

// BAD: pickImage in loop
Future<void> badPickImageInLoop(int count) async {
  final images = <Object>[];
  for (int i = 0; i < count; i++) {
    // expect_lint: prefer_image_picker_multi_selection
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) images.add(image);
  }
}

// GOOD: Using pickMultiImage
Future<void> goodPickMultiImage() async {
  final images = await ImagePicker().pickMultiImage();
}

// =========================================================================
// Mock classes for fixtures
// =========================================================================

abstract class Equatable {
  const Equatable();
  List<Object?> get props;
}

class DeepCollectionEquality {
  bool equals(Object? a, Object? b) => true;
}

class ImagePicker {
  Future<Object?> pickImage({required ImageSource source}) async => null;
  Future<List<Object>> pickMultiImage() async => [];
}

enum ImageSource { gallery, camera }

Future<Object> openFile(String path) async => Object();
Future<void> processFile(Object file) async {}
Future<void> closeFile(Object file) async {}
Object createController() => Object();
Future<void> useController(Object controller) async {}
void disposeController(Object controller) {}
