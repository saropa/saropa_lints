// Test fixture for: external_with_initializer
// BAD: external with initializer triggers the lint.
// GOOD: external without initializer does not.

// LINT: external_with_initializer — external top-level must not have initializer
external int badTopLevel = 0;

// OK: no initializer
external int goodTopLevel;

class C {
  // LINT: external_with_initializer — external field must not have initializer
  external int badField = 0;

  // OK: no initializer
  external int goodField;
}
