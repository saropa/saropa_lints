// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Firebase and database lint rules for Flutter applications.
///
/// These rules help identify common Firebase/Firestore issues including
/// unbounded queries, missing limits, and improper database usage patterns.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_firestore_unbounded_query',
    problemMessage:
        '[avoid_firestore_unbounded_query] Firestore query without limit() returns unbounded data from the entire collection. This triggers excessive bandwidth consumption, inflated Firestore read costs, slow UI rendering, and out-of-memory crashes on low-end devices when the collection grows large.',
    correctionMessage:
        'Add .limit(n) to cap the number of documents returned and prevent unbounded queries. Unbounded reads can result in high bills, slow apps, and out-of-memory errors.',
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

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_database_in_build',
    problemMessage:
        '[avoid_database_in_build] Running database queries inside build() causes the query to execute on every rebuild, leading to repeated database hits, slow UI, increased backend load, and degraded app performance. This can also cause inconsistent data, race conditions, and higher costs for cloud databases.',
    correctionMessage:
        'Move database queries to initState(), use cached futures, or employ state management solutions to avoid repeated queries. Document query logic to ensure efficient and predictable data access.',
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_secure_storage_on_web',
    problemMessage:
        '[avoid_secure_storage_on_web] flutter_secure_storage uses localStorage on web, which is not secure. Sensitive data stored in localStorage may be exposed to attackers, browser extensions, or other scripts, violating user privacy and security requirements. This can lead to credential theft, data breaches, and app store rejection.',
    correctionMessage:
        'Check kIsWeb and use an alternative secure storage solution for web platforms, such as IndexedDB or encrypted cookies. Document platform-specific storage logic to ensure data security.',
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

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_firebase_init_before_use',
    problemMessage:
        '[require_firebase_init_before_use] Firebase services crash if accessed '
        'before initializeApp() completes. App fails on startup.',
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
/// Alias: schema_versioning
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

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_database_migration',
    problemMessage:
        '[require_database_migration] Database models must support versioned migrations to handle schema changes safely. Without migration logic, updates to the schema can break data, cause runtime errors, and result in data loss or corruption. This is a critical reliability and maintainability issue for any persistent storage solution.',
    correctionMessage:
        'Implement versioned migrations for all database schema changes. Document migration steps and test upgrades to ensure data integrity and smooth user updates.',
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_database_index',
    problemMessage:
        '[require_database_index] Query on non-indexed field causes full table scan.',
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
/// Uses AST type resolution to distinguish database writes from in-memory
/// collection operations (List.add, Set.add, Map.put, etc.).
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

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_transaction_for_batch',
    problemMessage:
        '[prefer_transaction_for_batch] Multiple sequential database writes. Use transaction for atomicity.',
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
      final _DatabaseWriteCounter counter = _DatabaseWriteCounter();
      node.body.accept(counter);

      if (counter.hasTransaction || counter.writeCount < 3) return;

      reporter.atNode(node, code);
    });
  }
}

/// Walks a method body's AST to count potential database write operations,
/// skipping known in-memory collection types to avoid false positives.
class _DatabaseWriteCounter extends RecursiveAstVisitor<void> {
  int writeCount = 0;
  bool hasTransaction = false;

  /// Method names that indicate individual write operations.
  static const Set<String> _writeMethodNames = <String>{
    'add',
    'delete',
    'insert',
    'put',
    'set',
    'update',
  };

  /// Method names that indicate batch or transaction usage.
  static const Set<String> _batchMethodNames = <String>{
    'addAll',
    'batch',
    'commit',
    'deleteAll',
    'insertAll',
    'putAll',
    'transaction',
    'updateAll',
    'writeTxn',
  };

  /// Known in-memory collection types where write-like method names
  /// are not database operations.
  static const Set<String> _safeCollectionTypes = <String>{
    'DoubleLinkedQueue',
    'HashMap',
    'HashSet',
    'Iterable',
    'LinkedHashMap',
    'LinkedHashSet',
    'LinkedList',
    'List',
    'ListQueue',
    'Map',
    'Queue',
    'Set',
    'SplayTreeMap',
    'SplayTreeSet',
    'UnmodifiableListView',
    'UnmodifiableMapView',
  };

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String name = node.methodName.name;

