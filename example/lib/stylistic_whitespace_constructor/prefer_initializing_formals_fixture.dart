// ignore_for_file: unused_element

/// Fixture for `prefer_initializing_formals` (opposite of
/// prefer_constructor_body_assignment — flags manual field assignment that
/// could instead use `this.field` shorthand).

class _BadUser {
  final String name;
  final int age;

  // expect_lint: prefer_initializing_formals
  _BadUser(String name, int age) : this.name = name, this.age = age;
}

class _BadUserBody {
  final String name;

  _BadUserBody(String name) {
    // expect_lint: prefer_initializing_formals
    this.name = name;
  }
}

class _GoodUser {
  final String name;
  final int age;

  // OK — already uses initializing formals, nothing to simplify.
  _GoodUser(this.name, this.age);
}

class _GoodEmail {
  final String value;

  // OK — the assignment normalizes the input (trim + lowercase), which
  // `this.field` shorthand cannot express, so the explicit form is correct.
  _GoodEmail(String raw) : value = raw.trim().toLowerCase();
}

class _GoodDefaulted {
  final String label;

  // OK — falls back to a default when null, a real transformation.
  _GoodDefaulted(String? label) : label = label ?? 'unnamed';
}
