// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// http package lint rules (new coverage only).
///
/// The repo already ships HTTP/network coverage that subsumes several of the
/// originally proposed http rules, so those are intentionally NOT duplicated
/// here:
///   - status-code-before-body  -> `require_http_status_check`
///                                 (network/api_network_rules.dart) — same name,
///                                 would collide on registration.
///   - request timeout           -> `require_request_timeout`,
///                                 `prefer_timeout_on_requests`,
///                                 `require_future_timeout`.
///   - content-type on POST      -> `require_content_type_check`,
///                                 `require_content_type_validation`.
///   - dart:io HttpClient close   -> `require_http_client_close`
///                                 (resources/resource_management_rules.dart),
///                                 which targets dart:io's HttpClient, NOT
///                                 package:http's Client — the name is taken, so
///                                 the package:http variant here is renamed.
///
/// These rules cover the gaps that none of the above handle: a package:http
/// `Client` leaked without close(), a per-iteration top-level request that
/// discards keep-alive, and a String passed where http 1.x requires a Uri.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../fixes/common/replace_node_fix.dart';
import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

/// Request verbs exposed both as top-level `http.<verb>(...)` functions and as
/// methods on `http.Client`. `send` is included because it is the low-level
/// entry the others delegate to.
const Set<String> _httpRequestMethods = <String>{
  'get',
  'post',
  'put',
  'patch',
  'delete',
  'head',
  'read',
  'send',
};

/// The verbs that exist as top-level convenience functions (no `send`, which is
/// a Client-only method, and `read`, which returns the decoded body).
const Set<String> _httpTopLevelVerbs = <String>{
  'get',
  'post',
  'put',
  'patch',
  'delete',
  'head',
  'read',
};

/// Nearest enclosing function-like body, stopping at the member boundary so a
/// rule never reasons across an unrelated outer scope.
FunctionBody? _enclosingMemberBody(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is MethodDeclaration) return current.body;
    if (current is FunctionDeclaration) {
      return current.functionExpression.body;
    }
    if (current is ConstructorDeclaration) return current.body;
    current = current.parent;
  }
  return null;
}

/// Collects the call / reference shapes the http flow rules reason over.
class _BodyScan extends RecursiveAstVisitor<void> {
  final List<MethodInvocation> invocations = <MethodInvocation>[];
  final List<SimpleIdentifier> identifiers = <SimpleIdentifier>[];
  final List<ReturnStatement> returns = <ReturnStatement>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    invocations.add(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    identifiers.add(node);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    returns.add(node);
    super.visitReturnStatement(node);
  }

  /// True when `<varName>.close(...)` is invoked anywhere in the scanned body.
  bool closesVar(String varName) {
    for (final MethodInvocation inv in invocations) {
      if (inv.methodName.name != 'close') continue;
      final Expression? target = inv.realTarget;
      if (target is SimpleIdentifier && target.name == varName) return true;
    }
    return false;
  }

  /// True when [varName] is returned from the body (ownership transfers out, so
  /// the caller is responsible for closing — suppress the leak report).
  bool returnsVar(String varName) {
    for (final ReturnStatement ret in returns) {
      final Expression? value = ret.expression;
      if (value is SimpleIdentifier && value.name == varName) return true;
    }
    return false;
  }

  /// True when [varName] is passed as an argument to any call other than its
  /// own close()/method chain — it may be stored or closed elsewhere, so a
  /// local leak can no longer be proven. Conservative on purpose.
  bool escapesAsArgument(String varName) {
    for (final MethodInvocation inv in invocations) {
      for (final Expression arg in inv.argumentList.arguments) {
        final Expression value = arg is NamedExpression ? arg.expression : arg;
        if (value is SimpleIdentifier && value.name == varName) return true;
      }
    }
    return false;
  }
}

// =============================================================================
// require_http_package_client_close
// =============================================================================

