// ignore_for_file: always_specify_types, depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../../saropa_lint_rule.dart';

// =============================================================================
// Dart SDK 3.4 deprecated APIs (migration rules)
// =============================================================================
//
// ## Purpose
//
// Dart 3.4.0 deprecated several APIs. These rules flag usage and guide
// migration. Same design principles as `dart_sdk_3_removal_rules.dart`:
// element resolution, `requiredPatterns`, and false-positive guards.

bool _isDartIoLibrary(LibraryElement? lib) {
  if (lib == null) return false;
  return lib.uri.toString() == 'dart:io';
}

/// True when [type] is `FileSystemDeleteEvent` from `dart:io`.
bool _isFileSystemDeleteEventFromDartIo(DartType? type) {
  if (type == null) return false;
  final el = type.element;
  if (el == null || el.name != 'FileSystemDeleteEvent') return false;
  return _isDartIoLibrary(el.library);
}

// ─────────────────────────────────────────────────────────────────────────────
// avoid_deprecated_file_system_delete_event_is_directory
// ─────────────────────────────────────────────────────────────────────────────

/// Flags use of `FileSystemDeleteEvent.isDirectory` (deprecated in Dart 3.4).
///
/// **Why:** `FileSystemDeleteEvent.isDirectory` always returns `false` because
/// the underlying OS event does not reliably indicate whether the deleted path
/// was a directory. The property was deprecated to avoid misleading results.
///
/// **Detection:** [PropertyAccess] where the property name is `isDirectory`
/// and the target's static type resolves to `FileSystemDeleteEvent` from
/// `dart:io`.
///
/// **False-positive guard:** `.isDirectory` on other types (e.g.,
/// `FileSystemEntity`, `FileSystemCreateEvent`, user-defined classes) is not
/// flagged.
///
/// **Quick fix:** none — the caller must decide whether to remove the
/// condition or restructure the logic.
///
/// **BAD:**
/// ```dart
/// watcher.listen((event) {
///   if (event is FileSystemDeleteEvent && event.isDirectory) { ... }
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// watcher.listen((event) {
///   if (event is FileSystemDeleteEvent) {
///     // isDirectory is unreliable; check the path yourself if needed
///   }
/// });
/// ```
class AvoidDeprecatedFileSystemDeleteEventIsDirectoryRule
    extends SaropaLintRule {
  AvoidDeprecatedFileSystemDeleteEventIsDirectoryRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-io', 'config'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'isDirectory'};

  static const LintCode _code = LintCode(
    'avoid_deprecated_file_system_delete_event_is_directory',
    '[avoid_deprecated_file_system_delete_event_is_directory] '
        'FileSystemDeleteEvent.isDirectory was deprecated in Dart 3.4 '
        'because it always returns false. The underlying OS event does '
        'not reliably report whether the deleted path was a directory. '
        'Remove the check or verify the path type before deletion. {v1}',
    correctionMessage:
        'Remove the .isDirectory check on FileSystemDeleteEvent. '
        'It always returns false.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPropertyAccess((PropertyAccess node) {
      if (node.propertyName.name != 'isDirectory') return;
      final targetType = node.realTarget.staticType;
      if (!_isFileSystemDeleteEventFromDartIo(targetType)) return;
      reporter.atNode(node.propertyName);
    });

    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (node.identifier.name != 'isDirectory') return;
      final targetType = node.prefix.staticType;
      if (!_isFileSystemDeleteEventFromDartIo(targetType)) return;
      reporter.atNode(node.identifier);
    });
  }
}
