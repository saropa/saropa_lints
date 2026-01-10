// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Firebase and database lint rules for Flutter applications.
///
/// These rules help identify common Firebase/Firestore issues including
/// unbounded queries, missing limits, and improper database usage patterns.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when Firestore query doesn't have a limit.
///
/// Alias: firestore_query_limit, no_unbounded_query
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

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

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
/// Alias: no_database_in_build, cache_database_query, avoid_firestore_in_widget_build
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

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

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
/// Alias: prefs_key_constant, no_string_literal_prefs_key
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

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_prefs_key_constants',
    problemMessage:
        'SharedPreferences key should be a constant, not a string literal.',
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
/// Alias: no_secure_storage_web, web_storage_insecure
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

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

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
          if (condition.contains('kIsWeb') || condition.contains('Platform.')) {
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

/// Warns when SharedPreferences is used to store large data.
///
/// Alias: no_large_prefs, use_database_for_large_data
///
/// SharedPreferences loads the entire file on first access. Storing large
/// amounts of data causes slow startup and memory issues. Use a database
/// for collections or large values.
///
/// **BAD:**
/// ```dart
/// // Storing large list in SharedPreferences
/// prefs.setStringList('all_users', hundredsOfUsers);
///
/// // Storing large JSON blob
/// prefs.setString('cache_data', jsonEncode(largeData));
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use Hive, Isar, or SQLite for collections
/// await box.put('users', users);
///
/// // Use SharedPreferences only for small settings
/// prefs.setBool('dark_mode', true);
/// prefs.setString('locale', 'en_US');
/// ```
class AvoidPrefsForLargeDataRule extends SaropaLintRule {
  const AvoidPrefsForLargeDataRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_prefs_for_large_data',
    problemMessage:
        'SharedPreferences is not suitable for large data. Use a database.',
    correctionMessage:
        'Use Hive, Isar, or SQLite for collections. SharedPreferences is for small settings only.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for setStringList which is often misused for large data
      if (methodName != 'setStringList') return;

      final Expression? target = node.target;
      if (target == null) return;

      // Check if target looks like SharedPreferences
      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('pref') && !targetSource.contains('shared')) {
        return;
      }

      // Check for patterns that suggest large data storage
      if (node.argumentList.arguments.length >= 2) {
        final Expression keyArg = node.argumentList.arguments.first;
        final String keySource = keyArg.toSource().toLowerCase();

        // Flag keys that suggest storing collections
        final List<String> largeDataPatterns = <String>[
          'users',
          'items',
          'products',
          'orders',
          'messages',
          'history',
          'cache',
          'data',
          'list',
          'all_',
          'every',
        ];

        if (largeDataPatterns.any((String p) => keySource.contains(p))) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when Firebase services are used before initialization.
///
/// Alias: firebase_init_first, no_firebase_before_init
///
/// Firebase.initializeApp() must complete before accessing any Firebase
/// service. Without it, all provider access throws errors.
///
/// **BAD:**
/// ```dart
/// void main() {
///   runApp(MyApp());
/// }
///
/// class MyApp extends StatelessWidget {
///   Widget build(context) {
///     // Crashes! Firebase not initialized
///     return StreamBuilder(
///       stream: FirebaseFirestore.instance.collection('users').snapshots(),
///       ...
///     );
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await Firebase.initializeApp();
///   runApp(MyApp());
/// }
/// ```
class RequireFirebaseInitBeforeUseRule extends SaropaLintRule {
  const RequireFirebaseInitBeforeUseRule() : super(code: _code);

  /// Each occurrence is a serious issue that should be fixed immediately.
  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'require_firebase_init_before_use',
    problemMessage:
        'Firebase service used without ensuring Firebase.initializeApp() was called.',
    correctionMessage:
        'Ensure Firebase.initializeApp() completes in main() before runApp().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Firebase service access patterns
  static const Set<String> _firebaseServices = <String>{
    'FirebaseFirestore',
    'FirebaseAuth',
    'FirebaseStorage',
    'FirebaseMessaging',
    'FirebaseAnalytics',
    'FirebaseCrashlytics',
    'FirebaseRemoteConfig',
    'FirebaseDynamicLinks',
    'FirebaseDatabase',
    'FirebaseFunctions',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check main() function for Firebase usage without initialization
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      if (node.name.lexeme != 'main') return;

      final String mainSource = node.toSource();

      // Skip if main has Firebase.initializeApp
      if (mainSource.contains('Firebase.initializeApp')) return;

      // Check if main uses any Firebase service
      for (final String service in _firebaseServices) {
        if (mainSource.contains('$service.instance') ||
            mainSource.contains('$service(')) {
          reporter.atToken(node.name, code);
          return;
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddFirebaseInitFix()];
}

class _AddFirebaseInitFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.name.lexeme != 'main') return;

      final FunctionBody body = node.functionExpression.body;
      if (body is! BlockFunctionBody) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add Firebase.initializeApp() call',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          body.block.leftBracket.end,
          '\n  WidgetsFlutterBinding.ensureInitialized();\n  await Firebase.initializeApp();\n',
        );
      });
    });
  }
}