/// Flags a `package:http` Client created in a local scope and never closed.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `http.Client` (and its `IOClient` / `RetryClient` / `BrowserClient`
/// subtypes) owns an underlying connection pool; a local Client that is never
/// `close()`d leaks sockets and can keep the Dart VM from exiting cleanly in
/// CLI / server / test code. Named distinctly from the existing dart:io
/// `require_http_client_close` rule (which targets `HttpClient`, a different
/// type).
///
/// **BAD:**
/// ```dart
/// final client = http.Client();
/// await client.get(uri); // client never closed
/// ```
///
/// **GOOD:**
/// ```dart
/// final client = http.Client();
/// try {
///   await client.get(uri);
/// } finally {
///   client.close();
/// }
/// ```
class RequireHttpPackageClientCloseRule extends SaropaLintRule {
  RequireHttpPackageClientCloseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns => const <String>{'Client'};

  static const LintCode _code = LintCode(
    'require_http_package_client_close',
    '[require_http_package_client_close] A package:http Client (Client(), IOClient, RetryClient or BrowserClient) is created in a local variable but close() is never called on it in the same function. The Client owns an underlying connection pool that holds sockets open; a leaked Client wastes connections and can prevent a CLI, server, or test isolate from exiting cleanly. The official guidance is to close the client when finished, ideally in a finally block. Suppressed when the client is returned, stored, or passed out (ownership transfers). {v1}',
    correctionMessage:
        'Close the client when done, e.g. wrap usage in try { ... } finally { client.close(); }.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addVariableDeclaration((VariableDeclaration node) {
      if (!fileImportsPackage(node, PackageImports.http)) return;

      final Expression? init = node.initializer;
      if (init is! InstanceCreationExpression) return;
      // Constructor name match: Client() / IOClient() / RetryClient() /
      // BrowserClient(). Syntactic name (not resolved type) keeps the rule
      // working under the scan CLI, which does not always resolve elements.
      final String ctorName = init.constructorName.type.name.lexeme;
      const Set<String> clientCtors = <String>{
        'Client',
        'IOClient',
        'RetryClient',
        'BrowserClient',
      };
      if (!clientCtors.contains(ctorName)) return;

      final String varName = node.name.lexeme;
      final FunctionBody? body = _enclosingMemberBody(node);
      if (body == null) return;

      final _BodyScan scan = _BodyScan();
      body.accept(scan);

      // Ownership transfers out — the caller is responsible for close().
      if (scan.returnsVar(varName)) return;
      if (scan.escapesAsArgument(varName)) return;
      // Stored to a field via `_field = client` — also an escape.
      if (_assignedToField(body, varName)) return;

      if (scan.closesVar(varName)) return;

      // node.name is a Token; report on the Client() initializer instead.
      reporter.atNode(init);
    });
  }

  /// True when [varName] is the right-hand side of an assignment to anything
  /// other than itself (e.g. a class field), meaning it outlives this scope.
  bool _assignedToField(FunctionBody body, String varName) {
    final _AssignmentScan scan = _AssignmentScan(varName);
    body.accept(scan);
    return scan.escaped;
  }
}

/// Detects `<other> = client` assignments that move the client out of scope.
class _AssignmentScan extends RecursiveAstVisitor<void> {
  _AssignmentScan(this.varName);
  final String varName;
  bool escaped = false;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final Expression rhs = node.rightHandSide;
    final Expression lhs = node.leftHandSide;
    final bool rhsIsClient = rhs is SimpleIdentifier && rhs.name == varName;
    // `client = something` is a re-assignment of the local, not an escape.
    final bool lhsIsClient = lhs is SimpleIdentifier && lhs.name == varName;
    if (rhsIsClient && !lhsIsClient) escaped = true;
    super.visitAssignmentExpression(node);
  }
}

// =============================================================================
// avoid_http_top_level_in_loop
// =============================================================================

