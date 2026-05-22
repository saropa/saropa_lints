// Mirror-test presence marker for lib/a.dart — NOT a real test.
// The cross-file analyzer's missing-mirror-test check only verifies this file
// EXISTS at test/a_test.dart (it builds the expected path as `${source}_test.dart`
// in cross_file_analyzer.dart) and never reads the body. The name and location
// ARE the fixture: do not rename or move — that flips the `hasLength(1)`
// assertion in test/cli/cross_file_test.dart. Intentionally empty.
void main() {}