/// Warns when database schema changes lack migration support.
///
/// Alias: database_migration, schema_versioning
///
/// Breaking schema changes without migrations corrupt existing user data.
/// Use versioned migrations for schema evolution.
///
/// **BAD:**
/// ```dart
/// @HiveType(typeId: 1)
/// class User {
///   @HiveField(0)
///   String id;
///
///   @HiveField(1)
///   String name;
///
///   @HiveField(2) // Added field - breaks existing data!
///   String email;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class DatabaseMigrator {
///   static const int currentVersion = 2;
///
///   static Future<void> migrate(int fromVersion) async {
///     if (fromVersion < 2) {
///       await _addEmailField();
///     }
///   }
/// }
/// ```
class RequireDatabaseMigrationRule extends SaropaLintRule {
  const RequireDatabaseMigrationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_database_migration',
    problemMessage:
        'Database model without migration support. Schema changes may break data.',
    correctionMessage:
        'Implement versioned migrations for database schema changes.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String classSource = node.toSource();

      // Check for Hive model patterns
      if (classSource.contains('@HiveType') ||
          classSource.contains('@HiveField')) {
        // Check if project has migration infrastructure
        // (This is a heuristic - real check would need project context)

        // Check for versioning in class or nearby
        if (!classSource.contains('version') &&
            !classSource.contains('Version') &&
            !classSource.contains('migration') &&
            !classSource.contains('Migration') &&
            !classSource.contains('schema') &&
            !classSource.contains('Schema')) {
          // Count HiveFields to estimate complexity
          final int fieldCount =
              RegExp(r'@HiveField\(\d+\)').allMatches(classSource).length;

          // If many fields, more likely to evolve and need migrations
          if (fieldCount >= 5) {
            reporter.atNode(node, code);
          }
        }
      }

