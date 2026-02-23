// Test fixture for avoid_variable_shadowing rule

// ignore_for_file: prefer_const_declarations, unused_local_variable
// ignore_for_file: avoid_print_in_release

/// True shadowing - SHOULD trigger the rule
void trueShadowingExample() {
  final list = [1, 2, 3];

  void inner() {
    // expect_lint: avoid_variable_shadowing
    final list = [4, 5, 6];
    print(list);
  }

  print(list);
}

/// Nested shadowing - SHOULD trigger the rule
void nestedShadowingExample() {
  final value = 10;

  final callback = () {
    // expect_lint: avoid_variable_shadowing
    final value = 20;
    return value;
  };

  print(value);
  print(callback());
}

/// Sibling closures - should NOT trigger (independent scopes)
void siblingClosuresExample() {
  void runTests() {
    // First callback
    final testA = () {
      final list = [1]; // OK: Scope A
      print(list);
    };

    // Second callback - NOT shadowing, these are siblings
    final testB = () {
      final list = [2]; // OK: Scope B - sibling, not nested
      print(list);
    };

    testA();
    testB();
  }
}

/// Simulating test group pattern - should NOT trigger
void testGroupPattern() {
  void group(String name, void Function() body) => body();
  void test(String name, void Function() body) => body();

  group('MyTests', () {
    test('test A', () {
      final result = 1; // OK: Independent test scope
      print(result);
    });

    test('test B', () {
      final result = 2; // OK: Independent test scope (sibling)
      print(result);
    });

    test('test C', () {
      final result = 3; // OK: Independent test scope (sibling)
      print(result);
    });
  });
}

/// Sequential for loops - should NOT trigger (non-overlapping scopes)
void sequentialForLoops() {
  const silentH = <String>['hour', 'honest'];
  for (final ex in silentH) {
    print(ex); // OK: scope A
  }

  const youSound = <String>['uni', 'use'];
  for (final ex in youSound) {
    print(ex); // OK: scope B — `ex` from scope A is gone
  }
}

/// Sequential C-style for loops - should NOT trigger
void sequentialCStyleLoops() {
  for (int i = 0; i < 5; i++) {
    print(i); // OK: scope A
  }
  for (int i = 10; i < 15; i++) {
    print(i); // OK: scope B — `i` from scope A is gone
  }
}

/// Nested loop shadowing - SHOULD trigger
void nestedLoopShadowing() {
  for (final x in [1, 2]) {
    // expect_lint: avoid_variable_shadowing
    for (final x in [3, 4]) {
      print(x); // Shadows outer loop `x`
    }
  }
}

/// If/else sibling blocks - should NOT trigger
void ifElseSiblingBlocks() {
  final bool condition = true;
  if (condition) {
    final name = 'a';
    print(name); // OK: scope A
  } else {
    final name = 'b';
    print(name); // OK: scope B — sibling, not nested
  }
}

/// Mixed case - outer variable with sibling closures
void mixedCaseExample() {
  final outerValue = 'outer';

  final closure1 = () {
    final innerValue = 'inner1'; // OK: Not shadowing outerValue
    print(innerValue);
  };

  final closure2 = () {
    final innerValue = 'inner2'; // OK: Sibling scope, not shadowing closure1
    // expect_lint: avoid_variable_shadowing
    final outerValue = 'shadowed';
    print(innerValue);
    print(outerValue);
  };

  print(outerValue);
}
