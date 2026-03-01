// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// SQLite/sqflite lint rules for Flutter applications.
///
/// These rules help ensure proper SQLite usage including type matching
/// between SQL and Dart types.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../saropa_lint_rule.dart';

// =============================================================================
// avoid_sqflite_type_mismatch
// =============================================================================

/// Warns when SQLite column types may not match Dart types correctly.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: sqflite_type, sqlite_type_mismatch
///
/// SQLite types must match Dart types. SQLite is dynamically typed but
/// sqflite expects specific Dart types for columns. Type conversion issues
/// cause runtime errors or data corruption.
///
/// **BAD:**
/// ```dart
/// // Boolean stored as INTEGER but read without conversion
/// final isActive = row['is_active']; // Returns int, not bool!
///
/// // DateTime stored as TEXT but not parsed
/// final createdAt = row['created_at']; // Returns String, not DateTime!
/// ```
///
/// **GOOD:**
/// ```dart
/// // Convert INTEGER to bool
/// final isActive = row['is_active'] == 1;
///
/// // Parse TEXT to DateTime
/// final createdAt = DateTime.parse(row['created_at'] as String);
///
/// // Or use helper methods
/// extension DatabaseRowExtension on Map<String, Object?> {
///   bool getBool(String key) => this[key] == 1;
///   DateTime getDateTime(String key) => DateTime.parse(this[key] as String);
/// }
/// ```
class AvoidSqfliteTypeMismatchRule extends SaropaLintRule {
  AvoidSqfliteTypeMismatchRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_sqflite_type_mismatch',
    '[avoid_sqflite_type_mismatch] SQLite type may not match Dart type. '
        'Booleans are stored as INTEGER (0/1), DateTime as TEXT/INTEGER. {v2}',
    correctionMessage:
        'Convert types explicitly: bool = row["col"] == 1; DateTime = DateTime.parse(row["col"]).',
    severity: DiagnosticSeverity.ERROR,
  );

  /// Column names that suggest boolean values
  static const Set<String> _boolColumnPatterns = <String>{
    'is_',
    'has_',
    'can_',
    'should_',
    '_enabled',
    '_active',
    '_visible',
    '_deleted',
    '_verified',
    '_confirmed',
    '_completed',
    '_read',
    '_archived',
  };

  /// Column names that suggest datetime values
  static const Set<String> _dateColumnPatterns = <String>{
    'created_at',
    'updated_at',
    'deleted_at',
    'timestamp',
    'date',
    '_date',
    '_time',
    '_at',
  };

  static final RegExp _rowTargetPattern = RegExp(
    r'\b(row|map|result|data)\b',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIndexExpression((IndexExpression node) {
      // Check for row['column'] pattern
      final Expression? target = node.target;
      if (target == null) return;

      final Expression index = node.index;

      // Check if target looks like a database row
      final String targetSource = target.toSource().toLowerCase();
      if (!_rowTargetPattern.hasMatch(targetSource)) {
        return;
      }

      // Check if the index is a string literal (column name)
      if (index is! SimpleStringLiteral) return;

      final String columnName = index.value.toLowerCase();

      // Check for bool columns being accessed without conversion
      bool isBoolColumn = false;
      for (final String pattern in _boolColumnPatterns) {
        if (columnName.contains(pattern)) {
          isBoolColumn = true;
          break;
        }
      }

      // Check for date columns
      bool isDateColumn = false;
      for (final String pattern in _dateColumnPatterns) {
        if (columnName.contains(pattern)) {
          isDateColumn = true;
          break;
        }
      }

      if (!isBoolColumn && !isDateColumn) return;

      // Check if there's proper type conversion
      AstNode? parent = node.parent;

      // Check for direct assignment without conversion
      if (parent is VariableDeclaration) {
        // Check if the variable has a type annotation that matches
        final VariableDeclarationList? varList =
            parent.parent as VariableDeclarationList?;
        if (varList != null) {
          final String? typeAnnotation = varList.type?.toSource();
          if (typeAnnotation != null) {
            if (isBoolColumn && typeAnnotation == 'bool') {
              reporter.atNode(node);
              return;
            }
            if (isDateColumn && typeAnnotation == 'DateTime') {
              reporter.atNode(node);
              return;
            }
          }
        }
      }

      // Check for == 1 conversion for booleans
      if (isBoolColumn) {
        if (parent is BinaryExpression) {
          final String operator = parent.operator.lexeme;
          if (operator == '==' || operator == '!=') {
            return; // Has comparison, likely converting to bool
          }
        }
        if (parent is AsExpression) {
          final String castType = parent.type.toSource();
          if (castType == 'bool') {
            reporter.atNode(node);
          }
          return;
        }
      }

      // Check for DateTime.parse conversion
      if (isDateColumn) {
        if (parent is MethodInvocation) {
          final String methodName = parent.methodName.name;
          if (methodName == 'parse') {
            return; // Has DateTime.parse conversion
          }
        }
        if (parent is ArgumentList) {
          // Check if being passed to DateTime.parse or similar
          final AstNode? grandparent = parent.parent;
          if (grandparent is MethodInvocation) {
            if (grandparent.methodName.name == 'parse') {
              return;
            }
          }
        }
      }
    });

    // Also check CREATE TABLE statements for documentation
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for execute/rawQuery with CREATE TABLE
      if (methodName != 'execute' && methodName != 'rawQuery') return;

      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final String sqlArg = args.first.toSource().toLowerCase();

      // Check for BOOLEAN columns (SQLite doesn't have native BOOLEAN)
      if (sqlArg.contains('create table') && sqlArg.contains('boolean')) {
        reporter.atNode(args.first, code);
      }
    });
  }
}

