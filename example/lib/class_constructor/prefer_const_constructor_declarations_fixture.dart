// ignore_for_file: unused_element

/// Fixture for `prefer_const_constructor_declarations` lint rule.
/// Quick fix: Add const keyword to the constructor declaration.

// BAD: All fields final, no @immutable / Widget supertype, constructor
// is not const — rule fires.
class ConfigBad {
  ConfigBad(this.url);
  // expect_lint: prefer_const_constructor_declarations

  final String url;
}

// GOOD: constructor already const.
class ConfigGood {
  const ConfigGood(this.url);

  final String url;
}
