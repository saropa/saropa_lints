import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart';

/// Warns when file read operations are used without exists() check or try-catch.
///
/// File operations on non-existent files throw exceptions. Always verify
/// the file exists or wrap in try-catch to handle missing files gracefully.
///
/// **BAD:**
/// ```dart
/// final content = await file.readAsString(); // Crashes if file missing!
/// ```
///
/// **GOOD:**
/// ```dart
/// if (await file.exists()) {
///   final content = await file.readAsString();
/// }
/// // OR
/// try {
///   final content = await file.readAsString();
/// } on FileSystemException {
///   handleMissingFile();
/// }
/// ```
class RequireFileExistsCheckRule extends SaropaLintRule {
  const RequireFileExistsCheckRule() : super(code: _code);

  /// Important for robust file handling.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_file_exists_check',
    problemMessage:
        '[require_file_exists_check] File read operation should check exists() or use try-catch.',
    correctionMessage: 'Wrap in if (await file.exists()) or try-catch block.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _fileReadMethods = <String>{
    'readAsString',
    'readAsStringSync',
    'readAsBytes',
    'readAsBytesSync',
    'readAsLines',
    'readAsLinesSync',
    'openRead',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_fileReadMethods.contains(methodName)) return;

      // Use type resolution to verify this is a File from dart:io
      final Expression? target = node.target;
      if (target == null) return;

      final String? typeName = target.staticType?.element?.name;
      if (typeName != 'File') return;

      // Check if inside try-catch
      bool insideTryCatch = false;
      AstNode? current = node.parent;

      while (current != null) {
        if (current is TryStatement) {
          insideTryCatch = true;
          break;
        }
        current = current.parent;
      }

      if (insideTryCatch) return;

      // Check if preceded by exists() check in same block
      current = node.parent;
      BlockFunctionBody? enclosingBody;

      while (current != null) {
        if (current is BlockFunctionBody) {
          enclosingBody = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingBody != null) {
        final String bodySource = enclosingBody.toSource();
        // Simple check for exists() call before the read operation
        final int readPos = bodySource.indexOf(methodName);
        final int existsPos = bodySource.indexOf('.exists()');

        if (existsPos >= 0 && existsPos < readPos) {
          return; // exists() check is before read
        }
      }

      reporter.atNode(node.methodName, code);
    });
  }
}

/// Warns when PDF loading lacks error handling.
///
/// PDF files can be corrupted, password-protected, or use unsupported features.
/// Without error handling, these failures crash the app instead of showing
/// a helpful error message.
///
/// **BAD:**
/// ```dart
/// final doc = await PDFDocument.fromAsset('file.pdf'); // May crash!
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   final doc = await PDFDocument.fromAsset('file.pdf');
/// } catch (e) {
///   showError('Could not open PDF: $e');
/// }
/// ```
class RequirePdfErrorHandlingRule extends SaropaLintRule {
  const RequirePdfErrorHandlingRule() : super(code: _code);

  /// Important for robust PDF handling.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_pdf_error_handling',
    problemMessage:
        '[require_pdf_error_handling] PDF loading should have error handling.',
    correctionMessage: 'Wrap PDF loading in try-catch block.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _pdfLoadMethods = <String>{
    'fromAsset',
    'fromFile',
    'fromUrl',
    'fromPath',
    'openDocument',
    'loadDocument',
  };

  static const Set<String> _pdfTypes = <String>{
    'PDFDocument',
    'PdfDocument',
    'PdfController',
    'PDFView',
    'PdfViewer',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_pdfLoadMethods.contains(methodName)) return;

      // Check if target is a PDF-related type
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      bool isPdfOperation = false;
      for (final String pdfType in _pdfTypes) {
        if (targetSource.contains(pdfType)) {
          isPdfOperation = true;
          break;
        }
      }

      if (!isPdfOperation) return;

      // Check if inside try-catch
      bool insideTryCatch = false;
      AstNode? current = node.parent;

      while (current != null) {
        if (current is TryStatement) {
          insideTryCatch = true;
          break;
        }
        current = current.parent;
      }

      if (!insideTryCatch) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when GraphQL response is used without checking for errors.
///
/// GraphQL returns errors in the response body, not via HTTP status codes.
/// Accessing `result.data` without checking `result.hasException` may
/// process null data or miss important error information.
///
/// **BAD:**
/// ```dart
/// final result = await client.query(options);
/// final data = result.data!['users']; // May be null if there's an error!
/// ```
///
/// **GOOD:**
/// ```dart
/// final result = await client.query(options);
/// if (result.hasException) {
///   handleError(result.exception!);
///   return;
/// }
/// final data = result.data!['users'];
/// ```
class RequireGraphqlErrorHandlingRule extends SaropaLintRule {
  const RequireGraphqlErrorHandlingRule() : super(code: _code);