      // Check for Isar model patterns
      if (classSource.contains('@collection') ||
          classSource.contains('@Collection')) {
        if (!classSource.contains('migration') &&
            !classSource.contains('Migration') &&
            !classSource.contains('schema') &&
            !classSource.contains('version')) {
          final String className = node.name.lexeme;
          if (!className.contains('Migration') &&
              !className.contains('Version')) {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }
}

/// Warns when frequently queried database fields lack indices.
///
/// Alias: index_database_field, add_query_index
///
/// Queries on non-indexed fields are slow. Add indices for fields
/// used in where clauses, especially in large collections.
///
/// **BAD:**
/// ```dart
/// @collection
/// class Product {
///   Id id = Isar.autoIncrement;
///   String category; // Queried but not indexed
///   double price;
/// }
///
/// // Slow query!
/// final products = await isar.products
///     .filter()
///     .categoryEqualTo('electronics')
///     .findAll();
/// ```
///
/// **GOOD:**
/// ```dart
/// @collection
/// class Product {
///   Id id = Isar.autoIncrement;
///
///   @Index()
///   String category;
///
///   @Index()
///   double price;
/// }
/// ```
class RequireDatabaseIndexRule extends SaropaLintRule {
  const RequireDatabaseIndexRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_database_index',
    problemMessage:
        'Database query on non-indexed field. Add @Index for better performance.',
    correctionMessage:
        'Add @Index() annotation to fields used in queries and filters.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for query/filter methods
      if (!methodName.contains('filter') &&
          !methodName.contains('where') &&
          !methodName.contains('query') &&
          !methodName.contains('find')) {
        return;
      }

      // Check parent chain for database patterns
      AstNode? current = node.parent;
      bool isDatabaseQuery = false;

      while (current != null) {
        final String source = current.toSource();
        if (source.contains('.products') ||
            source.contains('.users') ||
            source.contains('.items') ||
            source.contains('.documents') ||
            source.contains('collection(') ||
            source.contains('isar.') ||
            source.contains('realm.')) {
          isDatabaseQuery = true;
          break;
        }
        if (current is MethodDeclaration) break;
        current = current.parent;
      }

      if (!isDatabaseQuery) return;

      // Check if the query includes field filtering
      final String nodeSource = node.toSource();
      if (nodeSource.contains('EqualTo') ||
          nodeSource.contains('GreaterThan') ||
          nodeSource.contains('LessThan') ||
          nodeSource.contains('Between') ||
          nodeSource.contains('where(')) {
        // This is a filter query - suggest indexing
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when multiple database writes are not batched in transactions.
///
/// Alias: batch_database_writes, use_transaction
///
/// Individual writes are slower and can leave data inconsistent.
/// Use transactions or batch writes for multiple related changes.
///
/// **BAD:**
/// ```dart
/// await box.put('user1', user1);
/// await box.put('user2', user2);
/// await box.put('user3', user3);
/// // Three separate writes - slow and not atomic
/// ```
///
/// **GOOD:**
/// ```dart
/// await isar.writeTxn(() async {
///   await isar.users.putAll([user1, user2, user3]);
/// });
///
/// // Or with Firestore:
/// final batch = firestore.batch();
/// batch.set(ref1, data1);
/// batch.set(ref2, data2);
/// await batch.commit();
/// ```
class PreferTransactionForBatchRule extends SaropaLintRule {
  const PreferTransactionForBatchRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_transaction_for_batch',
    problemMessage:
        'Multiple sequential database writes. Use transaction for atomicity.',
    correctionMessage:
        'Wrap related writes in a transaction or use batch operations.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Count individual write operations, excluding batch variants
      final int putCount = '.put('.allMatches(bodySource).length -
          '.putIfAbsent('.allMatches(bodySource).length -
          '.putAll('.allMatches(bodySource).length;
      final int addCount = '.add('.allMatches(bodySource).length -
          '.addAll('.allMatches(bodySource).length;
      final int insertCount = '.insert('.allMatches(bodySource).length -
          '.insertAll('.allMatches(bodySource).length;
      final int deleteCount = '.delete('.allMatches(bodySource).length -
          '.deleteAll('.allMatches(bodySource).length;
      final int updateCount = '.update('.allMatches(bodySource).length -
          '.updateAll('.allMatches(bodySource).length;
      final int setCount = '.set('.allMatches(bodySource).length;

      final int writeOps = putCount +
          addCount +
          insertCount +
          deleteCount +
          updateCount +
          setCount;

      // If few writes, not a concern
      if (writeOps < 3) return;

      // Check if already using transactions/batches
      if (bodySource.contains('writeTxn') ||
          bodySource.contains('transaction') ||
          bodySource.contains('Transaction') ||
          bodySource.contains('.batch()') ||
          bodySource.contains('batch.') ||
          bodySource.contains('Batch') ||
          bodySource.contains('putAll') ||
          bodySource.contains('addAll') ||
          bodySource.contains('insertAll')) {
        return; // Already using batch/transaction pattern
      }

      reporter.atNode(node, code);
    });
  }
}

/// Warns when database connections are not properly closed.
///
/// Alias: close_database, database_connection_leak
///
/// Unclosed database connections cause resource leaks and can prevent
/// proper app shutdown. Always close databases in dispose.
///
/// **BAD:**
/// ```dart
/// class DataService {
///   Isar? _isar;
///
///   Future<void> init() async {
///     _isar = await Isar.open([UserSchema]);
///   }
///   // Missing close()!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class DataService {
///   Isar? _isar;
///
///   Future<void> init() async {
///     _isar = await Isar.open([UserSchema]);
///   }
///
///   Future<void> dispose() async {
///     await _isar?.close();
///   }
/// }
/// ```
class RequireHiveDatabaseCloseRule extends SaropaLintRule {
  const RequireHiveDatabaseCloseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_hive_database_close',
    problemMessage:
        'Database opened but no close() method found. Resource leak risk.',
    correctionMessage: 'Add dispose() method that calls database.close().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String classSource = node.toSource();

