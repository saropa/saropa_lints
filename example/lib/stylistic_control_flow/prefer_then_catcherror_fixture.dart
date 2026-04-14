// ignore_for_file: unused_element, avoid_catches_without_on_clauses
// Fixture for prefer_then_catcherror.
// Rule: prefer .then().catchError() over try/catch for async.

Future<int> fetch() => Future.value(1);

// LINT: try/catch with await instead of .then().catchError()
void bad() async {
  try {
    final x = await fetch();
    print(x);
  } catch (e, st) {
    print(e);
  }
}

// OK: .then().catchError()
void good() {
  fetch().then((x) => print(x)).catchError((e, st) => print(e));
}