  /// Critical for robust GraphQL apps.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_graphql_error_handling',
    problemMessage:
        '[require_graphql_error_handling] GraphQL result should check hasException before accessing data.',
    correctionMessage:
        'Add if (result.hasException) check before result.data access.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// GraphQL result type names from graphql_flutter and similar packages.
  static const Set<String> _graphqlResultTypes = <String>{
    'QueryResult',
    'MutationResult',
    'SubscriptionResult',
    'GraphQLResponse',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPropertyAccess((PropertyAccess node) {
      // Check for .data access
      if (node.propertyName.name != 'data') return;

      // Use type resolution to verify this is a GraphQL result
      final Expression? target = node.target;
      if (target == null) return;

      final String? typeName = target.staticType?.element?.name;
      if (typeName == null || !_graphqlResultTypes.contains(typeName)) {
        return;
      }

      // Check if hasException is checked before this access
      AstNode? current = node.parent;
      BlockFunctionBody? enclosingBody;

      while (current != null) {
        if (current is BlockFunctionBody) {
          enclosingBody = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingBody != null) {
        final String bodySource = enclosingBody.toSource();
        final int dataAccessPos = bodySource.indexOf('.data');
        final int hasExceptionPos = bodySource.indexOf('hasException');
        final int errorsPos = bodySource.indexOf('.errors');

        // Check if error handling appears before data access
        if ((hasExceptionPos >= 0 && hasExceptionPos < dataAccessPos) ||
            (errorsPos >= 0 && errorsPos < dataAccessPos)) {
          return; // Error check is before data access
        }

        reporter.atNode(node.propertyName, code);
      }
    });
  }
}

// =============================================================================
// Part 5 Rules: sqflite Database Rules
// =============================================================================

/// Warns when SQL queries use string interpolation instead of whereArgs.
///
/// String interpolation in SQL queries is vulnerable to SQL injection attacks.
/// Always use parameterized queries with whereArgs.
///
/// **BAD:**
/// ```dart
/// db.query('users', where: 'id = $userId');
/// db.rawQuery('SELECT * FROM users WHERE name = "$name"');
/// ```
///
/// **GOOD:**
/// ```dart
/// db.query('users', where: 'id = ?', whereArgs: [userId]);
/// db.rawQuery('SELECT * FROM users WHERE name = ?', [name]);
/// ```
class RequireSqfliteWhereArgsRule extends SaropaLintRule {
  const RequireSqfliteWhereArgsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_sqflite_whereargs',
    problemMessage:
        '[require_sqflite_whereargs] SQL injection vulnerability. Use whereArgs instead of string interpolation.',
    correctionMessage:
        'Always use ? placeholders and the whereArgs parameter for SQL queries. Avoid string interpolation, which exposes your app to SQL injection attacks, data corruption, and security breaches.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _sqlMethods = <String>{
    'query',
    'rawQuery',
    'rawDelete',
    'rawUpdate',
    'rawInsert',
    'delete',
    'update',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_sqlMethods.contains(methodName)) return;

      // Check if target looks like a database
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('db') &&
          !targetSource.contains('database') &&
          !targetSource.contains('batch')) {
        return;
      }

      // Check arguments for string interpolation
      for (final Expression arg in node.argumentList.arguments) {
        // Check named 'where' argument
        if (arg is NamedExpression) {
          final String paramName = arg.name.label.name;
          if (paramName == 'where' || paramName == 'sql') {
            if (_hasInterpolation(arg.expression)) {
              reporter.atNode(arg, code);
              return;
            }
          }
        }
        // Check positional arguments (for rawQuery, etc.)
        else if (arg is StringInterpolation) {
          reporter.atNode(arg, code);
          return;
        } else if (arg is AdjacentStrings) {
          for (final StringLiteral part in arg.strings) {
            if (part is StringInterpolation) {
              reporter.atNode(arg, code);
              return;
            }
          }
        }
      }
    });
  }

  bool _hasInterpolation(Expression expr) {
    if (expr is StringInterpolation) return true;
    if (expr is AdjacentStrings) {
      return expr.strings.any((s) => s is StringInterpolation);
    }
    // Check for string concatenation with +
    if (expr is BinaryExpression && expr.operator.lexeme == '+') {
      return true;
    }
    return false;
  }
}