      // Check for database open patterns
      final bool opensDatabase = classSource.contains('Isar.open') ||
          classSource.contains('Hive.openBox') ||
          classSource.contains('openDatabase') ||
          classSource.contains('Realm.open') ||
          classSource.contains('Database.open');

      if (!opensDatabase) return;

      // Check for close patterns
      final bool hasClose = classSource.contains('.close()') ||
          classSource.contains('dispose()') ||
          classSource.contains('_close') ||
          classSource.contains('closeDatabase');

      if (!hasClose) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Hive type adapters are used without registration.
///
/// Alias: register_hive_adapter, hive_adapter_missing
///
/// Custom Hive types require adapters to be registered before use.
/// Unregistered adapters cause runtime errors.
///
/// **BAD:**
/// ```dart
/// void main() async {
///   await Hive.initFlutter();
///   await Hive.openBox<User>('users'); // Error: No adapter for User!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void main() async {
///   await Hive.initFlutter();
///   Hive.registerAdapter(UserAdapter());
///   await Hive.openBox<User>('users');
/// }
/// ```
class RequireTypeAdapterRegistrationRule extends SaropaLintRule {
  const RequireTypeAdapterRegistrationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_type_adapter_registration',
    problemMessage:
        'Hive box opened with custom type but adapter may not be registered.',
    correctionMessage:
        'Ensure Hive.registerAdapter() is called before opening typed boxes.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for Hive openBox calls
      if (methodName != 'openBox' && methodName != 'openLazyBox') return;

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (!targetSource.contains('Hive')) return;

      // Check if opening a typed box
      final NodeList<TypeAnnotation>? typeArgs = node.typeArguments?.arguments;
      if (typeArgs == null || typeArgs.isEmpty) return;

      final String typeArg = typeArgs.first.toSource();

      // Skip primitive types
      if (typeArg == 'String' ||
          typeArg == 'int' ||
          typeArg == 'double' ||
          typeArg == 'bool' ||
          typeArg == 'dynamic') {
        return;
      }

      // Check if there's a registerAdapter call nearby
      AstNode? current = node.parent;
      while (current != null) {
        if (current is MethodDeclaration || current is FunctionDeclaration) {
          break;
        }
        current = current.parent;
      }

      if (current == null) return;

      final String scopeSource = current.toSource();
      final String adapterName = '${typeArg}Adapter';

      if (!scopeSource.contains('registerAdapter') ||
          !scopeSource.contains(adapterName)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when large data is loaded into regular Hive boxes instead of lazy.
///
/// Alias: use_lazy_box, hive_lazy_loading
///
/// Regular boxes load all data into memory at open time. For large
/// datasets, use lazy boxes that load values on demand.
///
/// **BAD:**
/// ```dart
/// // Loads ALL products into memory
/// final box = await Hive.openBox<Product>('products');
/// final product = box.get(id);
/// ```
///
/// **GOOD:**
/// ```dart
/// // Only loads requested product
/// final box = await Hive.openLazyBox<Product>('products');
/// final product = await box.get(id);
/// ```
class PreferLazyBoxForLargeRule extends SaropaLintRule {
  const PreferLazyBoxForLargeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_lazy_box_for_large',
    problemMessage:
        'Large collection uses regular Hive box. Consider openLazyBox for memory.',
    correctionMessage:
        'Use Hive.openLazyBox() for collections that may grow large.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Box names that typically contain many items
  static const Set<String> _largeCollectionNames = {
    'products',
    'items',
    'messages',
    'logs',
    'events',
    'transactions',
    'orders',
    'history',
    'cache',
    'records',
    'data',
    'entries',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Only check regular openBox (not openLazyBox)
      if (methodName != 'openBox') return;

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (!targetSource.contains('Hive')) return;

      // Check box name argument
      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      final String boxName = firstArg.toSource().toLowerCase();

      // Check if this looks like a potentially large collection
      for (final String largeName in _largeCollectionNames) {
        if (boxName.contains(largeName)) {
          reporter.atNode(node, code);
          return;
        }
      }

      // Also check type argument for collection-like types
      final NodeList<TypeAnnotation>? typeArgs = node.typeArguments?.arguments;
      if (typeArgs != null && typeArgs.isNotEmpty) {
        final String typeArg = typeArgs.first.toSource().toLowerCase();
        for (final String largeName in _largeCollectionNames) {
          if (typeArg.contains(largeName)) {
            reporter.atNode(node, code);
            return;
          }
        }
      }
    });
  }
}

/// Warns when Firebase Analytics event name doesn't follow conventions.
///
/// Alias: firebase_event_naming, analytics_event_format
///
/// Firebase Analytics has strict naming conventions:
/// - Must start with a letter
/// - Can only contain alphanumeric characters and underscores
/// - Must be 1-40 characters
/// - Cannot start with 'firebase_', 'google_', or 'ga_' (reserved)
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// analytics.logEvent(name: 'User-Clicked-Button'); // Hyphens not allowed
/// analytics.logEvent(name: 'firebase_custom'); // Reserved prefix
/// analytics.logEvent(name: '123_event'); // Must start with letter
/// ```
///
/// #### GOOD:
/// ```dart
/// analytics.logEvent(name: 'user_clicked_button');
/// analytics.logEvent(name: 'purchase_completed');
/// ```
class IncorrectFirebaseEventNameRule extends SaropaLintRule {
  const IncorrectFirebaseEventNameRule() : super(code: _code);

