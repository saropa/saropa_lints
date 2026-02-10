// ignore_for_file: unused_local_variable, unused_element
// Test fixture for avoid_parameter_reassignment rule

/// Tests parameter reassignment detection
void testParameterReassignment() {
  // BAD: Direct assignment
  void processValue(int value) {
    // expect_lint: avoid_parameter_reassignment
    value = value * 2;
  }

  // BAD: Assignment with different value
  void processString(String text) {
    // expect_lint: avoid_parameter_reassignment
    text = text.trim();
  }

  // BAD: Postfix increment
  void incrementPost(int count) {
    // expect_lint: avoid_parameter_reassignment
    count++;
  }

  // BAD: Postfix decrement
  void decrementPost(int count) {
    // expect_lint: avoid_parameter_reassignment
    count--;
  }

  // BAD: Prefix increment
  void incrementPre(int count) {
    // expect_lint: avoid_parameter_reassignment
    ++count;
  }

  // BAD: Prefix decrement
  void decrementPre(int count) {
    // expect_lint: avoid_parameter_reassignment
    --count;
  }

  // BAD: Compound assignment
  void compound(int value) {
    // expect_lint: avoid_parameter_reassignment
    value += 10;
  }

  // GOOD: Use local variable
  void processValueGood(int value) {
    final doubled = value * 2; // No lint
  }

  // GOOD: Use local variable for string
  void processStringGood(String text) {
    final trimmed = text.trim(); // No lint
  }

  // GOOD: Use local variable for increment
  void incrementGood(int count) {
    final newCount = count + 1; // No lint
  }

  // GOOD: Read-only parameter access
  void readOnly(int value, String text) {
    print(value);
    print(text.length);
  }

  // GOOD: Parameter used in expressions without reassignment
  void expressionUse(int a, int b) {
    final sum = a + b;
    final product = a * b;
  }
}