/// Warns when sqflite database operations are not in a transaction.
///
/// Multiple sequential writes should use transactions for atomicity
/// and better performance.
///
/// **BAD:**
/// ```dart
/// await db.insert('users', user1);
/// await db.insert('users', user2);
/// await db.insert('users', user3);
/// ```
///
/// **GOOD:**
/// ```dart
/// await db.transaction((txn) async {
///   await txn.insert('users', user1);
///   await txn.insert('users', user2);
///   await txn.insert('users', user3);
/// });
/// ```
class RequireSqfliteTransactionRule extends SaropaLintRule {
  const RequireSqfliteTransactionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_sqflite_transaction',
    problemMessage:
        '[require_sqflite_transaction] Multiple sequential writes should use transaction for atomicity.',
    correctionMessage:
        'Wrap writes in db.transaction() for better performance.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _writeMethods = <String>{
    'insert',
    'update',
    'delete',
    'rawInsert',
    'rawUpdate',
    'rawDelete',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBlock((Block node) {
      // Count database write operations in this block
      int writeCount = 0;
      MethodInvocation? firstWrite;

      for (final Statement statement in node.statements) {
        _countWrites(statement, (MethodInvocation write) {
          writeCount++;
          firstWrite ??= write;
        });
      }

      // Report if 3+ writes found without transaction
      if (writeCount >= 3 && firstWrite != null) {
        // Check if already inside transaction
        bool insideTransaction = false;
        AstNode? current = node.parent;
        while (current != null) {
          if (current is MethodInvocation &&
              current.methodName.name == 'transaction') {
            insideTransaction = true;
            break;
          }
          current = current.parent;
        }

        if (!insideTransaction) {
          reporter.atNode(firstWrite!, code);
        }
      }
    });
  }

  void _countWrites(AstNode node, void Function(MethodInvocation) onWrite) {
    if (node is MethodInvocation) {
      if (_writeMethods.contains(node.methodName.name)) {
        final Expression? target = node.target;
        if (target != null) {
          final String targetSource = target.toSource().toLowerCase();
          if (targetSource.contains('db') ||
              targetSource.contains('database')) {
            onWrite(node);
          }
        }
      }
    }

    // Recurse into children
    for (final child in node.childEntities) {
      if (child is AstNode) {
        _countWrites(child, onWrite);
      }
    }
  }
}

/// Warns when sqflite database operations are not wrapped in try-catch.
///
/// Database operations can fail due to schema issues, disk full, or
/// constraint violations.
///
/// **BAD:**
/// ```dart
/// await db.insert('users', userData);
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   await db.insert('users', userData);
/// } on DatabaseException catch (e) {
///   handleDatabaseError(e);
/// }
/// ```
class RequireSqfliteErrorHandlingRule extends SaropaLintRule {
  const RequireSqfliteErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_sqflite_error_handling',
    problemMessage:
        '[require_sqflite_error_handling] Database operation should have error handling.',
    correctionMessage: 'Wrap in try-catch to handle DatabaseException.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _dbMethods = <String>{
    'insert',
    'update',
    'delete',
    'query',
    'rawQuery',
    'rawInsert',
    'rawUpdate',
    'rawDelete',
    'execute',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_dbMethods.contains(methodName)) return;

      // Check if target looks like a database
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('db') &&
          !targetSource.contains('database') &&
          !targetSource.contains('txn') &&
          !targetSource.contains('batch')) {
        return;
      }

      // Check if inside try-catch
      AstNode? current = node.parent;
      while (current != null) {
        if (current is TryStatement) return;
        if (current is FunctionBody) break;
        current = current.parent;
      }

      reporter.atNode(node, code);
    });
  }
}

/// Warns when sqflite uses individual inserts in a loop instead of batch.
///
/// Inserting rows one at a time is slow. Use batch operations for bulk inserts.
///
/// **BAD:**
/// ```dart
/// for (final user in users) {
///   await db.insert('users', user.toMap());
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// final batch = db.batch();
/// for (final user in users) {
///   batch.insert('users', user.toMap());
/// }
/// await batch.commit();
/// ```
class PreferSqfliteBatchRule extends SaropaLintRule {
  const PreferSqfliteBatchRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_sqflite_batch',
    problemMessage:
        '[prefer_sqflite_batch] Database insert in loop. Use batch operations for better performance.',
    correctionMessage: 'Use db.batch() with batch.insert() and batch.commit().',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addForStatement((ForStatement node) {
      _checkLoopBody(node.body, reporter);
    });

    context.registry.addForElement((ForElement node) {
      // ForElement is in list literals, less common for DB operations
    });

