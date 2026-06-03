// ignore_for_file: unused_local_variable, unused_element
// Test fixture for avoid_parameter_mutation rule

class User {
  String name;
  int age;
  User(this.name, this.age);
}

// Mutation-by-design types. The example package has no Flutter dependency, so
// these mirror the foundation classes the rule recognizes by name/supertype.
abstract class Listenable {}

class ChangeNotifier implements Listenable {}

class ValueNotifier<T> extends ChangeNotifier {
  ValueNotifier(this.value);
  T value;
}

// A user-defined notifier subclass — recognized via the supertype walk.
class BusyNotifier extends ChangeNotifier {
  bool busy = false;
}

// GOOD: updating a ValueNotifier param is its entire designed purpose. The
// caller passes it in precisely so the callee can set .value and notify
// listeners — not a caller-owned DTO being corrupted.
void setBusy(ValueNotifier<bool> isBusy) {
  isBusy.value = true; // No lint - notifier mutation is by design
}

// GOOD: a ChangeNotifier subclass field write is also by design.
void toggleBusy(BusyNotifier notifier) {
  notifier.busy = true; // No lint - type extends ChangeNotifier
}

/// Tests parameter mutation detection
void testParameterMutation() {
  // BAD: List mutation - add
  void addToList(List<String> items) {
    // expect_lint: avoid_parameter_mutation
    items.add('new');
  }

  // BAD: List mutation - addAll
  void addAllToList(List<String> items) {
    // expect_lint: avoid_parameter_mutation
    items.addAll(['a', 'b']);
  }

  // BAD: List mutation - clear
  void clearList(List<String> items) {
    // expect_lint: avoid_parameter_mutation
    items.clear();
  }

  // BAD: List mutation - sort
  void sortList(List<int> numbers) {
    // expect_lint: avoid_parameter_mutation
    numbers.sort();
  }

  // BAD: List mutation - remove
  void removeFromList(List<String> items) {
    // expect_lint: avoid_parameter_mutation
    items.remove('item');
  }

  // BAD: Map mutation - index assignment
  void updateMap(Map<String, int> map) {
    // expect_lint: avoid_parameter_mutation
    map['key'] = 42;
  }

  // BAD: Map mutation - clear
  void clearMap(Map<String, int> map) {
    // expect_lint: avoid_parameter_mutation
    map.clear();
  }

  // BAD: Set mutation - add
  void addToSet(Set<String> items) {
    // expect_lint: avoid_parameter_mutation
    items.add('new');
  }

  // BAD: Field assignment on parameter
  void updateUser(User user) {
    // expect_lint: avoid_parameter_mutation
    user.name = 'changed';
  }

  // BAD: Multiple field assignments
  void updateUserFull(User user) {
    // expect_lint: avoid_parameter_mutation
    user.name = 'new name';
    // expect_lint: avoid_parameter_mutation
    user.age = 30;
  }

  // BAD: Cascade mutation
  void cascadeMutation(List<String> items) {
    // expect_lint: avoid_parameter_mutation
    items
      ..add('a')
      ..add('b');
  }

  // GOOD: Create copy with spread
  void addToListGood(List<String> items) {
    final newItems = [...items, 'new']; // No lint
  }

  // GOOD: Create copy with toList
  void sortListGood(List<int> numbers) {
    final sorted = numbers.toList()..sort(); // No lint - mutating copy
  }

  // GOOD: Read-only access
  void readList(List<String> items) {
    print(items.length);
    print(items.first);
    final contains = items.contains('test');
  }

  // GOOD: Parameter reassignment (different rule)
  void reassignParameter(List<String> items) {
    items = []; // This is reassignment, not mutation
  }

  // GOOD: Mutation of local variable, not parameter
  void mutateLocal(List<String> items) {
    final localList = <String>[];
    localList.add('test'); // No lint - local variable
  }

  // GOOD: Method call that doesn't mutate
  void nonMutatingMethod(List<String> items) {
    final first = items.first;
    final last = items.last;
    final length = items.length;
    final isEmpty = items.isEmpty;
  }
}