    if (_batchMethodNames.contains(name)) {
      hasTransaction = true;
    }

    if (_writeMethodNames.contains(name)) {
      _countIfDatabaseTarget(node);
    }

    super.visitMethodInvocation(node);
  }

  void _countIfDatabaseTarget(MethodInvocation node) {
    final Expression? target = node.target;
    if (target == null) return; // Implicit this — unlikely to be a DB call

    final DartType? type = target.staticType;
    if (type == null) return; // Unresolvable type — skip to avoid FP

    final String? elementName = type.element?.name;
    if (elementName == null) return; // dynamic or unresolvable

    if (!_safeCollectionTypes.contains(elementName)) {
      writeCount++;
    }
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'incorrect_firebase_event_name',
    problemMessage:
        '[incorrect_firebase_event_name] Invalid event name is silently dropped '
        'by Firebase Analytics. Your analytics data will be incomplete.',
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'incorrect_firebase_parameter_name',
    problemMessage:
        '[incorrect_firebase_parameter_name] Invalid parameter names are '
        'silently dropped by Firebase. Event data will be missing fields.',
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

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_firestore_batch_write',
    problemMessage:
        '[prefer_firestore_batch_write] Individual writes increase latency and billing costs.',
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

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_firestore_in_widget_build',
    problemMessage:
        '[avoid_firestore_in_widget_build] Performing Firestore operations (get, collection, doc) inside build() causes the query to run on every rebuild, leading to excessive database reads, slow UI, increased backend costs, and potential quota exhaustion. This can also cause inconsistent data, race conditions, and degraded user experience, especially in dynamic UIs.',
    correctionMessage:
        'Move Firestore queries to StreamBuilder, FutureBuilder, or state management logic outside build(). Cache results and avoid triggering database reads on every rebuild. Document query logic for maintainability and test for correct data flow.',
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_firebase_remote_config_defaults',
    problemMessage:
        '[prefer_firebase_remote_config_defaults] Missing defaults cause '
        'null/zero values when fetch fails, breaking app behavior.',
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_fcm_token_refresh_handler',
    problemMessage:
        '[require_fcm_token_refresh_handler] FCM tokens expire periodically. '
        'Without onTokenRefresh handling, push notifications will stop working.',
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_background_message_handler',
    problemMessage:
        '[require_background_message_handler] Push notifications received when '
        'app is terminated are silently dropped without handler.',
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_map_markers_in_build',
    problemMessage:
        '[avoid_map_markers_in_build] Creating map markers in build() causes flickering.',
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

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_map_idle_callback',
    problemMessage:
        '[require_map_idle_callback] Data fetching triggered in onCameraMove fires on every frame during map pan and zoom gestures. This spams backend APIs with hundreds of redundant requests per second, causes severe performance degradation with UI jank, and wastes user bandwidth and battery on mobile devices.',
    correctionMessage:
        'Move data-fetching logic to the onCameraIdle callback, which fires once after the user stops interacting with the map, preventing API spam and frame drops.',
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

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_marker_clustering',
    problemMessage:
        '[prefer_marker_clustering] Many markers cause frame drops and memory issues.',
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

/// Warns when FirebaseCrashlytics is used without setting user identifier.
///
/// Setting a user identifier helps track crashes to specific users
/// for better debugging and support. Without it, crashes are anonymous.
///
/// **BAD:**
/// ```dart
/// void initCrashlytics() async {
///   await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
///   // Missing setUserIdentifier!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void initCrashlytics(String userId) async {
///   await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
///   await FirebaseCrashlytics.instance.setUserIdentifier(userId);
/// }
/// ```
///
/// **Note:** This rule checks within the same method. Cross-method detection
/// is not possible with static analysis.
class RequireCrashlyticsUserIdRule extends SaropaLintRule {
  const RequireCrashlyticsUserIdRule() : super(code: _code);

  /// Debugging improvement - not critical but helpful.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_crashlytics_user_id',
    problemMessage:
        '[require_crashlytics_user_id] Crashlytics setup without setUserIdentifier. Crashes will be anonymous.',
    correctionMessage:
        'Add FirebaseCrashlytics.instance.setUserIdentifier(userId).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      final methodName = node.methodName.name;

      // Check for Crashlytics configuration methods
      if (methodName != 'setCrashlyticsCollectionEnabled' &&
          methodName != 'recordError' &&
          methodName != 'log') {
        return;
      }

      // Check target is FirebaseCrashlytics
      final targetSource = node.target?.toSource() ?? '';
      if (!targetSource.contains('Crashlytics')) {
        return;
      }

      // Find enclosing method
      AstNode? current = node.parent;
      MethodDeclaration? enclosingMethod;

      while (current != null) {
        if (current is MethodDeclaration) {
          enclosingMethod = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingMethod == null) {
        return;
      }

      final methodSource = enclosingMethod.toSource();

      // Check if setUserIdentifier is called
      if (!methodSource.contains('setUserIdentifier')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Firebase services are used without App Check.
///
/// Firebase App Check helps protect your backend resources from abuse.
/// Without it, your Firebase services are vulnerable to unauthorized access.
///
/// **BAD:**
/// ```dart
/// void initFirebase() async {
///   await Firebase.initializeApp();
///   // Using Firestore without App Check
///   FirebaseFirestore.instance.collection('users').get();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void initFirebase() async {
///   await Firebase.initializeApp();
///   await FirebaseAppCheck.instance.activate();
///   FirebaseFirestore.instance.collection('users').get();
/// }
/// ```
///
/// **Note:** This is an INFO-level reminder. App Check activation typically
/// happens once at app startup, not necessarily in the same file.
class RequireFirebaseAppCheckRule extends SaropaLintRule {
  const RequireFirebaseAppCheckRule() : super(code: _code);

  /// Security improvement - protects backend from abuse.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_firebase_app_check',
    problemMessage:
        '[require_firebase_app_check] Firebase initialization without App Check activation.',
    correctionMessage:
        'Add FirebaseAppCheck.instance.activate() after Firebase.initializeApp().',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      // Check for Firebase.initializeApp()
      final target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Firebase') {
        return;
      }

      if (node.methodName.name != 'initializeApp') {
        return;
      }

      // Find enclosing method
      AstNode? current = node.parent;
      MethodDeclaration? enclosingMethod;

      while (current != null) {
        if (current is MethodDeclaration) {
          enclosingMethod = current;
          break;
        }
        if (current is FunctionDeclaration) {
          // Check function body
          final funcSource = current.toSource();
          if (funcSource.contains('FirebaseAppCheck') &&
              funcSource.contains('activate')) {
            return;
          }
          reporter.atNode(node, code);
          return;
        }
        current = current.parent;
      }

      if (enclosingMethod == null) {
        return;
      }

      final methodSource = enclosingMethod.toSource();

      // Check if App Check is activated
      if (!methodSource.contains('FirebaseAppCheck') ||
          !methodSource.contains('activate')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when setCustomClaims stores large user data.
///
/// Firebase custom claims are meant for access control, not user data storage.
/// They're limited to 1000 bytes and are included in every auth token.
///
/// **BAD:**
/// ```dart
/// await admin.auth().setCustomUserClaims(uid, {
///   'profile': userProfile,  // Large object!
///   'preferences': allPrefs,
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// await admin.auth().setCustomUserClaims(uid, {
///   'role': 'admin',
///   'tier': 'premium',
/// });
/// // Store large data in Firestore instead
/// ```
class AvoidStoringUserDataInAuthRule extends SaropaLintRule {
  const AvoidStoringUserDataInAuthRule() : super(code: _code);

  /// Architectural issue - misuse of custom claims.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_storing_user_data_in_auth',
    problemMessage:
        '[avoid_storing_user_data_in_auth] Large object in setCustomClaims. Claims are for roles, not data storage.',
    correctionMessage:
        'Store user data in Firestore. Use claims only for access control (roles, permissions).',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const _dataTerms = [
    'profile',
    'preferences',
    'settings',
    'address',
    'history',
    'data',
    'info',
    'details',
    'metadata',
  ];

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      final methodName = node.methodName.name;

      if (methodName != 'setCustomUserClaims' &&
          methodName != 'setCustomClaims') {
        return;
      }

      // Check arguments for large data patterns
      for (final arg in node.argumentList.arguments) {
        if (arg is SetOrMapLiteral) {
          // Check if map has data-storage-like keys
          for (final element in arg.elements) {
            if (element is MapLiteralEntry) {
              final keySource = element.key.toSource().toLowerCase();
              final hasDataKey =
                  _dataTerms.any((term) => keySource.contains(term));

              if (hasDataKey) {
                reporter.atNode(arg, code);
                return;
              }
            }
          }

          // Also warn if map has more than 5 entries (too much data)
          if (arg.elements.length > 5) {
            reporter.atNode(arg, code);
          }
        }
      }
    });
  }
}

/// Warns when Firebase Auth on web doesn't set persistence to LOCAL.
///
/// By default, Firebase Auth on web uses session persistence, meaning users
/// are logged out when they close the browser tab. For "remember me"
/// functionality, you need to explicitly set persistence to LOCAL.
///
/// **Note:** This rule only applies to web applications.
///
/// **BAD:**
/// ```dart
/// // On web, user will be logged out when closing browser tab
/// await FirebaseAuth.instance.signInWithEmailAndPassword(
///   email: email,
///   password: password,
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// // Set persistence before sign-in for "remember me" on web
/// await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
/// await FirebaseAuth.instance.signInWithEmailAndPassword(
///   email: email,
///   password: password,
/// );
/// ```
class PreferFirebaseAuthPersistenceRule extends SaropaLintRule {
  const PreferFirebaseAuthPersistenceRule() : super(code: _code);

  /// Medium impact - affects user experience on web.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_firebase_auth_persistence',
    problemMessage:
        '[prefer_firebase_auth_persistence] Firebase Auth on web defaults to session persistence. Consider setting LOCAL persistence.',
    correctionMessage:
        'Call FirebaseAuth.instance.setPersistence(Persistence.LOCAL) before sign-in for "remember me".',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _signInMethods = <String>{
    'signInWithEmailAndPassword',
    'signInWithCredential',
    'signInWithPopup',
    'signInWithRedirect',
    'signInWithPhoneNumber',
    'signInAnonymously',
    'signInWithCustomToken',
    'createUserWithEmailAndPassword',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_signInMethods.contains(methodName)) return;

      // Check if this is a FirebaseAuth call
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (!targetSource.contains('FirebaseAuth') &&
          !targetSource.contains('firebaseAuth') &&
          !targetSource.contains('_auth')) {
        return;
      }

      // Check if there's a setPersistence call in the same function
      AstNode? functionBody;
      AstNode? current = node.parent;
      while (current != null) {
        if (current is FunctionBody) {
          functionBody = current;
          break;
        }
        if (current is MethodDeclaration ||
            current is FunctionDeclaration ||
            current is FunctionExpression) {
          break;
        }
        current = current.parent;
      }

      if (functionBody == null) return;

      // Look for setPersistence call before this sign-in
      final String functionSource = functionBody.toSource();
      if (functionSource.contains('setPersistence')) {
        return; // Already handles persistence
      }

      // Check if file has web check (kIsWeb) - only relevant for web
      final CompilationUnit? root = node.root as CompilationUnit?;
      if (root != null) {
        final String fullSource = root.toSource();
        // If there's platform checking, assume developer is aware
        if (fullSource.contains('kIsWeb') ||
            fullSource.contains('Platform.isWeb') ||
            fullSource.contains('defaultTargetPlatform')) {
          return;
        }
      }

      reporter.atNode(node.methodName, code);
    });
  }
}

