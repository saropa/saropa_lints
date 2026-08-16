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

/// Accepts [limit] (must be positive) and returns an [int] count.
/// Built-in type [int] is a valid doc reference — should NOT trigger.
int getCount(int limit) => limit.clamp(0, 999);

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

/// Service with method cross-references in doc comments.
class MyService {
  /// The service name.
  final String name;

  /// Creates a [MyService] with [name].
  MyService(this.name);

  /// Deprecated — use [showNewDialog] instead.
  /// This is a valid dartdoc cross-reference to another method, not a param.
  void showOldDialog() {}

  /// The replacement for [showOldDialog].
  void showNewDialog() {}

  /// See [name] for the display value.
  /// Field cross-references should not trigger either.
  void printName() {}

  /// Mirrors [isEligible] so callers can skip the check.
  /// Cross-class method ref — should not trigger.
  bool canProceed() => true;

  /// Refreshes after [loadContacts] completes.
  /// Top-level function ref — should not trigger.
  void refresh() {}

  /// Checks eligibility.
  bool isEligible() => true;
}

/// Top-level function referenced from doc comments.
void loadContacts() {}

/// Method with a stale param ref in bullet-list context.
///
// expect_lint: verify_documented_parameters_exist
/// - [removedParam] was renamed
void hasStaleParam(String actualParam) {}

/// Stale param ref using a `*` bullet marker.
///
// expect_lint: verify_documented_parameters_exist
/// * [goneParam] no longer exists
void hasStaleParamStarBullet(String actualParam) {}

/// Stale param ref using a numbered-list marker.
///
// expect_lint: verify_documented_parameters_exist
/// 1. [oldParam] no longer exists
void hasStaleParamNumberedBullet(String actualParam) {}

/// Base class declared in the same file as its subclass.
class BaseRecord {
  /// The record identifier.
  final String id;

  /// Creates a [BaseRecord] with [id].
  BaseRecord(this.id);

  /// Validates the record.
  bool validate() => id.isNotEmpty;
}

/// Subclass referencing an inherited field and method in its docs.
class DerivedRecord extends BaseRecord {
  /// Creates a [DerivedRecord] with [id].
  DerivedRecord(super.id);

  /// Calls [validate] and logs the [id] used.
  /// Both refs are inherited from the same-file superclass — should NOT
  /// trigger.
  void checkAndLog() {}
}

/// Enum declared in the same file as a function that references it.
enum SyncStatus { pending, complete }

/// Starts a sync, ending in [SyncStatus.complete].
/// References [SyncStatus] and its constant via dotted access, which the
/// bracketed-name pattern does not match at all (dotted refs are skipped
/// by the pattern itself). This function also plainly references the
/// [pending] status by name — should NOT trigger since it is a same-file
/// enum constant.
void startSync() {}
