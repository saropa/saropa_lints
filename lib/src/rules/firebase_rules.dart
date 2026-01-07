// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Firebase and database lint rules for Flutter applications.
///
/// These rules help identify common Firebase/Firestore issues including
/// unbounded queries, missing limits, and improper database usage patterns.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when Firestore query doesn't have a limit.
///
/// Firestore queries without limits can return unbounded amounts of data,
/// causing performance issues and high costs. Always limit query results.
///
/// **BAD:**
/// ```dart
/// final snapshot = await FirebaseFirestore.instance
///     .collection('users')
///     .get(); // Could return millions of documents!
/// ```
///
/// **GOOD:**
/// ```dart
/// final snapshot = await FirebaseFirestore.instance
///     .collection('users')
///     .limit(100)
///     .get();
/// ```
class AvoidFirestoreUnboundedQueryRule extends SaropaLintRule {
  const AvoidFirestoreUnboundedQueryRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_firestore_unbounded_query',
    problemMessage:
        'Firestore query without limit() could return excessive data.',
    correctionMessage:
        'Add .limit(n) to prevent unbounded queries and control costs.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for .get() or .snapshots() on Firestore query
      final String methodName = node.methodName.name;
      if (methodName != 'get' && methodName != 'snapshots') return;

      // Walk up the method chain to check for Firestore patterns
      bool hasCollection = false;
      bool hasLimit = false;
      bool hasDoc = false; // Single document queries don't need limit

      Expression? current = node.target;
      while (current is MethodInvocation) {
        final MethodInvocation methodCall = current;
        final String name = methodCall.methodName.name;

        if (name == 'collection' || name == 'collectionGroup') {
          hasCollection = true;
        }
        if (name == 'limit' || name == 'limitToLast') {
          hasLimit = true;
        }
        if (name == 'doc') {
          hasDoc = true;
        }

        current = methodCall.target;
      }

      // Report if we have a collection query without limit
      if (hasCollection && !hasLimit && !hasDoc) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when database operations are performed directly in widget build.
///
/// Database operations in build() cause queries on every rebuild, leading
/// to performance issues and unnecessary reads/costs. Use state management
/// or move queries to initState/dedicated methods.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return FutureBuilder(
///     future: db.collection('users').get(), // Query on every rebuild!
///     builder: ...,
///   );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// late Future<QuerySnapshot> _usersFuture;
///
/// @override
/// void initState() {
///   super.initState();
///   _usersFuture = db.collection('users').limit(100).get();
/// }
///
/// Widget build(BuildContext context) {
///   return FutureBuilder(
///     future: _usersFuture,
///     builder: ...,
///   );
/// }
/// ```
class AvoidDatabaseInBuildRule extends SaropaLintRule {
  const AvoidDatabaseInBuildRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_database_in_build',
    problemMessage:
        'Database query in build() runs on every rebuild. Cache the query.',
    correctionMessage:
        'Move database queries to initState() or use cached futures.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      // Check for database operations in FutureBuilder/StreamBuilder
      node.body.visitChildren(_DatabaseInBuildVisitor(reporter, code));
    });
  }
}

class _DatabaseInBuildVisitor extends RecursiveAstVisitor<void> {
  _DatabaseInBuildVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  bool _inFutureOrStreamBuilder = false;

  static const Set<String> _databasePatterns = <String>{
    'collection',
    'collectionGroup',
    'rawQuery',
    'query',
    'database',
    'firestore',
  };

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String? name = node.constructorName.type.element?.name;
    if (name == 'FutureBuilder' || name == 'StreamBuilder') {
      _inFutureOrStreamBuilder = true;
      super.visitInstanceCreationExpression(node);
      _inFutureOrStreamBuilder = false;
      return;
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!_inFutureOrStreamBuilder) {
      super.visitMethodInvocation(node);
      return;
    }

    // Check if this looks like a database query
    final String methodName = node.methodName.name;
    final Expression? target = node.target;