// =============================================================================
// require_firebase_error_handling
// =============================================================================

/// Firebase calls can fail and should have error handling.
///
/// Firebase operations are network calls that can fail for many reasons:
/// - No network connection
/// - Permission denied
/// - Quota exceeded
/// - Invalid data
///
/// **BAD:**
/// ```dart
/// final doc = await FirebaseFirestore.instance.doc('users/123').get();
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   final doc = await FirebaseFirestore.instance.doc('users/123').get();
/// } on FirebaseException catch (e) {
///   // Handle error
/// }
/// ```
class RequireFirebaseErrorHandlingRule extends SaropaLintRule {
  const RequireFirebaseErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_firebase_error_handling',
    problemMessage:
        '[require_firebase_error_handling] Firebase operation without '
        'error handling. Firebase calls can fail.',
    correctionMessage:
        'Wrap in try-catch or add .catchError() to handle Firebase errors.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _firebaseClasses = <String>{
    'FirebaseFirestore',
    'FirebaseAuth',
    'FirebaseStorage',
    'FirebaseMessaging',
    'FirebaseAnalytics',
    'FirebaseCrashlytics',
    'FirebaseDatabase',
    'FirebaseFunctions',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAwaitExpression((AwaitExpression node) {
      final Expression expr = node.expression;
      if (expr is! MethodInvocation) return;

      // Check if this is a Firebase call
      if (!_isFirebaseCall(expr)) return;

      // Check if inside try-catch
      if (_isInsideTryCatch(node)) return;

      // Check if has .catchError
      if (_hasCatchError(expr)) return;

      reporter.atNode(node, code);
    });
  }

  bool _isFirebaseCall(MethodInvocation node) {
    final Expression? target = node.target;
    if (target == null) return false;

    final String targetSource = target.toSource();
    for (final String firebaseClass in _firebaseClasses) {
      if (targetSource.contains(firebaseClass)) {
        return true;
      }
    }
    return false;
  }

  bool _isInsideTryCatch(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is TryStatement) {
        return true;
      }
      if (current is FunctionBody ||
          current is MethodDeclaration ||
          current is FunctionDeclaration) {
        break;
      }
      current = current.parent;
    }
    return false;
  }

  bool _hasCatchError(MethodInvocation node) {
    // Check if the parent is a cascaded .catchError
    AstNode? parent = node.parent;
    while (parent != null) {
      if (parent is MethodInvocation) {
        if (parent.methodName.name == 'catchError' ||
            parent.methodName.name == 'onError') {
          return true;
        }
      }
      if (parent is! CascadeExpression && parent is! MethodInvocation) {
        break;
      }
      parent = parent.parent;
    }
    return false;
  }
}

