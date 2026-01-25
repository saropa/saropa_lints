// ignore_for_file: unused_local_variable, cascade_invocations
// ignore_for_file: avoid_print

/// Test fixture demonstrating mid-chain ignore comments.
///
/// This feature allows `// ignore:` comments to be placed before the method
/// or property name in chained calls, not just before the entire statement.

class ChainExample {
  ChainExample doSomething() => this;
  ChainExample thenDoAnother() => this;
  String get value => 'test';
}

void midChainIgnoreExamples() {
  final obj = ChainExample();

  // Traditional ignore (still works):
  // ignore: avoid_print
  print('message');

  // NEW: Mid-chain ignore before method:
  final result1 = obj
      // ignore: avoid_print
      .doSomething();

  // The ignore only affects the immediately following method:
  final result2 = obj
      // ignore: some_rule
      .doSomething()
      .thenDoAnother(); // This is NOT ignored by the comment above

  // Works with property access too:
  // ignore: unused_local_variable
  final val = obj
      // ignore: some_rule
      .value;

  // Multiple chained methods with selective ignores:
  final result3 = obj
      .doSomething()
      // ignore: another_rule
      .thenDoAnother();
}
