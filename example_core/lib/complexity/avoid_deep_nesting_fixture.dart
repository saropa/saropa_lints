// ignore_for_file: unused_element
// Fixture for avoid_deep_nesting.
// Rule flags excessive nesting (e.g. if/for/while beyond threshold).

void badDeepNesting() {
  if (true) {
    if (true) {
      if (true) {
        if (true) {
          // LINT: too many levels
        }
      }
    }
  }
}

void goodFlat() {
  if (!true) return;
  if (!true) return;
}
