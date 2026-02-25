// ignore_for_file: depend_on_referenced_packages

/// Utilities for precise target matching in lint rules.
///
/// These utilities replace error-prone `String.contains()` calls on identifier
/// names, method names, and type names with exact-match or structured checks
/// that avoid false positives from substring matching.
///
/// See also: `import_utils.dart` for package-level import detection.
library;

import 'package:analyzer/dart/ast/ast.dart';

/// Extracts the final identifier name from a method invocation target.
///
/// Handles the three common target expression types:
/// - [SimpleIdentifier]: `Geolocator` → `'Geolocator'`
/// - [PrefixedIdentifier]: `pkg.location` → `'location'`
/// - [PropertyAccess]: `this.client` → `'client'`
///
/// Returns `''` for unrecognized expression types (parenthesized,
/// conditional, index, etc.) so callers can safely use `Set.contains`.
String extractTargetName(Expression target) {
  if (target is SimpleIdentifier) return target.name;
  if (target is PrefixedIdentifier) return target.identifier.name;
  if (target is PropertyAccess) return target.propertyName.name;
  return '';
}

/// Checks whether a method invocation target matches any name in [targets].
///
/// Combines [extractTargetName] with an exact set lookup. Use instead of
/// `targetSource.contains('SomeClass')` which false-positives on
/// `SomeClassHelper`, `MySomeClass`, etc.
///
/// Example:
/// ```dart
/// static const _httpTargets = {'http', 'dio', 'client'};
/// if (!isExactTarget(node.target!, _httpTargets)) return;
/// ```
bool isExactTarget(Expression target, Set<String> targets) {
  return targets.contains(extractTargetName(target));
}

/// Detects whether [fieldName].[methodName]() appears in [body] using regex.
///
/// This replaces the fragile pattern of
/// `bodySource.contains('$fieldName.dispose(')` which breaks on whitespace,
/// null-aware calls (`?.`), and formatting differences.
///
/// The regex handles:
/// - Optional whitespace: `name . dispose (` and `name.dispose(`
/// - Null-aware access: `name?.dispose(`
/// - Safe-call variants: `name?.disposeSafe(`
///
/// Example:
/// ```dart
/// if (isFieldCleanedUp('_controller', 'dispose', disposeBody)) {
///   return; // Already disposed
/// }
/// ```
bool isFieldCleanedUp(String fieldName, String methodName, FunctionBody body) {
  final source = body.toSource();
  final pattern = RegExp(
    '${RegExp.escape(fieldName)}\\s*[?.]\\s*$methodName\\s*\\(',
  );
  return pattern.hasMatch(source);
}

/// Walks up the AST from [node] to check if a chained method call with
/// [methodName] exists on the returned value.
///
/// Detects patterns like:
/// ```dart
/// Geolocator.getCurrentPosition().timeout(duration)
/// //                               ^^^^^^^ detected
/// ```
///
/// This replaces checking only direct named arguments, which misses
/// the idiomatic Dart pattern of chaining `.timeout()` on Futures.
bool hasChainedMethod(MethodInvocation node, String methodName) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is MethodInvocation && current.methodName.name == methodName) {
      return true;
    }
    if (current is MethodInvocation || current is PropertyAccess) {
      current = current.parent;
      continue;
    }
    break;
  }

  return false;
}
