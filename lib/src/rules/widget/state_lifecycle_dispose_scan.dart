// ignore_for_file: depend_on_referenced_packages

/// Disposal detection for **State**-owned fields (e.g. `ScrollController`,
/// `FocusNode`) used by `RequireScrollControllerDisposeRule` and
/// `RequireFocusNodeDisposeRule`.
///
/// Two layers:
/// 1. **Regex** on the concatenated source of `dispose` and `didUpdateWidget`
///    — keeps the existing direct `field?.dispose()` and `for … in field`
///    iteration patterns cheap.
/// 2. **AST** — walks those entry methods plus private `_helpers` invoked from
///    them, maps locals whose initializer is a tracked field (`final c = _x`),
///    and treats `c.dispose()` / `disposeSafe` as disposing `_x`.
///
/// Limits: no whole-program alias tracking; unqualified `_foo()` calls enqueue
/// any private method name (same pattern as other lifecycle helpers in this
/// package). `ClassDeclaration.body` is handled as `BlockClassBody` /
/// `EmptyClassBody` for analyzer 11+.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

final RegExp _disposeCallPattern = RegExp(r'\.dispose\s*\(\s*\)');

/// Returns true if [body] shows [name] as disposed (direct or iteration).
bool isNameDisposedInBodyRegex(String body, String name) {
  final directRe = RegExp(
    '${RegExp.escape(name)}\\s*[?.]+'
    '\\s*dispose(Safe)?\\s*\\(',
  );
  final iterationRe = RegExp('in\\s+${RegExp.escape(name)}(\\.values)?\\)');
  return directRe.hasMatch(body) ||
      (iterationRe.hasMatch(body) && _disposeCallPattern.hasMatch(body));
}

Iterable<ClassMember> _classMembers(ClassDeclaration class_) {
  return switch (class_.body) {
    BlockClassBody(:final NodeList<ClassMember> members) => members,
    EmptyClassBody() => const <ClassMember>[],
  };
}

/// Concatenates [dispose] and [didUpdateWidget] method bodies for regex scans.
String combinedDisposeAndDidUpdateBodiesSource(ClassDeclaration class_) {
  final buffer = StringBuffer();
  for (final ClassMember member in _classMembers(class_)) {
    if (member is MethodDeclaration) {
      final String n = member.name.lexeme;
      if (n == 'dispose' || n == 'didUpdateWidget') {
        buffer.writeln(member.body.toSource());
      }
    }
  }
  return buffer.toString();
}

/// True when [fieldName] (member of [trackedNames]) is disposed in lifecycle
/// code: regex match on dispose + didUpdateWidget sources, or AST detection
/// (local aliases to the field, [dispose]/[didUpdateWidget], private helpers).
bool isTrackedFieldDisposedInStateLifecycle(
  ClassDeclaration class_,
  String fieldName,
  Set<String> trackedNames,
) {
  if (!trackedNames.contains(fieldName)) return false;
  final String combined = combinedDisposeAndDidUpdateBodiesSource(class_);
  if (combined.isNotEmpty && isNameDisposedInBodyRegex(combined, fieldName)) {
    return true;
  }
  return disposedTrackedFieldsInStateLifecycleAst(
    class_,
    trackedNames,
  ).contains(fieldName);
}

/// Field names from [trackedNames] that receive `.dispose()` / `.disposeSafe()`
/// when traced through locals aliasing those fields, plus private helpers
/// reachable from [dispose] or [didUpdateWidget].
Set<String> disposedTrackedFieldsInStateLifecycleAst(
  ClassDeclaration class_,
  Set<String> trackedNames,
) {
  if (trackedNames.isEmpty) return const <String>{};

  final Map<String, FunctionBody> methodBodies = <String, FunctionBody>{};
  for (final ClassMember member in _classMembers(class_)) {
    if (member is MethodDeclaration) {
      methodBodies[member.name.lexeme] = member.body;
    }
  }

  final Set<String> disposed = <String>{};
  final Set<String> visitedMethods = <String>{};
  final List<String> queue = <String>['dispose', 'didUpdateWidget'];

  while (queue.isNotEmpty) {
    final String methodName = queue.removeLast();
    if (visitedMethods.contains(methodName)) continue;
    visitedMethods.add(methodName);
    final FunctionBody? body = methodBodies[methodName];
    if (body == null) continue;

    final Map<String, String> localAlias = <String, String>{};
    body.accept(_LocalAliasCollector(localAlias, trackedNames));
    body.accept(
      _DisposeInvocationRecorder(
        disposed: disposed,
        localAlias: localAlias,
        trackedNames: trackedNames,
        enqueueMethod: (String n) {
          if (methodBodies.containsKey(n)) queue.add(n);
        },
      ),
    );
  }
  return disposed;
}

