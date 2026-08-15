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
import 'package:analyzer/dart/ast/visitor.dart';

import 'analyzer_compat.dart';

/// Extracts the field name an [AssignmentExpression] targets, handling both
/// bare identifiers (`_field = ...`) and explicit-`this` access
/// (`this._field = ...`). Returns null for any other LHS shape (indexed
/// assignment, cascade, property access on a non-this target).
String? assignmentTargetFieldName(AssignmentExpression node) {
  final Expression lhs = node.leftHandSide;
  if (lhs is SimpleIdentifier) {
    return lhs.name;
  }
  if (lhs is PropertyAccess && lhs.target is ThisExpression) {
    return lhs.propertyName.name;
  }
  return null;
}

/// Returns true when [expr] — a `Timer(...)`, `Timer.periodic(...)`,
/// `Stream.periodic(...)`, or `.listen(...)` result — is assigned to a class
/// field (directly or via an inline field initializer) that [enclosingClass]
/// cancels/closes inside its own `dispose()` method.
///
/// Used by lifecycle rules to treat "created and torn down within the same
/// State's initState()/dispose() pair" as sufficient, alongside app-level
/// lifecycle-observer handling: a foreground-only ticker doesn't need to
/// pause on backgrounding if it simply stops existing when disposed.
///
/// Conservative by design: if [expr] isn't assigned to a field we can name
/// (a local variable, a fire-and-forget call), or [enclosingClass] has no
/// `dispose()` method, this returns false — the caller should still flag.
///
/// Known limitation: only inspects `dispose()`'s own body, not methods it
/// delegates to (a `dispose() { _teardown(); }` pattern still false-flags);
/// and matches `dispose()` by name only, with no `@override` check. Both
/// are accepted trade-offs — see the equivalent note on
/// `RequireAppLifecycleHandlingRule._isCleanedUpInDispose` in
/// lifecycle_rules.dart, which shares this exact shape.
bool isBackgroundWorkCanceledInDispose(
  Expression expr,
  ClassDeclaration enclosingClass,
) {
  final AstNode? parent = expr.parent;
  String? fieldName;
  if (parent is AssignmentExpression && parent.rightHandSide == expr) {
    fieldName = assignmentTargetFieldName(parent);
  } else if (parent is VariableDeclaration &&
      parent.initializer == expr &&
      parent.parent?.parent is FieldDeclaration) {
    fieldName = parent.name.lexeme;
  }
  if (fieldName == null) return false;

  MethodDeclaration? disposeMethod;
  for (final ClassMember member in enclosingClass.bodyMembers) {
    if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
      disposeMethod = member;
      break;
    }
  }
  if (disposeMethod == null) return false;

  final FunctionBody disposeBody = disposeMethod.body;
  return isFieldCleanedUp(fieldName, 'cancel', disposeBody) ||
      isFieldCleanedUp(fieldName, 'close', disposeBody);
}

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
///
/// Extension cleanup methods (e.g. `disposeSafe`) are not implied by the method
/// name `dispose`; call [isFieldCleanedUp] again with the exact method name.
///
/// Example:
/// ```dart
/// if (isFieldCleanedUp('_controller', 'dispose', disposeBody)) {
///   return; // Already disposed
/// }
/// ```
bool isFieldCleanedUp(String fieldName, String methodName, FunctionBody body) {
  if (_directCallPattern(fieldName, methodName).hasMatch(body.toSource())) {
    return true;
  }
  return hasCascadeCleanup(fieldName, methodName, body);
}

/// Regex for direct calls only: `field.method(` or `field?.method(`.
RegExp _directCallPattern(String fieldName, String methodName) {
  final f = RegExp.escape(fieldName);
  final m = RegExp.escape(methodName);
  return RegExp(
    '$f\\s*(?:\\?\\.|\\.)'
    '\\s*$m\\s*\\(',
  );
}

/// AST-based cascade detection: walks [body] for `CascadeExpression` nodes
/// whose target is [fieldName] and one section calls [methodName].
bool hasCascadeCleanup(String fieldName, String methodName, FunctionBody body) {
  return hasCascadeCleanupWhere(fieldName, (name) => name == methodName, body);
}

/// Like [hasCascadeCleanup] but accepts a [methodMatcher] predicate for
/// flexible method-name matching (e.g. names containing "dispose").
bool hasCascadeCleanupWhere(
  String fieldName,
  bool Function(String methodName) methodMatcher,
  FunctionBody body,
) {
  final visitor = _CascadeCleanupVisitor(fieldName, methodMatcher);
  body.accept(visitor);
  return visitor.found;
}

class _CascadeCleanupVisitor extends RecursiveAstVisitor<void> {
  _CascadeCleanupVisitor(this._fieldName, this._methodMatcher);

  final String _fieldName;
  final bool Function(String) _methodMatcher;
  bool found = false;

  @override
  void visitCascadeExpression(CascadeExpression node) {
    if (found) return;
    final target = node.target;
    final String? name = switch (target) {
      SimpleIdentifier() => target.name,
      PrefixedIdentifier() => target.identifier.name,
      PropertyAccess() => target.propertyName.name,
      _ => null,
    };
    if (name == _fieldName) {
      for (final section in node.cascadeSections) {
        if (section is MethodInvocation &&
            _methodMatcher(section.methodName.name)) {
          found = true;
          return;
        }
      }
    }
    super.visitCascadeExpression(node);
  }
}

/// Same as [isFieldCleanedUp] but checks arbitrary [source] (e.g. full method).
///
/// Use when [body].toSource() may omit the call (e.g. mixin/override layout).
/// Callers can pass [MethodDeclaration].toSource() as fallback.
///
/// Cascade detection uses regex with `[^;]` statement boundary guard. For
/// cascades with closures containing semicolons, prefer [isFieldCleanedUp]
/// (AST-based, no edge cases).
bool isFieldCleanedUpInSource(
  String fieldName,
  String methodName,
  String source,
) {
  return _fieldCleanedUpInSourcePattern(fieldName, methodName).hasMatch(source);
}

/// Pattern for direct calls and cascade calls (regex-only, for string sources).
RegExp _fieldCleanedUpInSourcePattern(String fieldName, String methodName) {
  final f = RegExp.escape(fieldName);
  final m = RegExp.escape(methodName);
  return RegExp(
    '$f\\s*(?:\\?\\.|\\.)'
    '\\s*$m\\s*\\('
    '|'
    '$f\\s*\\.\\.'
    '(?:[^;]*?\\.\\.)*'
    '\\s*$m\\s*\\(',
  );
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
