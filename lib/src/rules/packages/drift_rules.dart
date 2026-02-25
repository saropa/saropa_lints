// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Drift (SQLite) lint rules for Flutter applications.
///
/// These rules help ensure proper Drift database usage including type safety,
/// resource management, SQL injection prevention, migration correctness,
/// and performance best practices.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

// =============================================================================
// ESSENTIAL TIER
// =============================================================================

// =============================================================================
// avoid_drift_enum_index_reorder
// =============================================================================

/// Warns when Drift TypeConverter uses enum `.index` for int storage.
///
/// Since: v5.1.0 | Rule version: v1
///
/// Drift's `intEnum` column type and custom `TypeConverter<EnumType, int>`
/// classes that store enums by ordinal position are fragile. If enum values
/// are reordered or new values are inserted before existing ones, all
/// persisted data silently maps to wrong enum values. This is the most
/// dangerous database anti-pattern — data corruption without any error.
///
/// **BAD:**
/// ```dart
/// class PriorityConverter extends TypeConverter<Priority, int> {
///   @override
///   Priority fromSql(int fromDb) => Priority.values[fromDb];
///   @override
///   int toSql(Priority value) => value.index;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Store by name (immune to reordering)
/// class PriorityConverter extends TypeConverter<Priority, String> {
///   @override
///   Priority fromSql(String fromDb) =>
///     Priority.values.firstWhere((e) => e.name == fromDb);
///   @override
///   String toSql(Priority value) => value.name;
/// }
/// ```
class AvoidDriftEnumIndexReorderRule extends SaropaLintRule {
  AvoidDriftEnumIndexReorderRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_drift_enum_index_reorder',
    '[avoid_drift_enum_index_reorder] Drift TypeConverter uses enum ordinal '
        'index for int storage. If enum values are reordered or new values are '
        'inserted before existing ones, all persisted data silently maps to '
        'wrong enum values, causing data corruption without any error. {v1}',
    correctionMessage:
        'Store enums by name (String) or by an explicit code property '
        'instead of .index. Use textEnum<T>() or a custom String-based '
        'TypeConverter.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Detect .index usage in TypeConverter<Enum, int> toSql methods
    context.addPropertyAccess((PropertyAccess node) {
      if (node.propertyName.name != 'index') return;
      if (!fileImportsPackage(node, PackageImports.drift)) return;

      // Check if inside a method named toSql
      AstNode? current = node.parent;
      while (current != null) {
        if (current is MethodDeclaration && current.name.lexeme == 'toSql') {
          // Check if the class extends TypeConverter
          final classDecl = _findEnclosingClass(current);
          if (classDecl != null && _extendsTypeConverter(classDecl)) {
            reporter.atNode(node);
          }
          return;
        }
        current = current.parent;
      }
    });

    // Detect EnumType.values[index] in fromSql methods
    context.addIndexExpression((IndexExpression node) {
      if (!fileImportsPackage(node, PackageImports.drift)) return;
      final target = node.target;
      if (target is! PrefixedIdentifier) return;
      if (target.identifier.name != 'values') return;

      // Check if inside fromSql method
      AstNode? current = node.parent;
      while (current != null) {
        if (current is MethodDeclaration && current.name.lexeme == 'fromSql') {
          final classDecl = _findEnclosingClass(current);
          if (classDecl != null && _extendsTypeConverter(classDecl)) {
            reporter.atNode(node);
          }
          return;
        }
        current = current.parent;
      }
    });

    // Detect intEnum<T>() column builder calls
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'intEnum') return;
      if (!fileImportsPackage(node, PackageImports.drift)) return;
      reporter.atNode(node);
    });
  }
}

ClassDeclaration? _findEnclosingClass(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is ClassDeclaration) return current;
    current = current.parent;
  }
  return null;
}

bool _extendsTypeConverter(ClassDeclaration classDecl) {
  final superclass = classDecl.extendsClause?.superclass;
  if (superclass == null) return false;
  final name = superclass.name.lexeme;
  return name == 'TypeConverter' || name == 'NullAwareTypeConverter';
}

// =============================================================================
// RECOMMENDED TIER
// =============================================================================

// =============================================================================
// require_drift_database_close
// =============================================================================

/// Warns when a Drift database field is not closed in dispose().
///
/// Since: v5.1.0 | Rule version: v1
///
/// Drift database instances hold file handles, isolate connections, and
/// stream query tracking. Not calling `.close()` causes resource leaks,
/// prevents database reopening, and can corrupt data if the process exits
/// during a write. Classes with dispose() methods that hold database fields
/// must close them.
///
/// **BAD:**
/// ```dart
/// class MyController {
///   final AppDatabase db;
///   void dispose() {
///     // Missing db.close()!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyController {
///   final AppDatabase db;
///   void dispose() {
///     db.close();
///   }
/// }
/// ```
class RequireDriftDatabaseCloseRule extends SaropaLintRule {
  RequireDriftDatabaseCloseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_drift_database_close',
    '[require_drift_database_close] Drift database field is not closed in '
        'dispose(). Database instances hold file handles, isolate connections, '
        'and stream tracking. Not calling .close() causes resource leaks, '
        'prevents database reopening, and can corrupt data on exit. {v1}',
    correctionMessage:
        'Call db.close() in your dispose() method to release all resources.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      if (!fileImportsPackage(node, PackageImports.drift)) return;

      // Find database fields (type name ending with Database or containing db)
      final dbFields = <String>[];
      for (final member in node.members) {
        if (member is FieldDeclaration) {
          final typeAnnotation = member.fields.type;
          if (typeAnnotation is NamedType) {
            final typeName = typeAnnotation.name.lexeme;
            if (typeName.endsWith('Database') ||
                typeName == 'GeneratedDatabase') {
              for (final variable in member.fields.variables) {
                dbFields.add(variable.name.lexeme);
              }
            }
          }
        }
      }

      if (dbFields.isEmpty) return;