  /// Critical issue. Invalid event names are silently dropped.
  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'incorrect_firebase_event_name',
    problemMessage:
        'Firebase Analytics event name does not follow conventions.',
    correctionMessage:
        'Event names must: start with a letter, contain only alphanumeric '
        'and underscores, be 1-40 chars, and not use reserved prefixes.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// Valid event name pattern
  static final RegExp _validEventName = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{0,39}$');

  /// Reserved prefixes
  static const List<String> _reservedPrefixes = <String>[
    'firebase_',
    'google_',
    'ga_',
  ];

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'logEvent') return;

      // Find the 'name' argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'name') {
          final Expression value = arg.expression;
          if (value is StringLiteral) {
            final String? eventName = value.stringValue;
            if (eventName != null && !_isValidEventName(eventName)) {
              reporter.atNode(value, code);
            }
          }
        }
      }
    });
  }

  bool _isValidEventName(String name) {
    // Check reserved prefixes
    for (final String prefix in _reservedPrefixes) {
      if (name.toLowerCase().startsWith(prefix)) {
        return false;
      }
    }

    // Check pattern
    return _validEventName.hasMatch(name);
  }
}

/// Warns when Firebase Analytics parameter name doesn't follow conventions.
///
/// Alias: firebase_param_naming, analytics_param_format
///
/// Firebase Analytics parameters have strict naming conventions:
/// - Must start with a letter
/// - Can only contain alphanumeric characters and underscores
/// - Must be 1-40 characters
/// - Cannot start with 'firebase_', 'google_', or 'ga_' (reserved)
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// analytics.logEvent(
///   name: 'purchase',
///   parameters: {
///     'item-id': '123', // Hyphens not allowed
///     'firebase_custom': 'value', // Reserved prefix
///   },
/// );
/// ```
///
/// #### GOOD:
/// ```dart
/// analytics.logEvent(
///   name: 'purchase',
///   parameters: {
///     'item_id': '123',
///     'item_name': 'Widget',
///   },
/// );
/// ```
class IncorrectFirebaseParameterNameRule extends SaropaLintRule {
  const IncorrectFirebaseParameterNameRule() : super(code: _code);

  /// Critical issue. Invalid parameter names are silently dropped.
  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'incorrect_firebase_parameter_name',
    problemMessage:
        'Firebase Analytics parameter name does not follow conventions.',
    correctionMessage:
        'Parameter names must: start with a letter, contain only alphanumeric '
        'and underscores, be 1-40 chars, and not use reserved prefixes.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// Valid parameter name pattern
  static final RegExp _validParamName = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{0,39}$');

  /// Reserved prefixes
  static const List<String> _reservedPrefixes = <String>[
    'firebase_',
    'google_',
    'ga_',
  ];

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'logEvent') return;

      // Find the 'parameters' argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'parameters') {
          final Expression value = arg.expression;
          if (value is SetOrMapLiteral) {
            _checkMapLiteral(value, reporter);
          }
        }
      }
    });
  }

  void _checkMapLiteral(
    SetOrMapLiteral mapLiteral,
    SaropaDiagnosticReporter reporter,
  ) {
    for (final CollectionElement element in mapLiteral.elements) {
      if (element is MapLiteralEntry) {
        final Expression key = element.key;
        if (key is StringLiteral) {
          final String? paramName = key.stringValue;
          if (paramName != null && !_isValidParamName(paramName)) {
            reporter.atNode(key, code);
          }
        }
      }
    }
  }

  bool _isValidParamName(String name) {
    // Check reserved prefixes
    for (final String prefix in _reservedPrefixes) {
      if (name.toLowerCase().startsWith(prefix)) {
        return false;
      }
    }

    // Check pattern
    return _validParamName.hasMatch(name);
  }
}