// =============================================================================
// prefer_sqflite_encryption
// =============================================================================

/// Warns when sqflite is used for potentially sensitive data without encryption.
///
/// **OWASP:** M9: Insecure Data Storage. Use sqflite_sqlcipher for sensitive DBs.
///
/// **BAD:**
/// ```dart
/// final db = await openDatabase('user_accounts.db', version: 1, ...);
/// ```
///
/// **GOOD:**
/// ```dart
/// import 'package:sqflite_sqlcipher/sqflite.dart';
/// final db = await openDatabase(path, password: await _getKey(), version: 1, ...);
/// ```
class PreferSqfliteEncryptionRule extends SaropaLintRule {
  PreferSqfliteEncryptionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'openDatabase'};

  @override
  OwaspMapping? get owasp =>
      const OwaspMapping(mobile: <OwaspMobile>{OwaspMobile.m9});

  static const LintCode _code = LintCode(
    'prefer_sqflite_encryption',
    '[prefer_sqflite_encryption] Sensitive database opened without encryption. Use sqflite_sqlcipher for user/auth/health/payment data.',
    correctionMessage:
        'Add sqflite_sqlcipher and open the database with a password, or use a non-sensitive path.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _sensitivePathPatterns = <String>{
    'user',
    'auth',
    'account',
    'payment',
    'health',
    'medical',
    'private',
    'credential',
    'secret',
  };

  static final RegExp _sqfliteTargetPattern = RegExp(
    r'\b(sqflite|databaseFactory)\b',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (!ProjectContext.hasDependency(context.filePath, 'sqflite')) return;
    if (ProjectContext.hasDependency(context.filePath, 'sqflite_sqlcipher') ||
        ProjectContext.hasDependency(
          context.filePath,
          'sqlcipher_flutter_libs',
        )) {
      return;
    }
    if (context.isInTestDirectory) return;

    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'openDatabase') return;
      final Expression? target = node.target;
      if (target != null) {
        final String targetSource = target.toSource();
        if (!_sqfliteTargetPattern.hasMatch(targetSource)) {
          return;
        }
      }
      final args = node.argumentList.arguments;
      if (args.isEmpty) return;
      final String pathSource = args.first.toSource().toLowerCase();
      if (pathSource.contains(':memory:')) return;
      final pathValue = args.first is SimpleStringLiteral
          ? (args.first as SimpleStringLiteral).value.toLowerCase()
          : pathSource;
      if (pathValue.isEmpty) return;
      final isSensitive = _sensitivePathPatterns.any(
        (p) => pathValue.contains(p),
      );
      if (!isSensitive) return;
      reporter.atNode(node);
    });
  }
}