      // Find dispose method
      MethodDeclaration? disposeMethod;
      for (final member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeMethod = member;
          break;
        }
      }

      if (disposeMethod == null) return;

      // Check if dispose body calls .close() on each db field
      final bodySource = disposeMethod.body.toSource();
      for (final field in dbFields) {
        if (!bodySource.contains('$field.close()') &&
            !bodySource.contains('$field?.close()')) {
          reporter.atNode(disposeMethod);
          return;
        }
      }
    });
  }
}

// =============================================================================
// avoid_drift_update_without_where
// =============================================================================

/// Warns when Drift update() or delete() is used without a where() clause.
///
/// Since: v5.1.0 | Rule version: v1
///
/// Calling `update(table).write(companion)` or `delete(table).go()` without
/// a `.where()` clause affects ALL rows in the table. This is almost always
/// unintentional and can cause catastrophic data loss. Drift's documentation
/// explicitly warns about this pitfall.
///
/// **BAD:**
/// ```dart
/// await update(todoItems).write(companion); // Updates ALL rows!
/// await delete(todoItems).go(); // Deletes ALL rows!
/// ```
///
/// **GOOD:**
/// ```dart
/// await (update(todoItems)..where((t) => t.id.equals(id))).write(companion);
/// await (delete(todoItems)..where((t) => t.id.equals(id))).go();
/// ```
class AvoidDriftUpdateWithoutWhereRule extends SaropaLintRule {
  AvoidDriftUpdateWithoutWhereRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_drift_update_without_where',
    '[avoid_drift_update_without_where] Drift update() or delete() called '
        'without a where() clause. This affects ALL rows in the table, '
        'which is almost always unintentional and can cause catastrophic '
        'data loss. Always add a where() clause to scope your operation. {v1}',
    correctionMessage:
        'Add a where() clause: (update(table)..where((t) => t.id.equals(id)))'
        '.write(companion)',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final methodName = node.methodName.name;
      // Check for terminal methods: write() for update, go() for delete
      if (methodName != 'write' && methodName != 'go') return;
      if (!fileImportsPackage(node, PackageImports.drift)) return;

      // Walk the expression chain to find the originating update/delete call
      final chainSource = _getFullChainSource(node);
      if (chainSource == null) return;

      // Check if chain starts with update() or delete()
      final hasUpdate = RegExp(r'\bupdate\s*\(').hasMatch(chainSource);
      final hasDelete = RegExp(r'\bdelete\s*\(').hasMatch(chainSource);
      if (!hasUpdate && !hasDelete) return;

      // Check if where() appears in the chain
      if (RegExp(r'\.where\s*\(').hasMatch(chainSource)) return;
      if (chainSource.contains('..where(')) return;

      // replace() is intentional single-row operation, don't flag
      if (methodName == 'write' && hasDelete) return;

      reporter.atNode(node.methodName);
    });
  }
}

String? _getFullChainSource(AstNode node) {
  // Walk up to find the full expression statement
  AstNode? current = node;
  while (current != null) {
    if (current is ExpressionStatement) return current.toSource();
    if (current is AwaitExpression) return current.toSource();
    if (current is ParenthesizedExpression) return current.toSource();
    if (current is CascadeExpression) return current.toSource();
    current = current.parent;
  }
  return node.toSource();
}

// =============================================================================
// require_await_in_drift_transaction
// =============================================================================

/// Warns when queries inside a Drift transaction callback are not awaited.
///
/// Since: v5.1.0 | Rule version: v1
///
/// Inside `transaction(() async { ... })`, all database queries must be
/// awaited. The transaction commits when the callback returns. Unawaited
/// futures execute outside the transaction boundary, losing atomicity
/// guarantees and potentially causing data inconsistency.
///
/// **BAD:**
/// ```dart
/// await transaction(() async {
///   into(todoItems).insert(companion); // NOT awaited!
///   update(categories).write(companion2); // NOT awaited!
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// await transaction(() async {
///   await into(todoItems).insert(companion);
///   await (update(categories)..where((c) => c.id.equals(id)))
///     .write(companion2);
/// });
/// ```
class RequireAwaitInDriftTransactionRule extends SaropaLintRule {
  RequireAwaitInDriftTransactionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_await_in_drift_transaction',
    '[require_await_in_drift_transaction] Database query inside a Drift '
        'transaction() callback is not awaited. The transaction commits when '
        'the callback returns — unawaited futures execute outside the '
        'transaction boundary, losing atomicity and causing data '
        'inconsistency. {v1}',
    correctionMessage:
        'Add await before database operations inside '
        'transaction callbacks.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Drift query terminal methods that return futures.
  static const Set<String> _queryMethods = <String>{
    'insert',
    'insertOnConflictUpdate',
    'write',
    'go',
    'get',
    'getSingle',
    'getSingleOrNull',
    'customSelect',
    'customUpdate',
    'customStatement',
    'customInsert',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'transaction') return;
      if (!fileImportsPackage(node, PackageImports.drift)) return;

      final args = node.argumentList.arguments;
      if (args.isEmpty) return;

      // Get the callback function
      final callback = args.first;
      FunctionBody? body;
      if (callback is FunctionExpression) {
        body = callback.body;
      }
      if (body == null) return;

      // Walk the callback body for expression statements
      _checkBlockForUnawaitedQueries(body, reporter);
    });
  }

  void _checkBlockForUnawaitedQueries(
    AstNode body,
    SaropaDiagnosticReporter reporter,
  ) {
    for (final child in body.childEntities) {
      if (child is ExpressionStatement) {
        final expr = child.expression;
        // If it's not an await expression, check if it's a query method
        if (expr is! AwaitExpression) {
          if (_containsQueryMethod(expr)) {
            reporter.atNode(child);
          }
        }
      } else if (child is Block) {
        _checkBlockForUnawaitedQueries(child, reporter);
      }
    }
  }

  bool _containsQueryMethod(Expression expr) {
    if (expr is MethodInvocation) {
      if (_queryMethods.contains(expr.methodName.name)) return true;
      final target = expr.target;
      if (target is Expression) return _containsQueryMethod(target);
    }
    if (expr is CascadeExpression) {
      for (final section in expr.cascadeSections) {
        if (section is MethodInvocation) {
          if (_queryMethods.contains(section.methodName.name)) return true;
        }
      }
    }
    return false;
  }
}

