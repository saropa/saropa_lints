// Test fixture for: unnecessary_library_name_with_fix
// BAD: library name only (no URI) triggers the lint.
// GOOD: library; (no name) does not.

// LINT: unnecessary_library_name_with_fix
library my_lib;

void main() {}
