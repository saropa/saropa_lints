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
///
/// Includes Flutter `path_provider` APIs (`getApplicationDocumentsDirectory`
/// et al.) and Dart-SDK resolvers that cannot carry HTTP-origin input without
/// the developer explicitly bridging them (`Isolate.resolvePackageUri`,
/// `Platform.resolvedExecutable`, `Platform.script`, `Directory.systemTemp`,
/// `Directory.current`, `File.fromUri` / `Directory.fromUri` /
/// `Link.fromUri`). Matched as substrings of the enclosing body source —
/// qualified names (with `.`) are used where the bare method name would be
/// too generic (e.g. `script`).
const Set<String> platformPathApis = <String>{
  // Flutter path_provider APIs.
  'getApplicationDocumentsDirectory',
  'getApplicationSupportDirectory',
  'getApplicationCacheDirectory',
  'getTemporaryDirectory',
  'getLibraryDirectory',
  'getExternalStorageDirectory',
  'getDownloadsDirectory',
  'getDatabasesPath',
  // Dart-SDK resolvers. See bugs/*_false_positive_internal_resolver_parameter.md
  // for why each of these is considered a trusted, non-HTTP-reachable source.
  'resolvePackageUri',
  'resolvedExecutable',
  'systemTemp',
  'Platform.script',
  'Directory.current',
  'File.fromUri',
  'Directory.fromUri',
  'Link.fromUri',
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
  return checker.isFound;
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

/// Returns true if [paramName] on the enclosing private method receives only
/// compile-time string literals at every call site within the same class or
/// compilation unit.
///
/// This is the maintenance-free alternative to growing [platformPathApis]
/// forever: a private helper whose tainted parameter never carries anything
/// but a `StringLiteral` (or `AdjacentStrings`) cannot be reached by
/// attacker-controlled input, regardless of what resolver the caller used.
///
/// Returns false if:
/// - the enclosing function is not a private method,
/// - [paramName] is not a declared parameter,
/// - zero call sites are found in the search scope (conservative — we cannot
///   prove all callers pass literals if we see none),
/// - any call site passes a non-literal expression at [paramName]'s position.
bool isParamPassedOnlyLiteralsAtCallSites(AstNode node, String paramName) {
  // Resolve the enclosing private declaration — either a class method or a
  // top-level function. Both sit in a traversable search scope (class /
  // compilation unit), so the logic is identical once we extract the name
  // and parameter list.
  final String enclosingName;
  final FormalParameterList? params;
  final MethodDeclaration? method = node
      .thisOrAncestorOfType<MethodDeclaration>();
  if (method != null) {
    enclosingName = method.name.lexeme;
    params = method.parameters;
  } else {
    final FunctionDeclaration? func = node
        .thisOrAncestorOfType<FunctionDeclaration>();
    if (func == null) return false;
    enclosingName = func.name.lexeme;
    params = func.functionExpression.parameters;
  }

  if (!enclosingName.startsWith('_')) return false;
  // Abstract / parameterless declaration — nothing to check.
  if (params == null) return false;

  final _ParamPosition? pos = _findParamPosition(params, paramName);
  if (pos == null) return false;

  final AstNode? searchScope = _getCallSiteSearchScope(node);
  if (searchScope == null) return false;

  final _LiteralArgChecker checker = _LiteralArgChecker(enclosingName, pos);
  searchScope.visitChildren(checker);

  // Require at least one observed call site. Zero call sites = we cannot
  // prove the helper is only reached with literals, so fall back to the
  // stricter existing behavior.
  return checker.callSiteCount > 0 && checker.allLiteral;
}

/// Position of a parameter in a parameter list — positional index and/or
/// named flag.
class _ParamPosition {
  const _ParamPosition({
    required this.isNamed,
    required this.positionalIndex,
    required this.name,
  });

  final bool isNamed;

  /// -1 for named-only parameters.
  final int positionalIndex;
  final String name;
}

_ParamPosition? _findParamPosition(FormalParameterList params, String name) {
  int positional = 0;
  for (final FormalParameter p in params.parameters) {
    final String? pName = p.name?.lexeme;
    final bool isNamed = p.isNamed;
    if (pName == name) {
      return _ParamPosition(
        isNamed: isNamed,
        positionalIndex: isNamed ? -1 : positional,
        name: name,
      );
    }
    if (!isNamed) positional++;
  }
  return null;
}

/// Visitor that inspects every call site of a named private method and
/// verifies the argument at a given parameter position is a compile-time
/// string literal.
class _LiteralArgChecker extends RecursiveAstVisitor<void> {
  _LiteralArgChecker(this._targetName, this._pos);

  final String _targetName;
  final _ParamPosition _pos;

  int callSiteCount = 0;
  bool allLiteral = true;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!allLiteral) return;
    if (node.methodName.name == _targetName) {
      _check(node.argumentList);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    if (!allLiteral) return;
    final Expression fn = node.function;
    if (fn is SimpleIdentifier && fn.name == _targetName) {
      _check(node.argumentList);
    }
    super.visitFunctionExpressionInvocation(node);
  }

  void _check(ArgumentList args) {
    callSiteCount++;

    // Resolve the argument bound to our target parameter.
    Expression? arg;
    if (_pos.isNamed) {
      for (final Expression a in args.arguments) {
        if (a is NamedExpression && a.name.label.name == _pos.name) {
          arg = a.expression;
          break;
        }
      }
      // Default value used (no explicit arg) — unknown provenance; reject.
      if (arg == null) {
        allLiteral = false;
        return;
      }
    } else {
      int idx = 0;
      for (final Expression a in args.arguments) {
        if (a is NamedExpression) continue;
        if (idx == _pos.positionalIndex) {
          arg = a;
          break;
        }
        idx++;
      }
      if (arg == null) {
        // Positional arg not supplied — can only happen with optional
        // positionals. Default value provenance unknown; reject.
        allLiteral = false;
        return;
      }
    }

    if (!_isCompileTimeLiteralString(arg)) {
      allLiteral = false;
    }
  }

  /// Recognize `'abc'`, `'a' 'b'` (adjacent literals), and plain
  /// interpolations whose parts are all literals.
  bool _isCompileTimeLiteralString(Expression e) {
    if (e is SimpleStringLiteral) return true;
    if (e is AdjacentStrings) {
      return e.strings.every(_isCompileTimeLiteralString);
    }
    // Interpolations with ONLY InterpolationString parts (no expressions)
    // are compile-time literals; any InterpolationExpression means runtime
    // data. Rare in practice — included for completeness.
    if (e is StringInterpolation) {
      return e.elements.every((el) => el is InterpolationString);
    }
    return false;
  }
}

/// Visitor that finds invocations of a named method and checks whether the
/// caller's enclosing function body contains a platform path API call.
///
/// Short-circuits after the first trusted caller is found.
class _CallerChecker extends RecursiveAstVisitor<void> {
  _CallerChecker(this._targetName);

  final String _targetName;
  bool isFound = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (isFound) return;
    if (node.methodName.name == _targetName) {
      _checkCallerBody(node);
    }
    if (!isFound) super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    if (isFound) return;
    final Expression fn = node.function;
    if (fn is SimpleIdentifier && fn.name == _targetName) {
      _checkCallerBody(node);
    }
    if (!isFound) super.visitFunctionExpressionInvocation(node);
  }

  void _checkCallerBody(AstNode callSite) {
    final FunctionBody? callerBody = callSite
        .thisOrAncestorOfType<FunctionBody>();
    if (callerBody == null) return;

    if (bodyContainsPlatformPathApi(callerBody.toSource())) {
      isFound = true;
    }
  }
}