// =============================================================================
// require_drift_foreign_key_pragma
// =============================================================================

/// Warns when a Drift database class lacks PRAGMA foreign_keys = ON.
///
/// Since: v5.1.0 | Rule version: v1
///
/// SQLite does NOT enforce foreign keys by default. Without setting
/// `PRAGMA foreign_keys = ON` in the `beforeOpen` callback of
/// MigrationStrategy, all foreign key constraints declared in table
/// definitions are silently ignored. This must be set in beforeOpen,
/// not inside onCreate or onUpgrade (which run inside transactions).
///
/// **BAD:**
/// ```dart
/// class AppDatabase extends _$AppDatabase {
///   @override
///   int get schemaVersion => 1;
///   // No migration strategy or no beforeOpen callback!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class AppDatabase extends _$AppDatabase {
///   @override
///   int get schemaVersion => 1;
///   @override
///   MigrationStrategy get migration => MigrationStrategy(
///     beforeOpen: (details) async {
///       await customStatement('PRAGMA foreign_keys = ON');
///     },
///   );
/// }
/// ```
class RequireDriftForeignKeyPragmaRule extends SaropaLintRule {
  RequireDriftForeignKeyPragmaRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_drift_foreign_key_pragma',
    '[require_drift_foreign_key_pragma] Drift database class does not set '
        'PRAGMA foreign_keys = ON in beforeOpen callback. SQLite does NOT '
        'enforce foreign keys by default — all foreign key constraints in '
        'table definitions are silently ignored without this pragma. {v1}',
    correctionMessage:
        'Add a MigrationStrategy with beforeOpen callback '
        'that runs: await customStatement(\'PRAGMA foreign_keys = ON\');',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if class extends _$Something (Drift generated superclass)
      final superclass = node.extendsClause?.superclass;
      if (superclass == null) return;
      final superName = superclass.name.lexeme;
      if (!superName.startsWith(r'_$')) return;
      if (!fileImportsPackage(node, PackageImports.drift)) return;

      // Check the full class source for foreign_keys pragma
      final classSource = node.toSource();
      if (classSource.contains('foreign_keys')) return;

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// avoid_drift_raw_sql_interpolation
// =============================================================================

/// Warns when raw SQL methods use string interpolation or concatenation.
///
/// Since: v5.1.0 | Rule version: v1
///
/// **OWASP:** A03:2021-Injection
///
/// Drift's typed API is inherently safe, but `customSelect`,
/// `customStatement`, and `customUpdate` accept raw SQL strings. Using
/// string interpolation or concatenation in these methods creates SQL
/// injection vulnerabilities. Always use parameterized queries via the
/// `variables` parameter with Variable.withInt(), Variable.withString().
///
/// **BAD:**
/// ```dart
/// customSelect('SELECT * FROM users WHERE id = $id');
/// customStatement('DROP TABLE $tableName');
/// ```
///
/// **GOOD:**
/// ```dart
/// customSelect('SELECT * FROM users WHERE id = ?',
///   variables: [Variable.withInt(id)]);
/// ```
class AvoidDriftRawSqlInterpolationRule extends SaropaLintRule {
  AvoidDriftRawSqlInterpolationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  OwaspMapping? get owasp => const OwaspMapping(web: <OwaspWeb>{OwaspWeb.a03});

  static const LintCode _code = LintCode(
    'avoid_drift_raw_sql_interpolation',
    '[avoid_drift_raw_sql_interpolation] String interpolation or '
        'concatenation detected in Drift raw SQL method. This creates a SQL '
        'injection vulnerability (OWASP A03:2021-Injection). Attackers can '
        'execute arbitrary SQL including data exfiltration and deletion. {v1}',
    correctionMessage:
        'Use parameterized queries with the variables '
        'parameter: customSelect(\'SELECT * FROM t WHERE id = ?\', '
        'variables: [Variable.withInt(id)])',
    severity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _rawSqlMethods = <String>{
    'customSelect',
    'customStatement',
    'customUpdate',
    'customInsert',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_rawSqlMethods.contains(node.methodName.name)) return;

      final args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final firstArg = args.first;

      // Check for string interpolation
      if (firstArg is StringInterpolation) {
        reporter.atNode(firstArg);
        return;
      }

      // Check for string concatenation with +
      if (firstArg is BinaryExpression && firstArg.operator.lexeme == '+') {
        reporter.atNode(firstArg);
      }
    });
  }
}

// =============================================================================
// prefer_drift_batch_operations
// =============================================================================

/// Warns when individual Drift inserts are called in a loop.
///
/// Since: v5.1.0 | Rule version: v1
///
/// Individual `into(table).insert()` calls in a loop are dramatically
/// slower than `batch((b) { b.insertAll(table, companions); })`. Batches
/// prepare SQL statements once and reuse them, providing 10-100x speedup
/// for large datasets. This is critical for any bulk data operation.
///
/// **BAD:**
/// ```dart
/// for (final item in items) {
///   await into(todoItems).insert(item);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// await batch((b) {
///   b.insertAll(todoItems, items);
/// });
/// ```
class PreferDriftBatchOperationsRule extends SaropaLintRule {
  PreferDriftBatchOperationsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_drift_batch_operations',
    '[prefer_drift_batch_operations] Individual Drift insert() or write() '
        'call detected inside a loop. This is dramatically slower than using '
        'batch((b) { b.insertAll(...); }). Batches prepare SQL once and '
        'reuse it, providing 10-100x speedup for large datasets. {v1}',
    correctionMessage:
        'Use batch operations: await batch((b) { '
        'b.insertAll(table, companions); });',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _insertMethods = <String>{
    'insert',
    'insertOnConflictUpdate',
    'write',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_insertMethods.contains(node.methodName.name)) return;
      if (!fileImportsPackage(node, PackageImports.drift)) return;

      // Check if inside a loop
      if (_isInsideLoop(node)) {
        reporter.atNode(node.methodName);
      }
    });
  }
}