/// Warns when multiple individual Firestore writes could be batched.
///
/// Alias: firestore_batch_write, batch_firestore_ops
///
/// Multiple individual write operations are slower and more expensive than
/// batch writes. Use WriteBatch for multiple related operations.
///
/// **BAD:**
/// ```dart
/// await doc1.set(data1);
/// await doc2.set(data2);
/// await doc3.set(data3);
/// ```
///
/// **GOOD:**
/// ```dart
/// final batch = FirebaseFirestore.instance.batch();
/// batch.set(doc1, data1);
/// batch.set(doc2, data2);
/// batch.set(doc3, data3);
/// await batch.commit();
/// ```
class PreferFirestoreBatchWriteRule extends SaropaLintRule {
  const PreferFirestoreBatchWriteRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_firestore_batch_write',
    problemMessage: 'Multiple individual Firestore writes should be batched.',
    correctionMessage: 'Use WriteBatch for multiple related write operations.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBlock((Block node) {
      int firestoreWriteCount = 0;
      MethodInvocation? firstWrite;

      for (final Statement statement in node.statements) {
        if (statement is ExpressionStatement) {
          final Expression expr = statement.expression;
          if (expr is AwaitExpression) {
            final Expression awaited = expr.expression;
            if (awaited is MethodInvocation) {
              final String methodName = awaited.methodName.name;
              if (methodName == 'set' ||
                  methodName == 'update' ||
                  methodName == 'delete') {
                // Check if it's a Firestore operation
                final String source = awaited.toSource();
                if (source.contains('.doc(') ||
                    source.contains('DocumentReference') ||
                    source.contains('Firestore')) {
                  firestoreWriteCount++;
                  firstWrite ??= awaited;
                }
              }
            }
          }
        }
      }

      // Report if there are 3 or more consecutive writes
      if (firestoreWriteCount >= 3 && firstWrite != null) {
        reporter.atNode(firstWrite, code);
      }
    });
  }
}