String? _initializerTrackedFieldRef(Expression init, Set<String> trackedNames) {
  Expression? e = init;
  while (e is ParenthesizedExpression) {
    e = e.expression;
  }
  while (e is PostfixExpression && e.operator.lexeme == '!') {
    e = e.operand;
  }
  while (e is PrefixExpression && e.operator.lexeme == '!') {
    e = e.operand;
  }
  if (e == null) return null;

  if (e is SimpleIdentifier && trackedNames.contains(e.name)) {
    return e.name;
  }
  if (e is PrefixedIdentifier &&
      e.prefix is ThisExpression &&
      trackedNames.contains(e.identifier.name)) {
    return e.identifier.name;
  }
  if (e is PropertyAccess &&
      e.target is ThisExpression &&
      trackedNames.contains(e.propertyName.name)) {
    return e.propertyName.name;
  }
  return null;
}

Expression? _unwrapDisposableReceiver(Expression? e) {
  Expression? cur = e;
  while (true) {
    if (cur == null) return null;
    if (cur is ParenthesizedExpression) {
      cur = cur.expression;
      continue;
    }
    if (cur is PostfixExpression && cur.operator.lexeme == '!') {
      cur = cur.operand;
      continue;
    }
    if (cur is PrefixExpression && cur.operator.lexeme == '!') {
      cur = cur.operand;
      continue;
    }
    return cur;
  }
}

String? _expressionToTrackedField(
  Expression? rawTarget,
  Map<String, String> localAlias,
  Set<String> trackedNames,
) {
  final Expression? target = _unwrapDisposableReceiver(rawTarget);
  if (target is SimpleIdentifier) {
    final String n = target.name;
    if (trackedNames.contains(n)) return n;
    final String? aliased = localAlias[n];
    if (aliased != null) return aliased;
    return null;
  }
  if (target is PrefixedIdentifier &&
      target.prefix is ThisExpression &&
      trackedNames.contains(target.identifier.name)) {
    return target.identifier.name;
  }
  if (target is PropertyAccess &&
      target.target is ThisExpression &&
      trackedNames.contains(target.propertyName.name)) {
    return target.propertyName.name;
  }
  if (target is CascadeExpression) {
    return _expressionToTrackedField(target.target, localAlias, trackedNames);
  }
  return null;
}

class _LocalAliasCollector extends RecursiveAstVisitor<void> {
  _LocalAliasCollector(this.localAlias, this.trackedNames);

  final Map<String, String> localAlias;
  final Set<String> trackedNames;

  @override
  void visitVariableDeclarationStatement(VariableDeclarationStatement node) {
    for (final VariableDeclaration variable in node.variables.variables) {
      final Expression? init = variable.initializer;
      if (init != null) {
        final String? ref = _initializerTrackedFieldRef(init, trackedNames);
        if (ref != null) {
          localAlias[variable.name.lexeme] = ref;
        }
      }
    }
    super.visitVariableDeclarationStatement(node);
  }
}

class _DisposeInvocationRecorder extends RecursiveAstVisitor<void> {
  _DisposeInvocationRecorder({
    required this.disposed,
    required this.localAlias,
    required this.trackedNames,
    required this.enqueueMethod,
  });

  final Set<String> disposed;
  final Map<String, String> localAlias;
  final Set<String> trackedNames;
  final void Function(String methodName) enqueueMethod;

  static const Set<String> _disposeNames = <String>{'dispose', 'disposeSafe'};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String methodName = node.methodName.name;
    if (_disposeNames.contains(methodName)) {
      final String? field = _expressionToTrackedField(
        node.realTarget,
        localAlias,
        trackedNames,
      );
      if (field != null) {
        disposed.add(field);
      }
    } else if (node.target == null &&
        methodName.startsWith('_') &&
        methodName.length > 1) {
      enqueueMethod(methodName);
    }
    super.visitMethodInvocation(node);
  }
}