bool _isInsideLoop(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is ForStatement ||
        current is WhileStatement ||
        current is DoStatement) {
      return true;
    }
    // Don't go above function boundaries, but check for forEach first
    if (current is FunctionExpression || current is MethodDeclaration) {
      // Check if this function is a forEach callback
      final parent = current.parent;
      if (parent is ArgumentList) {
        final grandparent = parent.parent;
        if (grandparent is MethodInvocation &&
            grandparent.methodName.name == 'forEach') {
          return true;
        }
      }
      return false;
    }
    current = current.parent;
  }
  return false;
}

// =============================================================================
// require_drift_stream_cancel
// =============================================================================

/// Warns when a Drift .watch() stream subscription is not cancelled.
///
/// Since: v5.1.0 | Rule version: v1
///
/// Drift stream queries are tracked internally. Subscriptions from
/// `.watch()`, `.watchSingle()`, or `.watchSingleOrNull()` that are not
/// cancelled cause memory leaks and re-execute on every table change.
/// Always store the subscription and cancel it in dispose().
///
/// **BAD:**
/// ```dart
/// class MyWidget extends State<MyPage> {
///   void initState() {
///     super.initState();
///     db.select(items).watch().listen((data) { setState(() {}); });
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyWidget extends State<MyPage> {
///   StreamSubscription? _sub;
///   void initState() {
///     super.initState();
///     _sub = db.select(items).watch().listen((data) { setState(() {}); });
///   }
///   void dispose() {
///     _sub?.cancel();
///     super.dispose();
///   }
/// }
/// ```
class RequireDriftStreamCancelRule extends SaropaLintRule {
  RequireDriftStreamCancelRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_drift_stream_cancel',
    '[require_drift_stream_cancel] Drift .watch() stream subscription is '
        'created but may not be cancelled in dispose(). Uncancelled '
        'subscriptions cause memory leaks and re-execute the query on every '
        'table change, wasting CPU and memory. Always store and cancel '
        'subscriptions. {v1}',
    correctionMessage:
        'Store the subscription in a field and call '
        '.cancel() on it in dispose().',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _watchMethods = <String>{
    'watch',
    'watchSingle',
    'watchSingleOrNull',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'listen') return;
      if (!fileImportsPackage(node, PackageImports.drift)) return;

      // Check if target chain contains .watch()
      final target = node.target;
      if (target == null) return;
      final targetSource = target.toSource();
      final hasWatch = _watchMethods.any((m) => targetSource.contains('.$m()'));
      if (!hasWatch) return;

      // Check if result is assigned to a field
      final parent = node.parent;
      if (parent is AssignmentExpression || parent is VariableDeclaration) {
        // Assigned — good practice, assume developer will cancel
        return;
      }

      // Not assigned — the subscription is lost, can never be cancelled
      reporter.atNode(node.methodName);
    });
  }
}

// =============================================================================
// PROFESSIONAL TIER
// =============================================================================

// =============================================================================
// avoid_drift_database_on_main_isolate
// =============================================================================

/// Warns when NativeDatabase is created without background isolate support.
///
/// Since: v5.1.0 | Rule version: v1
///
/// SQLite runs statements synchronously, blocking the current isolate.
/// On mobile, creating a `NativeDatabase` on the main isolate causes UI
/// jank and dropped frames. Use `NativeDatabase.createInBackground()`,
/// `DriftIsolate`, or `driftDatabase()` from drift_flutter which handles
/// platform selection automatically.
///
/// **BAD:**
/// ```dart
/// final db = AppDatabase(NativeDatabase(file));
/// ```
///
/// **GOOD:**
/// ```dart
/// final db = AppDatabase(NativeDatabase.createInBackground(file));
/// // Or use drift_flutter:
/// final db = AppDatabase(driftDatabase(name: 'app'));
/// ```
class AvoidDriftDatabaseOnMainIsolateRule extends SaropaLintRule {
  AvoidDriftDatabaseOnMainIsolateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_drift_database_on_main_isolate',
    '[avoid_drift_database_on_main_isolate] NativeDatabase created without '
        'background isolate support. SQLite blocks the current isolate — on '
        'mobile this causes UI jank and dropped frames. Use '
        'NativeDatabase.createInBackground() or driftDatabase() from '
        'drift_flutter for automatic platform handling. {v1}',
    correctionMessage:
        'Use NativeDatabase.createInBackground(file) or '
        'driftDatabase(name: \'app\') from the drift_flutter package.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final constructorName = node.constructorName;
      final typeName = constructorName.type.name.lexeme;
      if (typeName != 'NativeDatabase') return;

      // Skip NativeDatabase.memory() (used for testing)
      final name = constructorName.name;
      if (name != null) {
        final methodName = name.name;
        if (methodName == 'createInBackground' ||
            methodName == 'createBackgroundConnection' ||
            methodName == 'memory') {
          return;
        }
      }

      // Skip test files
      if (_isInTestFile(node)) return;

      reporter.atNode(node);
    });
  }
}

bool _isInTestFile(AstNode node) {
  // Walk up to CompilationUnit and check directives for test imports
  AstNode? current = node;
  while (current != null && current is! CompilationUnit) {
    current = current.parent;
  }
  if (current is! CompilationUnit) return false;
  for (final directive in current.directives) {
    if (directive is ImportDirective) {
      final uri = directive.uri.stringValue ?? '';
      if (uri.startsWith('package:test/') ||
          uri.startsWith('package:flutter_test/')) {
        return true;
      }
    }
  }
  return false;
}

// =============================================================================
// avoid_drift_log_statements_production
// =============================================================================