    context.registry.addWhileStatement((WhileStatement node) {
      _checkLoopBody(node.body, reporter);
    });
  }

  void _checkLoopBody(Statement body, SaropaDiagnosticReporter reporter) {
    _visitStatements(body, (MethodInvocation node) {
      if (node.methodName.name != 'insert') return;

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (targetSource.contains('db') || targetSource.contains('database')) {
        // Check it's not already a batch
        if (!targetSource.contains('batch')) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  void _visitStatements(
      AstNode node, void Function(MethodInvocation) callback) {
    if (node is MethodInvocation) {
      callback(node);
    }
    for (final child in node.childEntities) {
      if (child is AstNode) {
        _visitStatements(child, callback);
      }
    }
  }
}

/// Warns when sqflite database is opened but not closed.
///
/// Database connections should be closed when no longer needed to free resources.
///
/// **BAD:**
/// ```dart
/// final db = await openDatabase('my_db.db');
/// // ... use db
/// // Never closed!
/// ```
///
/// **GOOD:**
/// ```dart
/// final db = await openDatabase('my_db.db');
/// try {
///   // ... use db
/// } finally {
///   await db.close();
/// }
/// ```
class RequireSqfliteCloseRule extends SaropaLintRule {
  const RequireSqfliteCloseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_sqflite_close',
    problemMessage:
        '[require_sqflite_close] Database opened but not closed. Resource leak possible.',
    correctionMessage:
        'Ensure db.close() is called, preferably in a finally block or dispose().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check class fields that are databases
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Find fields that look like databases
      final List<VariableDeclaration> dbFields = <VariableDeclaration>[];

      for (final member in node.members) {
        if (member is FieldDeclaration) {
          for (final variable in member.fields.variables) {
            final String typeStr =
                member.fields.type?.toSource().toLowerCase() ?? '';
            final String nameStr = variable.name.lexeme.toLowerCase();

            if (typeStr.contains('database') ||
                nameStr.contains('db') ||
                nameStr.contains('database')) {
              dbFields.add(variable);
            }
          }
        }
      }

      if (dbFields.isEmpty) return;

      // Check for dispose method with close() calls
      bool hasClose = false;

      for (final member in node.members) {
        if (member is MethodDeclaration) {
          final String methodName = member.name.lexeme;
          if (methodName == 'dispose' || methodName == 'close') {
            final String? bodySource = member.body.toSource();
            if (bodySource != null && bodySource.contains('.close()')) {
              hasClose = true;
              break;
            }
          }
        }
      }

      if (!hasClose) {
        for (final field in dbFields) {
          reporter.atNode(field, code);
        }
      }
    });
  }
}

/// Warns when SQLite reserved words are used as column names.
///
/// Alias: sqflite_reserved_word, sql_reserved_column
///
/// SQLite reserved words like ORDER, GROUP, SELECT, etc. cannot be used
/// as column names without escaping. This causes cryptic SQL syntax errors.
///
/// **BAD:**
/// ```dart
/// await db.execute('''
///   CREATE TABLE items (
///     id INTEGER PRIMARY KEY,
///     order INTEGER  // 'order' is reserved!
///   )
/// ''');
/// ```
///
/// **GOOD:**
/// ```dart
/// await db.execute('''
///   CREATE TABLE items (
///     id INTEGER PRIMARY KEY,
///     "order" INTEGER  // Escaped with double quotes
///   )
/// ''');
/// // Or better: rename the column
/// await db.execute('''
///   CREATE TABLE items (
///     id INTEGER PRIMARY KEY,
///     sort_order INTEGER
///   )
/// ''');
/// ```
class AvoidSqfliteReservedWordsRule extends SaropaLintRule {
  const AvoidSqfliteReservedWordsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_sqflite_reserved_words',
    problemMessage:
        '[avoid_sqflite_reserved_words] SQL statement may contain SQLite reserved word as column name. Consequence: This can cause SQL errors, failed migrations, and data loss.',
    correctionMessage:
        'Escape reserved words with double quotes or rename the column.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// SQLite reserved words that commonly cause issues when used as column names
  static const Set<String> _reservedWords = <String>{
    'abort',
    'action',
    'add',
    'after',
    'all',
    'alter',
    'analyze',
    'and',
    'as',
    'asc',
    'attach',
    'autoincrement',
    'before',
    'begin',
    'between',
    'by',
    'cascade',
    'case',
    'cast',
    'check',
    'collate',
    'column',
    'commit',
    'conflict',
    'constraint',
    'create',
    'cross',
    'current',
    'current_date',
    'current_time',
    'current_timestamp',
    'database',
    'default',
    'deferrable',
    'deferred',
    'delete',
    'desc',
    'detach',
    'distinct',
    'drop',
    'each',
    'else',
    'end',
    'escape',
    'except',
    'exclusive',
    'exists',
    'explain',
    'fail',
    'for',
    'foreign',
    'from',
    'full',
    'glob',
    'group',
    'having',
    'if',
    'ignore',
    'immediate',
    'in',
    'index',
    'indexed',
    'initially',
    'inner',
    'insert',
    'instead',
    'intersect',
    'into',
    'is',
    'isnull',
    'join',
    'key',
    'left',
    'like',
    'limit',
    'match',
    'natural',
    'no',
    'not',
    'notnull',
    'null',
    'of',
    'offset',
    'on',
    'or',
    'order',
    'outer',
    'plan',
    'pragma',
    'primary',
    'query',
    'raise',
    'recursive',
    'references',
    'regexp',
    'reindex',
    'release',
    'rename',
    'replace',
    'restrict',
    'right',
    'rollback',
    'row',
    'savepoint',
    'select',
    'set',
    'table',
    'temp',
    'temporary',
    'then',
    'to',
    'transaction',
    'trigger',
    'union',
    'unique',
    'update',
    'using',
    'vacuum',
    'values',
    'view',
    'virtual',
    'when',
    'where',
    'with',
    'without',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for SQL execution methods
      if (methodName != 'execute' &&
          methodName != 'rawQuery' &&
          methodName != 'rawInsert' &&
          methodName != 'rawUpdate' &&
          methodName != 'rawDelete') {
        return;
      }

      // Check if target looks like a database
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('db') && !targetSource.contains('database')) {
        return;
      }

