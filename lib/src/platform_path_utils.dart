/// Utilities for detecting trusted platform path API usage across function
/// boundaries.
///
/// Used by [AvoidPathTraversalRule] and [RequireFilePathSanitizationRule] to
/// suppress false positives when a trusted platform directory path is passed
/// to a private helper method.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Well-known platform path APIs that return trusted directory paths.
const Set<String> platformPathApis = <String>{
  'getApplicationDocumentsDirectory',
  'getApplicationSupportDirectory',
  'getApplicationCacheDirectory',
  'getTemporaryDirectory',
  'getLibraryDirectory',
  'getExternalStorageDirectory',
  'getDownloadsDirectory',
  'getDatabasesPath',
};

/// Returns true if [bodySource] contains a call to any trusted platform API.
bool bodyContainsPlatformPathApi(String bodySource) {
  for (final String api in platformPathApis) {
    if (bodySource.contains(api)) return true;
  }
  return false;
}

/// Checks if the node is in a scope that uses a trusted platform path API.
///
/// First checks the enclosing function body (intra-procedural). If that fails
/// and the enclosing function is private, checks all call sites of that
/// function within the same class or compilation unit to see if the caller's
/// scope contains a platform path API call (inter-procedural).
bool isFromPlatformPathApi(AstNode node) {
  final FunctionBody? body = node.thisOrAncestorOfType<FunctionBody>();
  if (body != null && bodyContainsPlatformPathApi(body.toSource())) {
    return true;
  }

  return _callerHasPlatformPathApi(node);
}

/// For private methods/functions, checks if any caller's body contains a
/// platform path API call.
bool _callerHasPlatformPathApi(AstNode node) {
  final String? methodName = _getEnclosingPrivateName(node);
  if (methodName == null) return false;

  final AstNode? searchScope = _getCallSiteSearchScope(node);
  if (searchScope == null) return false;

  final _CallerChecker checker = _CallerChecker(methodName);
  searchScope.visitChildren(checker);
  return checker.found;
}

/// Returns the enclosing method/function name if it starts with `_`.
String? _getEnclosingPrivateName(AstNode node) {
  final MethodDeclaration? method = node
      .thisOrAncestorOfType<MethodDeclaration>();
  if (method != null) {
    final String name = method.name.lexeme;
    return name.startsWith('_') ? name : null;
  }

  final FunctionDeclaration? func = node
      .thisOrAncestorOfType<FunctionDeclaration>();
  if (func != null) {
    final String name = func.name.lexeme;
    return name.startsWith('_') ? name : null;
  }

  return null;
}

/// Returns the scope to search for call sites of a private method.
///
/// For class methods, returns the [ClassDeclaration]. For top-level
/// functions, returns the [CompilationUnit].
AstNode? _getCallSiteSearchScope(AstNode node) {
  final ClassDeclaration? classDecl = node
      .thisOrAncestorOfType<ClassDeclaration>();
  if (classDecl != null) return classDecl;

  return node.root is CompilationUnit ? node.root : null;
}

/// Visitor that finds invocations of a named method and checks whether the
/// caller's enclosing function body contains a platform path API call.
///
/// Short-circuits after the first trusted caller is found.
class _CallerChecker extends RecursiveAstVisitor<void> {
  _CallerChecker(this._targetName);

  final String _targetName;
  bool found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (found) return;
    if (node.methodName.name == _targetName) {
      _checkCallerBody(node);
    }
    if (!found) super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    if (found) return;
    final Expression fn = node.function;
    if (fn is SimpleIdentifier && fn.name == _targetName) {
      _checkCallerBody(node);
    }
    if (!found) super.visitFunctionExpressionInvocation(node);
  }

  void _checkCallerBody(AstNode callSite) {
    final FunctionBody? callerBody = callSite
        .thisOrAncestorOfType<FunctionBody>();
    if (callerBody == null) return;

    if (bodyContainsPlatformPathApi(callerBody.toSource())) {
      found = true;
    }
  }
}