/// Warns when logStatements is set to true without a debug mode guard.
///
/// Since: v5.1.0 | Rule version: v1
///
/// Setting `logStatements: true` on NativeDatabase or WasmDatabase prints
/// ALL SQL statements including data values to the console. This leaks
/// sensitive user data (emails, passwords, personal information) in
/// production logs. Always guard with kDebugMode or disable entirely.
///
/// **BAD:**
/// ```dart
/// NativeDatabase(file, logStatements: true);
/// ```
///
/// **GOOD:**
/// ```dart
/// NativeDatabase(file, logStatements: kDebugMode);
/// ```
class AvoidDriftLogStatementsProductionRule extends SaropaLintRule {
  AvoidDriftLogStatementsProductionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_drift_log_statements_production',
    '[avoid_drift_log_statements_production] logStatements is set to true '
        'without a debug mode guard. This prints ALL SQL including data '
        'values to the console, leaking sensitive user data (emails, '
        'passwords, personal info) in production logs. Always guard with '
        'kDebugMode or disable entirely. {v1}',
    correctionMessage:
        'Use logStatements: kDebugMode to only log in debug builds, '
        'or remove logStatements entirely.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addNamedExpression((NamedExpression node) {
      if (node.name.label.name != 'logStatements') return;
      if (!fileImportsPackage(node, PackageImports.drift)) return;

      final value = node.expression;
      // Only flag if value is literal true
      if (value is BooleanLiteral && value.value) {
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// avoid_drift_get_single_without_unique
// =============================================================================

/// Warns when getSingle/watchSingle is used without a where() clause.
///
/// Since: v5.1.0 | Rule version: v1
///
/// `getSingle()` and `watchSingle()` throw a `StateError` if the query
/// returns zero or more than one row. Using these without a `.where()`
/// clause that filters to a unique row (e.g., by primary key) will crash
/// at runtime whenever the table has != 1 row. Use `.get()` or
/// `.getSingleOrNull()` for safer alternatives.
///
/// **BAD:**
/// ```dart
/// final user = await select(users).getSingle();
/// ```
///
/// **GOOD:**
/// ```dart
/// final user = await (select(users)
///   ..where((u) => u.id.equals(id))).getSingle();
/// ```
class AvoidDriftGetSingleWithoutUniqueRule extends SaropaLintRule {
  AvoidDriftGetSingleWithoutUniqueRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_drift_get_single_without_unique',
    '[avoid_drift_get_single_without_unique] getSingle() or watchSingle() '
        'called without a where() clause. These methods throw StateError if '
        'the query returns zero or more than one row. Without filtering to '
        'a unique row, this will crash at runtime when the table has != 1 '
        'row. {v1}',
    correctionMessage:
        'Add a where() clause filtering by primary key or '
        'unique column, or use getSingleOrNull() / get() instead.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _singleMethods = <String>{
    'getSingle',
    'watchSingle',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_singleMethods.contains(node.methodName.name)) return;
      if (!fileImportsPackage(node, PackageImports.drift)) return;

      // Check the full expression chain for where()
      final chainSource = _getFullChainSource(node);
      if (chainSource == null) return;

      if (RegExp(r'\.where\s*\(').hasMatch(chainSource)) return;
      if (chainSource.contains('..where(')) return;

      reporter.atNode(node.methodName);
    });
  }
}

// =============================================================================
// prefer_drift_use_columns_false
// =============================================================================

/// Suggests using useColumns: false for join tables not read in results.
///
/// Since: v5.1.0 | Rule version: v1
///
/// When joining tables, Drift reads all columns from all joined tables by
/// default. If a table is only joined for filtering or aggregation but its
/// columns are not needed in the result, setting `useColumns: false` avoids
/// unnecessary column reading overhead and improves query performance.
///
/// **BAD:**
/// ```dart
/// select(items).join([
///   leftOuterJoin(categories, categories.id.equalsExp(items.category)),
/// ]);
/// ```
///
/// **GOOD:**
/// ```dart
/// select(items).join([
///   leftOuterJoin(categories, categories.id.equalsExp(items.category),
///     useColumns: false),
/// ]);
/// ```
class PreferDriftUseColumnsFalseRule extends SaropaLintRule {
  PreferDriftUseColumnsFalseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_drift_use_columns_false',
    '[prefer_drift_use_columns_false] Drift join without useColumns '
        'parameter. When a joined table is only used for filtering or '
        'aggregation, setting useColumns: false avoids reading unnecessary '
        'columns and improves query performance. Consider whether joined '
        'table columns are actually needed. {v1}',
    correctionMessage:
        'Add useColumns: false to join calls where joined '
        'table columns are not needed in the result.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _joinMethods = <String>{
    'innerJoin',
    'leftOuterJoin',
    'crossJoin',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_joinMethods.contains(node.methodName.name)) return;
      if (!fileImportsPackage(node, PackageImports.drift)) return;

      // Check if useColumns parameter is already set
      final args = node.argumentList.arguments;
      for (final arg in args) {
        if (arg is NamedExpression && arg.name.label.name == 'useColumns') {
          return;
        }
      }

      reporter.atNode(node.methodName);
    });
  }
}

// =============================================================================
// avoid_drift_lazy_database
// =============================================================================