/// Warns when Firestore operations are performed in widget build method.
///
/// Alias: no_firestore_in_build, firestore_query_in_build
///
/// Firestore queries in build() execute on every rebuild, causing performance
/// issues and unnecessary reads. Use StreamBuilder, FutureBuilder, or state
/// management instead.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   final data = FirebaseFirestore.instance.collection('users').get();
///   // ...
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return StreamBuilder<QuerySnapshot>(
///     stream: FirebaseFirestore.instance.collection('users').snapshots(),
///     builder: (context, snapshot) => ...,
///   );
/// }
/// ```
class AvoidFirestoreInWidgetBuildRule extends SaropaLintRule {
  const AvoidFirestoreInWidgetBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_firestore_in_widget_build',
    problemMessage: 'Firestore operation in build() causes queries on rebuild.',
    correctionMessage: 'Use StreamBuilder/FutureBuilder or state management.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for Firestore get or collection operations
      final String methodName = node.methodName.name;
      if (methodName != 'get' &&
          methodName != 'collection' &&
          methodName != 'doc') {
        return;
      }

      // Check if it's Firestore-related
      final String source = node.toSource();
      if (!source.contains('Firestore') && !source.contains('firestore')) {
        return;
      }

      // Check if inside build method
      if (!_isInsideBuildMethod(node)) return;

      // Allow if inside StreamBuilder or FutureBuilder
      if (_isInsideBuilder(node)) return;

      reporter.atNode(node, code);
    });
  }

  bool _isInsideBuildMethod(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration && current.name.lexeme == 'build') {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  bool _isInsideBuilder(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is InstanceCreationExpression) {
        final String typeName = current.constructorName.type.name.lexeme;
        if (typeName.contains('Builder')) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when RemoteConfig is used without setting defaults.
///
/// Alias: remote_config_defaults, set_remote_defaults
///
/// RemoteConfig values may not be fetched immediately. Without defaults,
/// the app may have undefined behavior on first launch or offline.
///
/// **BAD:**
/// ```dart
/// final value = remoteConfig.getString('feature_key');
/// ```
///
/// **GOOD:**
/// ```dart
/// await remoteConfig.setDefaults({
///   'feature_key': 'default_value',
/// });
/// final value = remoteConfig.getString('feature_key');
/// ```
class PreferFirebaseRemoteConfigDefaultsRule extends SaropaLintRule {
  const PreferFirebaseRemoteConfigDefaultsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'prefer_firebase_remote_config_defaults',
    problemMessage: 'RemoteConfig should have defaults set before use.',
    correctionMessage: 'Call setDefaults() with fallback values.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Track if setDefaults is called
    bool hasSetDefaults = false;

    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName == 'setDefaults' || methodName == 'setConfigSettings') {
        hasSetDefaults = true;
        return;
      }

      // Check for RemoteConfig get methods without setDefaults
      if (methodName.startsWith('get') &&
          (methodName == 'getString' ||
              methodName == 'getBool' ||
              methodName == 'getInt' ||
              methodName == 'getDouble')) {
        final Expression? target = node.target;
        if (target == null) return;

        final String targetSource = target.toSource();
        if (!targetSource.contains('remoteConfig') &&
            !targetSource.contains('RemoteConfig')) {
          return;
        }

        if (!hasSetDefaults) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when FCM is used without handling token refresh.
///
/// Alias: fcm_token_refresh, handle_token_refresh
///
/// FCM tokens can be refreshed at any time. Without handling onTokenRefresh,
/// the server may have stale tokens and messages won't be delivered.
///
/// **BAD:**
/// ```dart
/// final token = await messaging.getToken();
/// // Send to server - but no refresh handling!
/// ```
///
/// **GOOD:**
/// ```dart
/// final token = await messaging.getToken();
/// sendToServer(token);
///
/// messaging.onTokenRefresh.listen((newToken) {
///   sendToServer(newToken);
/// });
/// ```
class RequireFcmTokenRefreshHandlerRule extends SaropaLintRule {
  const RequireFcmTokenRefreshHandlerRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_fcm_token_refresh_handler',
    problemMessage: 'FCM token refresh should be handled.',
    correctionMessage:
        'Listen to onTokenRefresh to update server with new tokens.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    bool hasTokenRefreshHandler = false;
    MethodInvocation? getTokenCall;

    context.registry.addPropertyAccess((PropertyAccess node) {
      if (node.propertyName.name == 'onTokenRefresh') {
        hasTokenRefreshHandler = true;
      }
    });

    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'getToken') {
        final Expression? target = node.target;
        if (target == null) return;

        final String targetSource = target.toSource();
        if (targetSource.contains('messaging') ||
            targetSource.contains('Messaging') ||
            targetSource.contains('FirebaseMessaging')) {
          getTokenCall = node;
        }
      }
    });

    // Use addCompilationUnit to report at the end
    context.registry.addCompilationUnit((CompilationUnit unit) {
      if (getTokenCall != null && !hasTokenRefreshHandler) {
        reporter.atNode(getTokenCall!, code);
      }
    });
  }
}

/// Warns when FCM is used without a background message handler.
///
/// Alias: fcm_background_handler, background_message_handler
///
/// FCM messages received when app is terminated need a top-level background
/// handler. Without it, background messages are lost.
///
/// **BAD:**
/// ```dart
/// FirebaseMessaging.onMessage.listen((message) {
///   // Only handles foreground messages!
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// @pragma('vm:entry-point')
/// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage msg) async {
///   // Handle background message
/// }
///
/// void main() async {
///   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
/// }
/// ```
class RequireBackgroundMessageHandlerRule extends SaropaLintRule {
  const RequireBackgroundMessageHandlerRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_background_message_handler',
    problemMessage: 'FCM should have a background message handler.',
    correctionMessage:
        'Add onBackgroundMessage with a top-level handler function.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    bool hasBackgroundHandler = false;
    PropertyAccess? onMessageAccess;

    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'onBackgroundMessage') {
        hasBackgroundHandler = true;
      }
    });

    context.registry.addPropertyAccess((PropertyAccess node) {
      if (node.propertyName.name == 'onMessage') {
        final String source = node.toSource();
        if (source.contains('Messaging') || source.contains('messaging')) {
          onMessageAccess = node;
        }
      }
      if (node.propertyName.name == 'onBackgroundMessage') {
        hasBackgroundHandler = true;
      }
    });

    context.registry.addCompilationUnit((CompilationUnit unit) {
      if (onMessageAccess != null && !hasBackgroundHandler) {
        reporter.atNode(onMessageAccess!, code);
      }
    });
  }
}

