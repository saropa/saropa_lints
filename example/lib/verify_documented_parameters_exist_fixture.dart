// Test fixture for verify_documented_parameters_exist rule

// ignore_for_file: unused_element, unused_import

import 'dart:io';

// ============================================================
// BAD: Should trigger the rule
// ============================================================

/// Restores a file.
///
// expect_lint: verify_documented_parameters_exist
/// - [context] for the toast
Future<bool> fileRestore(String filePath) async {
  return true;
}

/// Processes the given [input].
///
// expect_lint: verify_documented_parameters_exist
/// - [timeout] specifies the maximum wait time.
void processData(String input) {}

// ============================================================
// GOOD: Should NOT trigger the rule
// ============================================================

/// Saves [data] to [filePath].
void saveFile(String filePath, String data) {}

/// Throws a [FormatException] if invalid.
///
/// Returns a [String] result.
void parseValue(String input) {}

/// Processes the item with [callback].
void withCallback(void Function() callback) {}

/// Creates an instance.
///
/// [T] is the element type.
class GenericBox<T> {
  /// Creates a [GenericBox] with the given [value].
  const GenericBox(this.value);

  /// The stored value.
  final T value;
}

/// A user with a [name] field.
class User {
  /// Creates a [User].
  ///
  /// [name] is the user's display name.
  User(this.name);

  /// The user's name.
  final String name;

  /// Returns the [name] in uppercase.
  String upperName() => name.toUpperCase();
}

/// Widget with [child] field reference.
class MyWidget {
  /// Creates a [MyWidget] with an optional [title].
  MyWidget({this.title, this.child});

  /// The title.
  final String? title;

  /// The child widget.
  final Object? child;

  /// Rebuilds with [child] and [title].
  void rebuild() {}
}

/// References a [BackupOptionEnum.contact] enum value.
void enumReference() {}