    if (target != null) {
      final String targetSource = target.toSource().toLowerCase();
      bool looksLikeDatabase =
          _databasePatterns.any((String p) => targetSource.contains(p));

      if (looksLikeDatabase &&
          (methodName == 'get' || methodName == 'snapshots')) {
        reporter.atNode(node, code);
      }
    }

    super.visitMethodInvocation(node);
  }
}

/// Warns when SharedPreferences uses string literals for keys.
///
/// Using string literals for SharedPreferences keys is error-prone.
/// A typo in the key string will silently fail. Define keys as constants.
///
/// **BAD:**
/// ```dart
/// prefs.setString('user_name', name);
/// final name = prefs.getString('user_name'); // Easy to typo!
/// final other = prefs.getString('userName'); // Different key - silent bug!
/// ```
///
/// **GOOD:**
/// ```dart
/// class PrefsKeys {
///   static const userName = 'user_name';
/// }
///
/// prefs.setString(PrefsKeys.userName, name);
/// final name = prefs.getString(PrefsKeys.userName);
/// ```
class RequirePrefsKeyConstantsRule extends SaropaLintRule {
  const RequirePrefsKeyConstantsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_prefs_key_constants',
    problemMessage: 'SharedPreferences key should be a constant, not a string literal.',
    correctionMessage:
        'Define preference keys as constants to avoid typos and enable refactoring.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _prefsMethods = <String>{
    'getString',
    'setString',
    'getInt',
    'setInt',
    'getBool',
    'setBool',
    'getDouble',
    'setDouble',
    'getStringList',
    'setStringList',
    'remove',
    'containsKey',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_prefsMethods.contains(methodName)) return;

      final Expression? target = node.target;
      if (target == null) return;

      // Check if target looks like SharedPreferences
      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('pref') && !targetSource.contains('shared')) {
        return;
      }

      // Check if first argument is a string literal
      if (node.argumentList.arguments.isEmpty) return;

      final Expression firstArg = node.argumentList.arguments.first;
      if (firstArg is SimpleStringLiteral) {
        reporter.atNode(firstArg, code);
      }
    });
  }
}

/// Warns when flutter_secure_storage is used in web builds.
///
/// flutter_secure_storage uses localStorage on web, which is not secure.
/// Sensitive data on web should use different approaches like encrypted
/// cookies with HttpOnly flag or server-side storage.
///
/// **BAD:**
/// ```dart
/// // On web platform:
/// final storage = FlutterSecureStorage();
/// await storage.write(key: 'token', value: token); // Uses localStorage!
/// ```
///
/// **GOOD:**
/// ```dart
/// // Check platform and use appropriate storage
/// if (kIsWeb) {
///   // Use encrypted cookies or server-side storage
/// } else {
///   final storage = FlutterSecureStorage();
///   await storage.write(key: 'token', value: token);
/// }
/// ```
class AvoidSecureStorageOnWebRule extends SaropaLintRule {
  const AvoidSecureStorageOnWebRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_secure_storage_on_web',
    problemMessage:
        'flutter_secure_storage uses localStorage on web (not secure).',
    correctionMessage:
        'Check kIsWeb and use alternative storage for web platform.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'FlutterSecureStorage') return;

      // Check if there's a kIsWeb check in the surrounding context
      AstNode? current = node.parent;
      bool hasWebCheck = false;

      while (current != null) {
        if (current is IfStatement) {
          final String condition = current.expression.toSource();
          if (condition.contains('kIsWeb') ||
              condition.contains('Platform.') ||
              condition.contains('defaultTargetPlatform')) {
            hasWebCheck = true;
            break;
          }
        }
        if (current is ConditionalExpression) {
          final String condition = current.condition.toSource();
          if (condition.contains('kIsWeb') ||
              condition.contains('Platform.')) {
            hasWebCheck = true;
            break;
          }
        }
        current = current.parent;
      }

      if (!hasWebCheck) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}
