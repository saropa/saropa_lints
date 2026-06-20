// ignore_for_file: unused_local_variable, unused_element
// Test fixture for avoid_parameter_mutation rule

import 'dart:typed_data';

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

  // GOOD: Map index assignment is the fill/output pattern (a caller passes the
  // map in to be populated) — symmetric with the .add/.addAll exemption.
  void updateMap(Map<String, int> map) {
    map['key'] = 42; // No lint - output collection fill
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

  // BAD: Cascade field assignment on a DTO parameter — real caller corruption.
  void cascadeFieldMutation(User user) {
    // expect_lint: avoid_parameter_mutation
    user
      ..name = 'changed'
      ..age = 30;
  }

  // GOOD: index assignment into a List parameter is the fill-buffer/output
  // pattern — the caller allocates the buffer and passes it in to be populated,
  // symmetric with the exempted .add/.addAll case. (Real-world trigger: a
  // generated polygon table filling a pre-sized buffer by index.)
  void fillList(List<String> p) {
    p[0] = 'a'; // No lint - fill-buffer / output pattern
    p[1] = 'b'; // No lint
    p[2] = 'c'; // No lint
  }

  // GOOD: index assignment into a typed-data list parameter — same fill pattern.
  void fillBytes(Uint8List buffer) {
    buffer[0] = 1; // No lint - typed-data output collection
    buffer[1] = 2; // No lint
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

// Render-object override exemption. The example package has no Flutter
// dependency, so these mirror the framework signatures the rule recognizes
// syntactically (method name + parameter shape).
class BuildContext {}

class ParentData {}

class RenderObject {
  ParentData? parentData;
}

class RenderMyBox extends RenderObject {
  bool flag = false;

  // GOOD: setupParentData's contract is to assign the child's parentData —
  // mutating the framework-supplied object is mandatory, not caller-corruption.
  void setupParentData(RenderObject child) {
    child.parentData = ParentData(); // No lint - render-object override
  }
}

class MyWidget {
  final bool flag = true;

  // GOOD: updateRenderObject pushes the widget's new config onto the live
  // render object. There is no copy alternative; the mutation is the contract.
  void updateRenderObject(BuildContext context, RenderMyBox renderObject) {
    renderObject.flag = flag; // No lint - render-object override
  }

  // BAD: a same-named guard against over-broad exemption. This method mutates a
  // passed DTO field but is NOT a render-object override (wrong signature: no
  // BuildContext first parameter), so it must still be flagged.
  void updateRenderObject2(User user) {
    // expect_lint: avoid_parameter_mutation
    user.name = 'changed';
  }
}