// =============================================================================
// avoid_firebase_realtime_in_build
// =============================================================================

/// Don't create Firebase listeners in build method.
///
/// Creating stream listeners in build() causes multiple subscriptions
/// as build is called frequently. Cache stream references.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   return StreamBuilder(
///     stream: FirebaseFirestore.instance.collection('users').snapshots(),
///     // Creates new listener on every rebuild!
///   );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// late final Stream<QuerySnapshot> _usersStream;
///
/// void initState() {
///   super.initState();
///   _usersStream = FirebaseFirestore.instance.collection('users').snapshots();
/// }
///
/// Widget build(BuildContext context) {
///   return StreamBuilder(stream: _usersStream, ...);
/// }
/// ```
class AvoidFirebaseRealtimeInBuildRule extends SaropaLintRule {
  const AvoidFirebaseRealtimeInBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_firebase_realtime_in_build',
    problemMessage:
        '[avoid_firebase_realtime_in_build] Creating Firebase stream/listener '
        'in build causes multiple subscriptions.',
    correctionMessage:
        'Cache the stream reference in a field and initialize in initState.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _realtimeMethods = <String>{
    'snapshots',
    'onValue',
    'onChildAdded',
    'onChildChanged',
    'onChildRemoved',
    'onAuthStateChanged',
    'authStateChanges',
    'idTokenChanges',
    'userChanges',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_realtimeMethods.contains(methodName)) return;

      // Check if inside build method
      if (!_isInsideBuildMethod(node)) return;

      reporter.atNode(node, code);
    });
  }

  bool _isInsideBuildMethod(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration) {
        return current.name.lexeme == 'build';
      }
      current = current.parent;
    }
    return false;
  }
}

