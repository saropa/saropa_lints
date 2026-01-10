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
