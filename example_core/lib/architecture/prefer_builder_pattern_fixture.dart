// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_builder_pattern` lint rule.

// BAD: Complex construction that could use a builder
// expect_lint: prefer_builder_pattern
void bad() {
  final obj = _Config(1, 2, 3, 4, 5);
}

// GOOD: Builder pattern for complex construction
void good() {
  final obj = _ConfigBuilder().a(1).b(2).c(3).build();
}

class _Config {
  _Config(this.a, this.b, this.c, this.d, this.e);
  final int a, b, c, d, e;
}

class _ConfigBuilder {
  int _a = 0, _b = 0, _c = 0;
  _ConfigBuilder a(int v) { _a = v; return this; }
  _ConfigBuilder b(int v) { _b = v; return this; }
  _ConfigBuilder c(int v) { _c = v; return this; }
  _Config build() => _Config(_a, _b, _c, 0, 0);
}

void main() {}