// =============================================================================
// require_firestore_index
// =============================================================================

/// Warns when compound Firestore query may need a composite index.
///
/// Alias: firestore_index, composite_index
///
/// Firestore compound queries (multiple where clauses or where + orderBy on
/// different fields) require composite indexes. Without an index, the query
/// fails at runtime with an error.
///
/// **BAD:**
/// ```dart
/// // This query needs a composite index
/// final query = FirebaseFirestore.instance
///     .collection('products')
///     .where('category', isEqualTo: 'electronics')
///     .where('price', isLessThan: 100)
///     .orderBy('rating', descending: true)
///     .get(); // Fails if index doesn't exist!
/// ```
///
/// **GOOD:**
/// ```dart
/// // Ensure composite index exists in firestore.indexes.json:
/// // { "collectionGroup": "products",
/// //   "queryScope": "COLLECTION",
/// //   "fields": [
/// //     { "fieldPath": "category", "order": "ASCENDING" },
/// //     { "fieldPath": "price", "order": "ASCENDING" },
/// //     { "fieldPath": "rating", "order": "DESCENDING" }
/// //   ]
/// // }
/// final query = FirebaseFirestore.instance
///     .collection('products')
///     .where('category', isEqualTo: 'electronics')
///     .where('price', isLessThan: 100)
///     .orderBy('rating', descending: true)
///     .get();
/// ```
class RequireFirestoreIndexRule extends SaropaLintRule {
  const RequireFirestoreIndexRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_firestore_index',
    problemMessage:
        '[require_firestore_index] Compound Firestore query may need a composite '
        'index. Query will fail at runtime without the required index.',
    correctionMessage:
        'Create a composite index in Firebase Console or firestore.indexes.json.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for get(), snapshots(), or getDocuments() on query
      if (methodName != 'get' &&
          methodName != 'snapshots' &&
          methodName != 'getDocuments') {
        return;
      }