      // Get the SQL string
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression sqlArg = args.first;
      final String sqlSource = sqlArg.toSource().toLowerCase();

      // Check for CREATE TABLE or column definition patterns
      if (sqlSource.contains('create table') ||
          sqlSource.contains('insert into') ||
          sqlSource.contains('alter table')) {
        // Look for reserved words used as identifiers
        for (final String reserved in _reservedWords) {
          // Match patterns like "reserved INTEGER" or "reserved TEXT"
          // But not if it's escaped with quotes
          final RegExp unescapedPattern = RegExp(
            '\\b$reserved\\s+(integer|text|real|blob|numeric|varchar|boolean)',
            caseSensitive: false,
          );

          if (unescapedPattern.hasMatch(sqlSource)) {
            // Check if it's properly escaped
            final RegExp escapedPattern = RegExp(
              '["\'`]$reserved["\'`]',
              caseSensitive: false,
            );
            if (!escapedPattern.hasMatch(sqlSource)) {
              reporter.atNode(node, code);
              return;
            }
          }
        }
      }
    });
  }
}

// =============================================================================
// Part 5 Rules: Hive Database Rules
// =============================================================================

/// Warns when Hive.openBox is called without prior Hive.init.
///
/// Hive must be initialized before opening boxes. Failure to do so
/// results in runtime errors.
///
/// **BAD:**
/// ```dart
/// final box = await Hive.openBox('myBox'); // Crashes!
/// ```
///
/// **GOOD:**
/// ```dart
/// await Hive.initFlutter();
/// final box = await Hive.openBox('myBox');
/// ```
class RequireHiveInitializationRule extends SaropaLintRule {
  const RequireHiveInitializationRule() : super(code: _code);

  /// HEURISTIC: This rule cannot verify cross-file initialization.
  /// It serves as a reminder to ensure init is called somewhere.
  /// Impact is medium since this is informational, not a definite bug.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_hive_initialization',
    problemMessage:
        '[require_hive_initialization] Hive.openBox called. Verify Hive.init() or Hive.initFlutter() is called in main().',
    correctionMessage:
        'Ensure Hive.initFlutter() is called in main() before opening boxes (cannot verify cross-file).',
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

      // Check for openBox variants
      if (!methodName.startsWith('openBox') &&
          !methodName.startsWith('openLazyBox')) {
        return;
      }

      // Check if target is Hive
      final Expression? target = node.target;
      if (target == null) return;