/// Flags a top-level `http.<verb>(...)` call inside a loop body.
///
/// Since: v4.16.0 | Rule version: v1
///
/// The top-level `http.get`/`post`/... functions each spin up a throwaway
/// `Client`, make one request, and close it. In a loop this discards the
/// keep-alive connection pool every iteration; the package README recommends a
/// shared `Client` for repeated requests to the same host.
///
/// **BAD:**
/// ```dart
/// for (final id in ids) {
///   await http.get(Uri.parse('https://api/$id'));
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// final client = http.Client();
/// try {
///   for (final id in ids) {
///     await client.get(Uri.parse('https://api/$id'));
///   }
/// } finally {
///   client.close();
/// }
/// ```
class AvoidHttpTopLevelInLoopRule extends SaropaLintRule {
  AvoidHttpTopLevelInLoopRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_http_top_level_in_loop',
    '[avoid_http_top_level_in_loop] A top-level http convenience function (http.get / post / put / patch / delete / head / read) is called inside a for/while/do loop. Each of these functions creates a brand-new Client, performs one request, then closes it, so calling them per-iteration throws away the keep-alive connection pool and opens a fresh TCP/TLS connection every time. For repeated requests reuse a single http.Client across the loop and close it once afterwards. {v1}',
    correctionMessage:
        'Create one http.Client() before the loop, call client.<verb>() inside it, and close the client after the loop.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      // Bare top-level call (null target) — distinguishes http.get-as-function
      // from someClient.get / dio.get. Combined with the import gate this is the
      // type-safe signal without needing element resolution.
      if (node.target != null) return;
      if (!_httpTopLevelVerbs.contains(node.methodName.name)) return;
      if (!fileImportsPackage(node, PackageImports.http)) return;

      if (!_insideLoop(node)) return;

      reporter.atNode(node.methodName);
    });
  }

  bool _insideLoop(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ForStatement ||
          current is WhileStatement ||
          current is DoStatement) {
        return true;
      }
      // Stop at the function boundary so a loop in an unrelated outer scope
      // does not count.
      if (current is FunctionBody) return false;
      current = current.parent;
    }
    return false;
  }
}

// =============================================================================
// avoid_http_string_url
// =============================================================================

/// Flags a String literal passed where http 1.x requires a `Uri`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// http 1.0.0 removed `String` support from `get`/`post`/... — they now take a
/// `Uri`. Code written against http ^0.13 that still passes a String literal is
/// a compile error after the upgrade. The fix wraps the literal in
/// `Uri.parse(...)`.
///
/// **BAD:**
/// ```dart
/// await http.get('https://example.com');
/// ```
///
/// **GOOD:**
/// ```dart
/// await http.get(Uri.parse('https://example.com'));
/// ```
class AvoidHttpStringUrlRule extends SaropaLintRule {
  AvoidHttpStringUrlRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_http_string_url',
    '[avoid_http_string_url] A String literal is passed as the URL to an http request function (get / post / put / patch / delete / head / read / send). http 1.0.0 removed String support from these APIs — they require a Uri — so this is a compile error after upgrading from http ^0.13. Wrap the URL in Uri.parse(...) (or Uri.https/Uri.http for structured construction). Detected syntactically on a string-literal first argument, so an existing Uri.parse(...) argument is never flagged. {v1}',
    correctionMessage:
        'Wrap the URL string in Uri.parse(...), e.g. http.get(Uri.parse(url)).',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _WrapInUriParseFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_httpRequestMethods.contains(node.methodName.name)) return;
      if (!fileImportsPackage(node, PackageImports.http)) return;

      // First positional argument is the URL. A String literal there is the
      // pre-1.0 form; Uri.parse(...) / a typed Uri variable is a different
      // AST shape and is intentionally not matched.
      final Expression? first = _firstPositional(node);
      if (first == null || first is! StringLiteral) return;

      reporter.atNode(first);
    });
  }

  Expression? _firstPositional(MethodInvocation node) {
    for (final Expression arg in node.argumentList.arguments) {
      if (arg is NamedExpression) continue;
      return arg;
    }
    return null;
  }
}

/// Quick fix: wrap the flagged URL string literal in `Uri.parse(...)`.
class _WrapInUriParseFix extends ReplaceNodeFix {
  _WrapInUriParseFix({required super.context});

  @override
  FixKind get fixKind => FixKind(
    'saropa.fix.wrapHttpUrlInUriParse',
    80,
    'Wrap URL in Uri.parse(...)',
  );

  @override
  String computeReplacement(AstNode node) => 'Uri.parse(${node.toSource()})';
}