/// Warns when LazyDatabase is used with isolate-based patterns.
///
/// Since: v5.1.0 | Rule version: v1
///
/// `LazyDatabase` loses stream synchronization when used with Drift
/// isolates. Stream queries may not update when data changes across
/// isolates because the lazy wrapper doesn't participate in the isolate
/// communication protocol. Use `DatabaseConnection.delayed()` instead,
/// which properly integrates with Drift's stream system.
///
/// **BAD:**
/// ```dart
/// LazyDatabase(() async {
///   final isolate = await DriftIsolate.spawn(createDb);
///   return isolate.connect();
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// DatabaseConnection.delayed(Future(() async {
///   final isolate = await DriftIsolate.spawn(createDb);
///   return isolate.connect();
/// }));
/// ```
class AvoidDriftLazyDatabaseRule extends SaropaLintRule {
  AvoidDriftLazyDatabaseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_drift_lazy_database',
    '[avoid_drift_lazy_database] LazyDatabase used with isolate-based '
        'pattern. LazyDatabase loses stream synchronization with Drift '
        'isolates — stream queries may not update when data changes across '
        'isolates. Use DatabaseConnection.delayed() instead, which properly '
        'integrates with the stream system. {v1}',
    correctionMessage:
        'Replace LazyDatabase with '
        'DatabaseConnection.delayed(Future(() async { ... })).',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'LazyDatabase') return;

      // Check if callback body references isolate patterns
      final args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final callback = args.first;
      final source = callback.toSource();
      if (source.contains('DriftIsolate') ||
          source.contains('Isolate') ||
          source.contains('compute')) {
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// prefer_drift_isolate_sharing
// =============================================================================

/// Warns when multiple NativeDatabase instances may use the same file.
///
/// Since: v5.1.0 | Rule version: v1
///
/// Opening multiple independent Drift database instances on the same file
/// breaks stream synchronization. Streams only update when changes go
/// through the same database instance. Use a singleton pattern,
/// drift_flutter with shareAcrossIsolates: true, or DriftIsolate for
/// proper multi-isolate support.
///
/// **BAD:**
/// ```dart
/// // In different parts of the app:
/// final db1 = AppDatabase(NativeDatabase(File('app.db')));
/// final db2 = AppDatabase(NativeDatabase(File('app.db')));
/// ```
///
/// **GOOD:**
/// ```dart
/// // Singleton pattern
/// static AppDatabase? _instance;
/// static AppDatabase get instance =>
///   _instance ??= AppDatabase(NativeDatabase.createInBackground(file));
/// ```
class PreferDriftIsolateSharingRule extends SaropaLintRule {
  PreferDriftIsolateSharingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_drift_isolate_sharing',
    '[prefer_drift_isolate_sharing] Multiple NativeDatabase instances may '
        'use the same database file, breaking stream synchronization. '
        'Streams only update when changes go through the same instance. '
        'Use a singleton pattern, drift_flutter shareAcrossIsolates, or '
        'DriftIsolate for proper multi-isolate support. {v1}',
    correctionMessage:
        'Use a singleton pattern or drift_flutter with '
        'shareAcrossIsolates: true.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Track NativeDatabase creation paths within the compilation unit
    final dbPaths = <String, InstanceCreationExpression>{};

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'NativeDatabase') return;

      final args = node.argumentList.arguments;
      if (args.isEmpty) return;

      // Extract the file path argument source
      final pathArg = args.first.toSource();

      if (dbPaths.containsKey(pathArg)) {
        // Second instance with same path — flag both
        final first = dbPaths[pathArg]!;
        reporter.atNode(first);
        reporter.atNode(node);
      } else {
        dbPaths[pathArg] = node;
      }
    });
  }
}

// =============================================================================
// COMPREHENSIVE TIER
// =============================================================================

// =============================================================================
// avoid_drift_query_in_migration
// =============================================================================

/// Warns when high-level Drift query APIs are used in migration callbacks.
///
/// Since: v5.1.0 | Rule version: v1
///
/// Inside `onUpgrade` and `onCreate` callbacks of MigrationStrategy,
/// high-level query APIs like `select()`, `update()`, `delete()`, and
/// `into()` must NOT be used. These APIs use generated code expecting the
/// LATEST schema, but during migration the database is still on the OLD
/// schema. This causes runtime crashes. Use raw SQL via
/// `customStatement()` or `migrator` methods instead.
///
/// **BAD:**
/// ```dart
/// MigrationStrategy(
///   onUpgrade: (m, from, to) async {
///     final users = await select(usersTable).get(); // WRONG!
///   },
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// MigrationStrategy(
///   onUpgrade: (m, from, to) async {
///     await m.addColumn(users, users.email);
///     await customStatement('UPDATE users SET email = ""');
///   },
/// );
/// ```
class AvoidDriftQueryInMigrationRule extends SaropaLintRule {
  AvoidDriftQueryInMigrationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_drift_query_in_migration',
    '[avoid_drift_query_in_migration] High-level Drift query API used '
        'inside migration callback. Generated query APIs expect the LATEST '
        'schema, but during migration the database is on the OLD schema. '
        'This causes runtime crashes. Use raw SQL via customStatement() '
        'or migrator methods instead. {v1}',
    correctionMessage:
        'Replace select/update/delete/into calls with '
        'customStatement() or migrator.addColumn() in migration callbacks.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _queryApis = <String>{
    'select',
    'update',
    'delete',
    'into',
  };

  static const Set<String> _migrationCallbacks = <String>{
    'onUpgrade',
    'onCreate',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_queryApis.contains(node.methodName.name)) return;
      if (!fileImportsPackage(node, PackageImports.drift)) return;

      // Check if inside a migration callback
      if (_isInsideMigrationCallback(node)) {
        reporter.atNode(node.methodName);
      }
    });
  }

  bool _isInsideMigrationCallback(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is NamedExpression) {
        final label = current.name.label.name;
        if (_migrationCallbacks.contains(label)) return true;
      }
      // Stop at class boundary
      if (current is ClassDeclaration) return false;
      current = current.parent;
    }
    return false;
  }
}

// =============================================================================
// require_drift_schema_version_bump
// =============================================================================

/// Warns when schemaVersion is 1 in a database with many tables.
///
/// Since: v5.1.0 | Rule version: v1
///
/// When a Drift database has multiple tables, a `schemaVersion` of 1
/// suggests the schema has never been migrated. If the schema has changed
/// since initial release without bumping the version, the `onUpgrade`
/// callback won't trigger and users will encounter runtime crashes from
/// schema mismatches. This is a heuristic check — it may be correct for
/// new projects.
///
/// **BAD:**
/// ```dart
/// @DriftDatabase(tables: [Users, Posts, Comments, Likes])
/// class AppDatabase extends _$AppDatabase {
///   @override
///   int get schemaVersion => 1; // 4 tables, still version 1?
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @DriftDatabase(tables: [Users, Posts, Comments, Likes])
/// class AppDatabase extends _$AppDatabase {
///   @override
///   int get schemaVersion => 3; // Bumped with each schema change
/// }
/// ```
class RequireDriftSchemaVersionBumpRule extends SaropaLintRule {
  RequireDriftSchemaVersionBumpRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'require_drift_schema_version_bump',
    '[require_drift_schema_version_bump] Drift database schemaVersion is 1 '
        'but the database has multiple tables. If the schema has changed '
        'since initial release without bumping the version, onUpgrade will '
        'not trigger, causing runtime crashes from schema mismatches. '
        'Consider bumping schemaVersion after schema changes. {v1}',
    correctionMessage:
        'Bump schemaVersion when you add, remove, or modify '
        'tables or columns. Add migration logic in onUpgrade.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check for _$ prefix superclass (Drift database pattern)
      final superclass = node.extendsClause?.superclass;
      if (superclass == null) return;
      if (!superclass.name.lexeme.startsWith(r'_$')) return;
      if (!fileImportsPackage(node, PackageImports.drift)) return;