      if (target is SimpleIdentifier && target.name == 'Hive') {
        // This is a Hive.openBox call - warn about initialization
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when custom types are stored in Hive without @HiveType annotation.
///
/// Custom classes stored in Hive need TypeAdapters. Use @HiveType and
/// @HiveField annotations with hive_generator.
///
/// **BAD:**
/// ```dart
/// class User {
///   final String name;
/// }
/// box.put('user', user); // Runtime error!
/// ```
///
/// **GOOD:**
/// ```dart
/// @HiveType(typeId: 0)
/// class User {
///   @HiveField(0)
///   final String name;
/// }
/// ```
class RequireHiveTypeAdapterRule extends SaropaLintRule {
  const RequireHiveTypeAdapterRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_hive_type_adapter',
    problemMessage:
        '[require_hive_type_adapter] Hive cannot serialize this object without '
        '@HiveType annotation. Storing will throw a HiveError at runtime.',
    correctionMessage:
        'Add @HiveType(typeId: X) annotation and generate adapter with build_runner.',
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

      // Check for put/add operations
      if (methodName != 'put' &&
          methodName != 'add' &&
          methodName != 'addAll') {
        return;
      }

      // Check if target looks like a Hive box
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('box')) return;

      // Check arguments - if it's a custom object (not primitive)
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      // Get the value argument (2nd for put, 1st for add)
      final Expression valueArg =
          methodName == 'put' && args.length > 1 ? args[1] : args.first;

      // Check if value is a user-defined class instance
      final String? typeName = valueArg.staticType?.element?.name;
      if (typeName != null && !_isPrimitiveType(typeName)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _isPrimitiveType(String typeName) {
    return const <String>{
      'String',
      'int',
      'double',
      'bool',
      'num',
      'List',
      'Map',
      'Set',
      'DateTime',
      'Duration',
      'BigInt',
      'Uint8List',
    }.contains(typeName);
  }
}

/// Warns when Hive box is opened but not closed in dispose.
///
/// Boxes should be closed when no longer needed, especially in widgets.
///
/// **BAD:**
/// ```dart
/// late Box box;
/// void initState() {
///   box = await Hive.openBox('myBox');
/// }
/// // dispose() doesn't close box
/// ```
///
/// **GOOD:**
/// ```dart
/// late Box box;
/// void dispose() {
///   box.close();
///   super.dispose();
/// }
/// ```
class RequireHiveBoxCloseRule extends SaropaLintRule {
  const RequireHiveBoxCloseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_hive_box_close',
    problemMessage:
        '[require_hive_box_close] Hive box opened but not closed in dispose. Resource leak.',
    correctionMessage: 'Call box.close() in dispose() method.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Find Box fields
      final List<VariableDeclaration> boxFields = <VariableDeclaration>[];

      for (final member in node.members) {
        if (member is FieldDeclaration) {
          for (final variable in member.fields.variables) {
            final String typeStr = member.fields.type?.toSource() ?? '';
            final String nameStr = variable.name.lexeme.toLowerCase();

            if (typeStr.contains('Box') || nameStr.contains('box')) {
              boxFields.add(variable);
            }
          }
        }
      }

      if (boxFields.isEmpty) return;

      // Check for dispose method with close() calls
      bool hasClose = false;

      for (final member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          final String? bodySource = member.body.toSource();
          if (bodySource != null && bodySource.contains('.close()')) {
            hasClose = true;
            break;
          }
        }
      }

      if (!hasClose) {
        for (final field in boxFields) {
          reporter.atNode(field, code);
        }
      }
    });
  }
}

