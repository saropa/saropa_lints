// ignore_for_file: unused_element
// Fixture for avoid_high_cyclomatic_complexity.
// Rule flags functions with too many branches (high cyclomatic complexity).

void badHighComplexity(bool a, bool b, bool c, bool d, bool e) {
  if (a) {}
  if (b) {}
  if (c) {}
  if (d) {}
  if (e) {}
  switch (a) {
    case true:
      break;
    case false:
      break;
  }
}

void goodSimple(bool a) {
  if (a) {}
}
