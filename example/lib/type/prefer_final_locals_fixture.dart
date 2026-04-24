// ignore_for_file: unused_element, unused_local_variable, prefer_const_declarations, unused_catch_clause

/// Fixture for `prefer_final_locals` lint rule.
/// Quick fix: Add final (or replace var with final).

void placeholderPreferFinalLocals() {
  // BAD: var never reassigned — LINT
  // expect_lint: prefer_final_locals
  var count = 1;

  // GOOD: final
  final name = 'ok';
}

// GOOD: reassignment inside `if` body — rule must NOT fire.
// Regression: used to fire because detector only walked sibling statements.
void reassignInIfBody() {
  String? text = 'initial';
  if (text == 'initial') {
    text = 'changed';
  }
  print(text);
}

// GOOD: reassignment inside `else` body.
void reassignInElseBody() {
  String label = 'a';
  if (label.isEmpty) {
    print(label);
  } else {
    label = 'b';
  }
  print(label);
}

// GOOD: reassignment inside a closure passed as an argument.
void reassignInClosureArg() {
  String result = '';
  _runCallback(() {
    result = 'set from callback';
  });
  print(result);
}

// GOOD: reassignment inside a `for` body (not the updater).
void reassignInForBody() {
  int total = 0;
  for (final int item in const [1, 2, 3]) {
    total = total + item;
  }
  print(total);
}

// GOOD: reassignment inside a `while` body.
void reassignInWhileBody() {
  int i = 0;
  while (i < 3) {
    i = i + 1;
  }
  print(i);
}

// GOOD: reassignment inside `do`/`while` body.
void reassignInDoWhileBody() {
  int i = 0;
  do {
    i = i + 1;
  } while (i < 3);
  print(i);
}

// GOOD: reassignment inside `try` / `catch` / `finally`.
void reassignInTry() {
  String state = 'start';
  try {
    state = 'try';
  } on Exception catch (_) {
    state = 'catch';
  } finally {
    state = 'finally';
  }
  print(state);
}

// GOOD: reassignment inside a `switch` case.
void reassignInSwitchCase(int x) {
  String label = 'default';
  switch (x) {
    case 1:
      label = 'one';
    case 2:
      label = 'two';
    default:
      label = 'other';
  }
  print(label);
}

// GOOD: reassignment inside a nested `{ ... }` block.
void reassignInNestedBlock() {
  int value = 1;
  {
    value = 2;
  }
  print(value);
}

// GOOD: compound / null-aware / arithmetic assignment inside nested block.
void reassignCompoundInNested() {
  int counter = 0;
  if (counter == 0) {
    counter += 5;
  }
  String? maybe = null;
  if (maybe == null) {
    maybe ??= 'fallback';
  }
  print('$counter $maybe');
}

// GOOD: self-referential reassignment inside `if` body.
String? reassignSelfRef(String? input) {
  String? displayTime = input;
  if (displayTime != null) {
    displayTime = 'at $displayTime';
  }
  return displayTime;
}

// BAD: outer variable never reassigned even though an inner-scope local of
// the same name is. Shadow must NOT be mistaken for a reassignment of the
// outer — rule MUST still fire on the outer.
void shadowedInnerReassignment() {
  // expect_lint: prefer_final_locals
  var outer = 1;
  {
    var outer = 10; // inner shadow — different element
    outer = 20; // reassigns inner, not outer
    print(outer);
  }
  print(outer);
}

// BAD: truly never reassigned in a function with if/for/closures that do not
// touch this particular variable — regression baseline.
void trulyNeverReassigned() {
  // expect_lint: prefer_final_locals
  var unchanged = 'hello';
  int other = 0;
  if (other == 0) {
    other = 1; // reassigns `other`, not `unchanged`
  }
  _runCallback(() {
    print(other);
  });
  print(unchanged);
}

void _runCallback(void Function() fn) => fn();