/// Warns when Hive stores sensitive data without encryption.
///
/// Sensitive data like passwords, tokens, and personal information
/// should be stored in encrypted boxes.
///
/// **BAD:**
/// ```dart
/// final box = await Hive.openBox('secrets');
/// box.put('password', password);
/// ```
///
/// **GOOD:**
/// ```dart
/// final key = await secureStorage.read(key: 'hive_key');
/// final encryptedBox = await Hive.openBox(
///   'secrets',
///   encryptionCipher: HiveAesCipher(key),
/// );
/// ```
class PreferHiveEncryptionRule extends SaropaLintRule {
  const PreferHiveEncryptionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_hive_encryption',
    problemMessage:
        '[prefer_hive_encryption] Unencrypted Hive box stores data in plaintext. '
        'Anyone with device access can read sensitive user data.',
    correctionMessage:
        'Use encryptionCipher parameter with HiveAesCipher for sensitive data.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _sensitiveKeys = <String>{
    'password',
    'token',
    'secret',
    'api_key',
    'apikey',
    'credential',
    'private',
    'ssn',
    'credit',
    'auth',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName != 'put' && methodName != 'add') return;

      // Check if target is a box
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('box')) return;

      // Check key for sensitive patterns
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final String keySource = args.first.toSource().toLowerCase();

      for (final pattern in _sensitiveKeys) {
        if (keySource.contains(pattern)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when HiveAesCipher uses a hardcoded encryption key.
///
/// Hardcoded keys can be extracted from the app binary. Store keys
/// securely using flutter_secure_storage.
///
/// **BAD:**
/// ```dart
/// final cipher = HiveAesCipher(base64.decode('hardcodedKeyHere=='));
/// final cipher = HiveAesCipher([1, 2, 3, 4, 5, ...]);
/// ```
///
/// **GOOD:**
/// ```dart
/// final keyString = await secureStorage.read(key: 'hive_key');
/// final cipher = HiveAesCipher(base64.decode(keyString!));
/// ```
class RequireHiveEncryptionKeySecureRule extends SaropaLintRule {
  const RequireHiveEncryptionKeySecureRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_hive_encryption_key_secure',
    problemMessage:
        '[require_hive_encryption_key_secure] Hardcoded key defeats encryption. '
        'Anyone decompiling the app can decrypt all stored user data.',
    correctionMessage:
        'Store encryption key in flutter_secure_storage, not in code.',
    errorSeverity: DiagnosticSeverity.ERROR,
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

      if (typeName != 'HiveAesCipher') return;

      // Check if argument is a literal
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression keyArg = args.first;

      // Check for list literal
      if (keyArg is ListLiteral) {
        reporter.atNode(node, code);
        return;
      }

      // Check for hardcoded string in decode call
      if (keyArg is MethodInvocation) {
        final String source = keyArg.toSource();
        // Look for decode with string literal
        if (source.contains("decode('") || source.contains('decode("')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when SELECT * is used in sqflite rawQuery() calls.
///
/// Alias: sqflite_select_columns, avoid_select_star
///
/// ## Why This Matters
///
/// Using SELECT * fetches all columns from the database, which:
/// - Wastes memory by loading unused data
/// - Increases network/disk bandwidth
/// - Breaks when table schema changes (new columns appear unexpectedly)
/// - Prevents SQLite query optimization
///
/// ## Detection
///
/// This rule checks `rawQuery()` calls for SQL strings containing `SELECT *`.
/// The `query()` method is not checked because it uses column parameters, not
/// raw SQL. Methods like `rawInsert`, `rawUpdate`, `rawDelete` are not checked
/// because they don't use SELECT statements.
///
/// ## Example
///
/// ### BAD:
/// ```dart
/// // Fetches ALL columns, including large blob fields you don't need
/// final users = await db.rawQuery('SELECT * FROM users WHERE id = ?', [id]);
/// ```
///
/// ### GOOD:
/// ```dart
/// // Only fetches what you need
/// final users = await db.rawQuery(
///   'SELECT id, name, email FROM users WHERE id = ?',
///   [id],
/// );
/// ```
class AvoidSqfliteReadAllColumnsRule extends SaropaLintRule {
  const AvoidSqfliteReadAllColumnsRule() : super(code: _code);

  /// Medium impact - performance issue, not a crash.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_sqflite_read_all_columns',
    problemMessage:
        '[avoid_sqflite_read_all_columns] SELECT * fetches unnecessary columns, wasting memory and bandwidth.',
    correctionMessage:
        'Specify only the columns you need: SELECT id, name, email FROM ...',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  // Only check rawQuery - the method that takes raw SQL strings with SELECT.
  // query() uses column parameters, not raw SQL.
  // rawInsert/rawUpdate/rawDelete don't use SELECT.
  static const Set<String> _sqfliteMethods = <String>{
    'rawQuery',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!_sqfliteMethods.contains(node.methodName.name)) return;

      // Check the first argument (SQL string) for SELECT *
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      // Get the first positional argument
      Expression? sqlArg;
      for (final arg in args) {
        if (arg is! NamedExpression) {
          sqlArg = arg;
          break;
        }
      }

      if (sqlArg == null) return;

      // Check if it's a string literal containing SELECT *
      String? sqlString;

      if (sqlArg is SimpleStringLiteral) {
        sqlString = sqlArg.value;
      } else if (sqlArg is AdjacentStrings) {
        sqlString = sqlArg.strings.map((s) {
          if (s is SimpleStringLiteral) return s.value;
          return '';
        }).join();
      }

      if (sqlString != null) {
        // Case-insensitive check for SELECT *
        final String upperSql = sqlString.toUpperCase();
        if (upperSql.contains('SELECT *') || upperSql.contains('SELECT  *')) {
          reporter.atNode(sqlArg, code);
        }
      }
    });
  }
}

/// Warns when PDF files are loaded entirely into memory without streaming.
///
/// Loading entire PDF documents into memory can cause out-of-memory errors
/// for large files, especially on mobile devices with limited RAM. Use
/// streaming or page-by-page loading for better memory efficiency.
///
/// **BAD:**
/// ```dart
/// // Loads entire PDF into memory at once
/// final doc = await PdfDocument.fromAsset('large_report.pdf');
/// final bytes = await rootBundle.load('assets/document.pdf');
/// final pdfBytes = await file.readAsBytes();
/// final doc = PdfDocument.openData(pdfBytes);
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use streaming or page-by-page loading
/// final doc = await PdfDocument.openFile(file.path);
/// // Only render pages as needed
/// final page = await doc.getPage(pageNumber);
///
/// // Or use a PDF viewer that handles pagination
/// PDFView(
///   filePath: file.path,
///   pageSnap: true,
///   swipeHorizontal: false,
/// )
/// ```
class AvoidLoadingFullPdfInMemoryRule extends SaropaLintRule {
  const AvoidLoadingFullPdfInMemoryRule() : super(code: _code);

  /// High impact - can cause OOM crashes on mobile devices.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_loading_full_pdf_in_memory',
    problemMessage:
        '[avoid_loading_full_pdf_in_memory] Loading entire PDF into memory may cause out-of-memory errors.',
    correctionMessage:
        'Use file path-based loading or streaming instead of loading bytes into memory.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// PDF loading methods that load entire document into memory.
  static const Set<String> _memoryLoadMethods = <String>{
    'fromAsset',
    'openData',
    'fromData',
    'fromBytes',
    'openAsset',
  };

  /// PDF type names from common PDF packages.
  static const Set<String> _pdfTypes = <String>{
    'PdfDocument',
    'PDFDocument',
    'Document',
    'PdfController',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_memoryLoadMethods.contains(methodName)) return;

      // Check if target is a PDF-related type
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      bool isPdfOperation = false;
      for (final String pdfType in _pdfTypes) {
        if (targetSource.contains(pdfType)) {
          isPdfOperation = true;
          break;
        }
      }

      if (!isPdfOperation) return;

      reporter.atNode(node, code);
    });

    // Also check for patterns like PdfDocument.openData(await file.readAsBytes())
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_pdfTypes.contains(typeName)) return;

      // Check for data/bytes parameters
      for (final Expression arg in node.argumentList.arguments) {
        String argSource = '';
        if (arg is NamedExpression) {
          final String paramName = arg.name.label.name;
          if (paramName == 'data' || paramName == 'bytes') {
            argSource = arg.expression.toSource();
          }
        } else {
          argSource = arg.toSource();
        }

        // Check if the argument loads bytes into memory
        if (argSource.contains('readAsBytes') ||
            argSource.contains('readAsBytesSync') ||
            argSource.contains('rootBundle.load') ||
            argSource.contains('ByteData')) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

// =============================================================================
// prefer_sqflite_singleton
// =============================================================================

/// Use singleton database instance instead of multiple openDatabase calls.
///
/// Calling openDatabase repeatedly creates connection overhead and may
/// cause locking issues. Use a singleton pattern.
///
/// **BAD:**
/// ```dart
/// Future<void> saveUser(User user) async {
///   final db = await openDatabase('app.db');  // Opens new connection!
///   await db.insert('users', user.toMap());
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class DatabaseService {
///   static Database? _db;
///   static Future<Database> get database async {
///     return _db ??= await openDatabase('app.db');
///   }
/// }
/// ```
class PreferSqfliteSingletonRule extends SaropaLintRule {
  const PreferSqfliteSingletonRule() : super(code: _code);

  /// Database connection overhead and potential locking.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_sqflite_singleton',
    problemMessage:
        '[prefer_sqflite_singleton] openDatabase called directly. May create multiple connections.',
    correctionMessage: 'Use a singleton pattern for database instance.',
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
      if (methodName != 'openDatabase') return;

      // Check if we're inside a non-singleton context
      // Look for common singleton patterns: static field, getter, or factory
      final FunctionBody? enclosingBody =
          node.thisOrAncestorOfType<FunctionBody>();
      if (enclosingBody == null) return;

      // Check if enclosing function/method is a static getter or uses null-aware
      final MethodDeclaration? method =
          enclosingBody.parent as MethodDeclaration?;
      if (method != null) {
        // If it's a getter returning cached value, it's likely a singleton
        if (method.isGetter) return;
        if (method.isStatic) {
          final String bodySource = enclosingBody.toSource();
          // Check for caching patterns like ??= or if (_db != null)
          if (bodySource.contains('??=') || bodySource.contains('_db')) return;
        }
      }

      reporter.atNode(node, code);
    });
  }
}