/// Warns when map markers are created in build method.
///
/// Alias: cache_map_markers, no_markers_in_build
///
/// Creating markers in build() causes recreation on every rebuild,
/// leading to flickering and performance issues. Cache markers.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return GoogleMap(
///     markers: locations.map((loc) => Marker(
///       markerId: MarkerId(loc.id),
///       position: loc.position,
///     )).toSet(),
///   );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Set<Marker>? _cachedMarkers;
///
/// Set<Marker> get markers {
///   return _cachedMarkers ??= locations.map((loc) => Marker(
///     markerId: MarkerId(loc.id),
///     position: loc.position,
///   )).toSet();
/// }
/// ```
class AvoidMapMarkersInBuildRule extends SaropaLintRule {
  const AvoidMapMarkersInBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_map_markers_in_build',
    problemMessage: 'Creating map markers in build() causes flickering.',
    correctionMessage: 'Cache markers in state and only recreate when needed.',
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
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Marker') return;

      // Check if inside build method
      if (!_isInsideBuildMethod(node)) return;

      reporter.atNode(node, code);
    });
  }

  bool _isInsideBuildMethod(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration && current.name.lexeme == 'build') {
        return true;
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when map data is fetched on onCameraMove instead of onCameraIdle.
///
/// Alias: map_camera_idle, no_fetch_on_camera_move
///
/// onCameraMove fires continuously during pan/zoom, causing excessive API calls.
/// Use onCameraIdle to fetch data only when movement stops.
///
/// **BAD:**
/// ```dart
/// GoogleMap(
///   onCameraMove: (position) {
///     fetchMarkersForRegion(position.target);  // Fires 60x/second!
///   },
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// GoogleMap(
///   onCameraIdle: () {
///     final position = mapController.camera;
///     fetchMarkersForRegion(position.center);
///   },
/// )
/// ```
class RequireMapIdleCallbackRule extends SaropaLintRule {
  const RequireMapIdleCallbackRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_map_idle_callback',
    problemMessage: 'Data fetching should use onCameraIdle, not onCameraMove.',
    correctionMessage: 'Move data fetching to onCameraIdle to prevent spam.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addNamedExpression((NamedExpression node) {
      if (node.name.label.name != 'onCameraMove') return;

      // Check if the callback contains fetch/load/get operations
      final Expression value = node.expression;
      if (value is! FunctionExpression) return;

      final String bodySource = value.body.toSource();
      if (bodySource.contains('fetch') ||
          bodySource.contains('load') ||
          bodySource.contains('get') ||
          bodySource.contains('http') ||
          bodySource.contains('Http') ||
          bodySource.contains('api') ||
          bodySource.contains('Api')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when many individual map markers are used without clustering.
///
/// Alias: marker_clustering, cluster_map_markers
///
/// Displaying hundreds of markers individually causes performance issues.
/// Use marker clustering for better performance and UX.
///
/// **BAD:**
/// ```dart
/// GoogleMap(
///   markers: allLocations.map((loc) => Marker(...)).toSet(),  // 500 markers!
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use flutter_map_marker_cluster or google_maps_cluster_manager
/// FlutterMap(
///   children: [
///     MarkerClusterLayerWidget(
///       options: MarkerClusterLayerOptions(
///         markers: markers,
///       ),
///     ),
///   ],
/// )
/// ```
class PreferMarkerClusteringRule extends SaropaLintRule {
  const PreferMarkerClusteringRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_marker_clustering',
    problemMessage: 'Consider using marker clustering for better performance.',
    correctionMessage: 'Use marker clustering library for many markers.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addNamedExpression((NamedExpression node) {
      if (node.name.label.name != 'markers') return;

      // Check if using .map() to create markers from a collection
      final Expression value = node.expression;
      final String valueSource = value.toSource();

      // Look for patterns that suggest many markers
      if (valueSource.contains('.map(') && valueSource.contains('Marker')) {
        reporter.atNode(node, code);
      }
    });
  }
}