      // Count where clauses and orderBy in the chain
      int whereCount = 0;
      int orderByCount = 0;
      final Set<String> whereFields = <String>{};
      final Set<String> orderByFields = <String>{};

      AstNode? current = node;
      while (current != null) {
        if (current is MethodInvocation) {
          final String method = current.methodName.name;

          if (method == 'where') {
            whereCount++;
            // Try to extract field name from first argument
            final NodeList<Expression> args = current.argumentList.arguments;
            if (args.isNotEmpty) {
              final String fieldArg = args.first.toSource();
              whereFields.add(fieldArg);
            }
          } else if (method == 'orderBy') {
            orderByCount++;
            final NodeList<Expression> args = current.argumentList.arguments;
            if (args.isNotEmpty) {
              final String fieldArg = args.first.toSource();
              orderByFields.add(fieldArg);
            }
          } else if (method == 'collection' ||
              method == 'collectionGroup' ||
              method == 'doc') {
            break; // Reached the start of the query
          }
        }
        current = current.parent;
      }

      // Check if composite index is likely needed:
      // 1. Multiple where clauses on different fields
      // 2. where + orderBy on different fields
      // 3. Range query (<, >, <=, >=) + orderBy on different field
      bool needsIndex = false;

      if (whereCount >= 2) {
        needsIndex = true;
      }

      if (whereCount >= 1 && orderByCount >= 1) {
        // Check if orderBy is on a field not in where
        for (final String orderField in orderByFields) {
          if (!whereFields.contains(orderField)) {
            needsIndex = true;
            break;
          }
        }
      }

      if (needsIndex) {
        reporter.atNode(node, code);
      }
    });
  }
}