// =============================================================================
// prefer_sqflite_column_constants
// =============================================================================

// cspell:ignore emial

/// Use constants for column names to avoid typos.
///
/// String literals for column names are error-prone. Use constants
/// for compile-time checking.
///
/// **BAD:**
/// ```dart
/// await db.query('users', columns: ['id', 'name', 'emial']);  // Typo!
/// ```
///
/// **GOOD:**
/// ```dart
/// class UserTable {
///   static const table = 'users';
///   static const colId = 'id';
///   static const colName = 'name';
///   static const colEmail = 'email';
/// }
/// await db.query(UserTable.table, columns: [UserTable.colId, ...]);
/// ```
class PreferSqfliteColumnConstantsRule extends SaropaLintRule {
  const PreferSqfliteColumnConstantsRule() : super(code: _code);

  /// Runtime errors from column name typos.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_sqflite_column_constants',
    problemMessage:
        '[prefer_sqflite_column_constants] String literal column name may contain typos.',
    correctionMessage: 'Define column names as constants in a table class.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Database methods that take column parameters.
  static const Set<String> _dbMethods = <String>{
    'query',
    'rawQuery',
    'insert',
    'update',
    'delete',
    'rawInsert',
    'rawUpdate',
    'rawDelete',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_dbMethods.contains(methodName)) return;

      // Check if target looks like a database
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (!targetSource.contains('db') &&
          !targetSource.contains('database') &&
          !targetSource.contains('Database')) {
        return;
      }

      // Check for string literal column names in columns parameter
      final ArgumentList args = node.argumentList;
      for (final Expression arg in args.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'columns') {
          final Expression value = arg.expression;
          if (value is ListLiteral) {
            for (final CollectionElement element in value.elements) {
              if (element is SimpleStringLiteral) {
                reporter.atNode(element, code);
                return;
              }
            }
          }
        }
      }
    });
  }
}