      // Check @DriftDatabase annotation for table count
      int tableCount = 0;
      for (final annotation in node.metadata) {
        final name = annotation.name.name;
        if (name == 'DriftDatabase') {
          final source = annotation.toSource();
          // Count commas in tables list as heuristic for table count
          final tablesMatch = RegExp(
            r'tables:\s*\[([^\]]*)\]',
          ).firstMatch(source);
          if (tablesMatch != null) {
            final tablesContent = tablesMatch.group(1) ?? '';
            tableCount = tablesContent.split(',').length;
          }
        }
      }

      if (tableCount < 3) return; // Only flag with 3+ tables

      // Find schemaVersion getter
      for (final member in node.members) {
        if (member is MethodDeclaration &&
            member.name.lexeme == 'schemaVersion' &&
            member.isGetter) {
          final bodySource = member.body.toSource();
          if (bodySource.contains('=> 1;') || bodySource.contains('=> 1 ;')) {
            reporter.atNode(member);
          }
          return;
        }
      }
    });
  }
}

// =============================================================================
// avoid_drift_foreign_key_in_migration
// =============================================================================

/// Warns when PRAGMA foreign_keys is set inside a migration callback.
///
/// Since: v5.1.0 | Rule version: v1
///
/// Setting `PRAGMA foreign_keys` inside `onCreate` or `onUpgrade`
/// callbacks silently fails because these callbacks run inside
/// transactions, and SQLite PRAGMAs cannot be changed inside
/// transactions. The pragma must be set in the `beforeOpen` callback
/// which runs after the migration transaction completes.
///
/// **BAD:**
/// ```dart
/// MigrationStrategy(
///   onCreate: (m) async {
///     await customStatement('PRAGMA foreign_keys = ON'); // Silently fails!
///   },
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// MigrationStrategy(
///   beforeOpen: (details) async {
///     await customStatement('PRAGMA foreign_keys = ON');
///   },
/// );
/// ```
class AvoidDriftForeignKeyInMigrationRule extends SaropaLintRule {
  AvoidDriftForeignKeyInMigrationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_drift_foreign_key_in_migration',
    '[avoid_drift_foreign_key_in_migration] PRAGMA foreign_keys set inside '
        'an onCreate or onUpgrade callback. These callbacks run inside '
        'transactions, and SQLite PRAGMAs cannot be changed inside '
        'transactions — this silently fails. Set the pragma in the '
        'beforeOpen callback instead. {v1}',
    correctionMessage:
        'Move the PRAGMA foreign_keys statement to the '
        'beforeOpen callback of MigrationStrategy.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _migrationCallbacks = <String>{
    'onCreate',
    'onUpgrade',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'customStatement') return;

      final args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final sqlArg = args.first.toSource().toLowerCase();
      if (!sqlArg.contains('foreign_keys')) return;

      // Check if inside onCreate or onUpgrade
      AstNode? current = node.parent;
      while (current != null) {
        if (current is NamedExpression) {
          final label = current.name.label.name;
          if (_migrationCallbacks.contains(label)) {
            reporter.atNode(node);
            return;
          }
        }
        if (current is ClassDeclaration) return;
        current = current.parent;
      }
    });
  }
}

// =============================================================================
// require_drift_reads_from
// =============================================================================

/// Warns when customSelect().watch() is missing the readsFrom parameter.
///
/// Since: v5.1.0 | Rule version: v1
///
/// Without the `readsFrom` parameter, Drift doesn't know which tables
/// a `customSelect` query reads from. This means the resulting stream
/// can never be invalidated — it returns the initial result and never
/// updates, even when the underlying data changes. This is a silent
/// bug that's very hard to debug.
///
/// **BAD:**
/// ```dart
/// customSelect('SELECT * FROM users WHERE active = 1').watch();
/// ```
///
/// **GOOD:**
/// ```dart
/// customSelect('SELECT * FROM users WHERE active = 1',
///   readsFrom: {users}).watch();
/// ```
class RequireDriftReadsFromRule extends SaropaLintRule {
  RequireDriftReadsFromRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_drift_reads_from',
    '[require_drift_reads_from] customSelect().watch() called without '
        'readsFrom parameter. Without readsFrom, Drift does not know which '
        'tables the query reads from and the stream can never be '
        'invalidated — it returns the initial result and never updates, '
        'even when the underlying data changes. {v1}',
    correctionMessage:
        'Add the readsFrom parameter: '
        'customSelect(sql, readsFrom: {tableName}).watch()',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _watchMethods = <String>{
    'watch',
    'watchSingle',
    'watchSingleOrNull',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_watchMethods.contains(node.methodName.name)) return;

      // Check if target chain contains customSelect
      final target = node.target;
      if (target == null) return;
      final targetSource = target.toSource();
      if (!targetSource.contains('customSelect')) return;

      // Check if customSelect call has readsFrom parameter
      if (targetSource.contains('readsFrom')) return;

      reporter.atNode(node.methodName);
    });
  }
}

// =============================================================================
// avoid_drift_unsafe_web_storage
// =============================================================================

