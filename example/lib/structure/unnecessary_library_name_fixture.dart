// Test fixture for: unnecessary_library_name
// BAD: library name only (no URI) triggers the lint.
// GOOD: library; (no name) does not.

// LINT: unnecessary_library_name
library my_lib;

void main() {}