/// Warns when unsafe web storage modes are used with Drift.
///
/// Since: v5.1.0 | Rule version: v1
///
/// `unsafeIndexedDb` and the legacy `WebDatabase` are NOT safe for
/// multiple browser tabs. Data races can occur when multiple tabs write
/// to the same database simultaneously. Use `opfsShared`, `opfsLocks`,
/// or `sharedIndexedDb` via drift_flutter's `driftDatabase()` for
/// multi-tab safety.
///
/// **BAD:**
/// ```dart
/// WebDatabase('app.db');
/// WasmDatabase(storage: DriftWebStorage.unsafeIndexedDb('app'));
/// ```
///
/// **GOOD:**
/// ```dart
/// driftDatabase(name: 'app'); // Selects best strategy automatically
/// ```
class AvoidDriftUnsafeWebStorageRule extends SaropaLintRule {
  AvoidDriftUnsafeWebStorageRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_drift_unsafe_web_storage',
    '[avoid_drift_unsafe_web_storage] Unsafe Drift web storage mode '
        'detected. unsafeIndexedDb and legacy WebDatabase are NOT safe for '
        'multiple browser tabs — data races can occur when multiple tabs '
        'write simultaneously. Use driftDatabase() from drift_flutter which '
        'selects the safest available strategy automatically. {v1}',
    correctionMessage:
        'Use driftDatabase(name: \'app\') from drift_flutter '
        'for automatic multi-tab safe storage selection.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Detect WebDatabase constructor
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final typeName = node.constructorName.type.name.lexeme;
      if (typeName == 'WebDatabase') {
        reporter.atNode(node);
      }
    });

    // Detect unsafeIndexedDb reference
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'unsafeIndexedDb') {
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// avoid_drift_close_streams_in_tests
// =============================================================================

/// Warns when NativeDatabase.memory() is used in tests without
/// closeStreamsSynchronously.
///
/// Since: v5.1.0 | Rule version: v1
///
/// In widget tests, Drift's stream debouncing uses timers that persist
/// after test completion. Without wrapping `NativeDatabase.memory()` in
/// a `DatabaseConnection` with `closeStreamsSynchronously: true`, tests
/// fail with "A Timer is still pending even after the widget was
/// disposed" errors. This is a common source of flaky tests.
///
/// **BAD:**
/// ```dart
/// setUp(() {
///   db = AppDatabase(NativeDatabase.memory());
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// setUp(() {
///   db = AppDatabase(DatabaseConnection(
///     NativeDatabase.memory(),
///     closeStreamsSynchronously: true,
///   ));
/// });
/// ```
class AvoidDriftCloseStreamsInTestsRule extends SaropaLintRule {
  AvoidDriftCloseStreamsInTestsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_drift_close_streams_in_tests',
    '[avoid_drift_close_streams_in_tests] NativeDatabase.memory() used in '
        'test file without closeStreamsSynchronously: true. Stream '
        'debouncing timers persist after test completion, causing flaky '
        'test failures with "Timer still pending" errors. Wrap in '
        'DatabaseConnection with closeStreamsSynchronously: true. {v1}',
    correctionMessage:
        'Wrap in DatabaseConnection: '
        'DatabaseConnection(NativeDatabase.memory(), '
        'closeStreamsSynchronously: true)',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  Set<String>? get requiredPatterns => const {'NativeDatabase.memory'};

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final typeName = node.constructorName.type.name.lexeme;
      final constructorName = node.constructorName.name?.name;
      if (typeName != 'NativeDatabase' || constructorName != 'memory') return;

      // Only relevant in test files
      if (!_isInTestFile(node)) return;

      // Check if wrapped in DatabaseConnection with the parameter
      final parent = node.parent;
      if (parent is ArgumentList) {
        final grandparent = parent.parent;
        if (grandparent is InstanceCreationExpression) {
          final wrapperType = grandparent.constructorName.type.name.lexeme;
          if (wrapperType == 'DatabaseConnection') {
            // Check for closeStreamsSynchronously parameter
            for (final arg in grandparent.argumentList.arguments) {
              if (arg is NamedExpression &&
                  arg.name.label.name == 'closeStreamsSynchronously') {
                return; // Already wrapped correctly
              }
            }
          }
        }
      }

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// avoid_drift_nullable_converter_mismatch
// =============================================================================

/// Warns when a TypeConverter has both nullable type parameters.
///
/// Since: v5.1.0 | Rule version: v1
///
/// A `TypeConverter<Foo?, int?>` with both nullable type parameters
/// cannot be applied to non-nullable columns (enforced since Drift v2).
/// This pattern is almost always wrong — use `NullAwareTypeConverter`
/// instead, or make only the Dart type nullable if the column is
/// nullable.
///
/// **BAD:**
/// ```dart
/// class MyConverter extends TypeConverter<MyEnum?, int?> {
///   @override
///   MyEnum? fromSql(int? fromDb) => ...;
///   @override
///   int? toSql(MyEnum? value) => ...;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyConverter extends TypeConverter<MyEnum, int> {
///   @override
///   MyEnum fromSql(int fromDb) => ...;
///   @override
///   int toSql(MyEnum value) => ...;
/// }
/// // For nullable columns, use NullAwareTypeConverter
/// ```
class AvoidDriftNullableConverterMismatchRule extends SaropaLintRule {
  AvoidDriftNullableConverterMismatchRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_drift_nullable_converter_mismatch',
    '[avoid_drift_nullable_converter_mismatch] Drift TypeConverter has '
        'both nullable type parameters (TypeConverter<Foo?, int?>). This '
        'cannot be applied to non-nullable columns since Drift v2 and is '
        'almost always wrong. Use NullAwareTypeConverter for nullable '
        'handling, or make only the needed type parameter nullable. {v1}',
    correctionMessage:
        'Use TypeConverter<Foo, int> for non-nullable '
        'columns, or NullAwareTypeConverter for nullable column support.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      if (!_extendsTypeConverter(node)) return;
      if (!fileImportsPackage(node, PackageImports.drift)) return;

      final superclass = node.extendsClause?.superclass;
      if (superclass == null) return;

      // Check type arguments
      final typeArgs = superclass.typeArguments;
      if (typeArgs == null || typeArgs.arguments.length < 2) return;

      final dartType = typeArgs.arguments[0];
      final sqlType = typeArgs.arguments[1];

      // Check if both end with ? (nullable)
      final dartTypeSource = dartType.toSource();
      final sqlTypeSource = sqlType.toSource();

      if (dartTypeSource.endsWith('?') && sqlTypeSource.endsWith('?')) {
        reporter.atNode(superclass);
      }
    });
  }
}
