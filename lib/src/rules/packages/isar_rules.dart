// ignore_for_file: depend_on_referenced_packages, deprecated_member_use, always_specify_types

/// Isar database rules for Flutter applications.
///
/// These rules detect common Isar database anti-patterns and
/// data corruption risks.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../mode_constants_utils.dart';
import '../../saropa_lint_rule.dart';

/// Warns when enum types are used directly as fields in Isar `@collection` classes.
///
/// Since: v1.7.6 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: avoid_isar_enum_index_change, isar_enum_corruption, isar_enum_index
///
/// Storing enums directly in Isar is dangerous because:
/// - Renaming an enum value breaks existing data
/// - Reordering enum values corrupts data (stored as index)
///
/// The correct pattern is to store the enum as a String and use a cached getter:
///
/// Example of **bad** code:
/// ```dart
/// @collection
/// class Contact {
///   CountryEnum? country;  // DANGEROUS: stored as index
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// @collection
/// class Contact {
///   String? countryCode;  // Store as string in DB
///
///   @ignore
///   CountryEnum? _country;  // Cached (ignored by Isar)
///
///   @ignore
///   CountryEnum? get country => _country ??= CountryEnum.tryParse(countryCode);
/// }
/// ```
class AvoidIsarEnumFieldRule extends SaropaLintRule {
  AvoidIsarEnumFieldRule() : super(code: _code);

  /// Data corruption risk: renaming/reordering enums breaks persisted rows.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_isar_enum_field',
    '[avoid_isar_enum_field] Storing enums directly in Isar collections is dangerous: renaming or reordering enum values will silently corrupt your data, breaking existing records and causing unpredictable bugs. {v3}',
    correctionMessage:
        'Store the enum as a String field in the database and use an @ignore getter to parse it into an enum. See the rule documentation for a safe pattern.',
    severity: DiagnosticSeverity.ERROR,
  );

  /// Type name suffixes that typically indicate an enum
  static const List<String> _enumSuffixes = <String>[
    'Enum',
    'Type',
    'Status',
    'Mode',
    'Kind',
    'Category',
    'State',
  ];

  /// Types that look like enums but are safe (not actually enums)
  static const Set<String> _safeTypes = <String>{
    'DateTime',
    'DateTimeType',
    'IndexType',
    'String',
    'int',
    'double',
    'bool',
    'Int8List',
    'Int16List',
    'Int32List',
    'Int64List',
    'Float32List',
    'Float64List',
    'Uint8List',
    'List',
    'Id',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if this class has @collection annotation
      if (!_hasCollectionAnnotation(node)) {
        return;
      }

      // Check each field in the class
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          _checkFieldDeclaration(member, reporter);
        }
      }
    });
  }

  /// Check if a class has the @collection annotation
  bool _hasCollectionAnnotation(ClassDeclaration node) {
    for (final Annotation annotation in node.metadata) {
      final String name = annotation.name.name.toLowerCase();
      if (name == 'collection') {
        return true;
      }
    }
    return false;
  }

  /// Check if a field has the @ignore annotation
  bool _hasIgnoreAnnotation(FieldDeclaration node) {
    for (final Annotation annotation in node.metadata) {
      final String name = annotation.name.name.toLowerCase();
      if (name == 'ignore') {
        return true;
      }
    }
    return false;
  }

  /// Check a field declaration for enum type usage
  void _checkFieldDeclaration(
    FieldDeclaration node,
    SaropaDiagnosticReporter reporter,
  ) {
    // Skip if field has @ignore annotation
    if (_hasIgnoreAnnotation(node)) {
      return;
    }

    final TypeAnnotation? type = node.fields.type;
    if (type == null) {
      return;
    }

    final String typeName = _extractTypeName(type);
    if (typeName.isEmpty) {
      return;
    }

    // Skip safe types
    if (_safeTypes.contains(typeName)) {
      return;
    }

    // Check if the type looks like an enum
    if (_looksLikeEnumType(typeName)) {
      reporter.atNode(node.fields, code);
    }
  }

  /// Extract the base type name from a type annotation
  String _extractTypeName(TypeAnnotation type) {
    if (type is NamedType) {
      return type.name.lexeme;
    }
    return '';
  }

  /// Check if a type name looks like an enum type based on naming conventions
  bool _looksLikeEnumType(String typeName) {
    // Remove nullable suffix for checking
    String cleanName = typeName;
    if (cleanName.endsWith('?')) {
      cleanName = cleanName.replaceAll('?', '');
    }

    for (final String suffix in _enumSuffixes) {
      if (cleanName.endsWith(suffix)) {
        return true;
      }
    }
    return false;
  }
}

// =============================================================================
// Isar Collection Annotation Rule
// =============================================================================

/// Warns when a class is used with Isar operations but lacks @collection.
///
/// Since: v4.13.0 | Rule version: v1
///
/// Classes passed to Isar operations (put, get, delete) must have the
/// @collection annotation to be properly persisted.
///
/// **BAD:**
/// ```dart
/// class User {
///   Id? id;
///   String? name;
/// }
/// await isar.writeTxn(() => isar.users.put(user)); // Error!
/// ```
///
/// **GOOD:**
/// ```dart
/// @collection
/// class User {
///   Id? id;
///   String? name;
/// }
/// ```
class RequireIsarCollectionAnnotationRule extends SaropaLintRule {
  RequireIsarCollectionAnnotationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_isar_collection_annotation',
    '[require_isar_collection_annotation] This class is missing the @collection annotation, so Isar will not generate an adapter for it. As a result, any attempt to persist or query this type will fail at runtime, and your build will break with missing adapter errors. {v1}',
    correctionMessage:
        'Add the @collection annotation to this class to enable Isar code generation and ensure persistence works.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if class has Id field (suggests Isar usage)
      bool hasIdField = false;
      for (final member in node.members) {
        if (member is FieldDeclaration) {
          final type = member.fields.type;
          if (type is NamedType && type.name.lexeme == 'Id') {
            hasIdField = true;
            break;
          }
        }
      }

      if (!hasIdField) return;

      // Check for @collection annotation
      bool hasCollection = false;
      for (final annotation in node.metadata) {
        if (annotation.name.name.toLowerCase() == 'collection') {
          hasCollection = true;
          break;
        }
      }

      if (!hasCollection) {
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// Isar ID Field Rule
// =============================================================================

/// Warns when @collection class is missing the required Id field.
///
/// Since: v4.13.0 | Rule version: v1
///
/// Every Isar collection must have an `Id? id` field to store the
/// auto-generated primary key.
///
/// **BAD:**
/// ```dart
/// @collection
/// class User {
///   String? name;  // Missing Id field!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @collection
/// class User {
///   Id? id;
///   String? name;
/// }
/// ```
class RequireIsarIdFieldRule extends SaropaLintRule {
  RequireIsarIdFieldRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_isar_id_field',
    '[require_isar_id_field] Every Isar collection must have an "Id? id" field as the primary key. Without it, Isar cannot uniquely identify records, and code generation will fail, causing your build to break and all database operations to be unusable. {v1}',
    correctionMessage:
        'Add "Id? id;" as the first field in your @collection class to enable Isar persistence and code generation.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check for @collection annotation
      bool hasCollection = false;
      for (final annotation in node.metadata) {
        if (annotation.name.name.toLowerCase() == 'collection') {
          hasCollection = true;
          break;
        }
      }

      if (!hasCollection) return;

      // Check for Id field
      bool hasIdField = false;
      for (final member in node.members) {
        if (member is FieldDeclaration) {
          final type = member.fields.type;
          if (type is NamedType && type.name.lexeme == 'Id') {
            hasIdField = true;
            break;
          }
        }
      }

      if (!hasIdField) {
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// Isar Close on Dispose Rule
// =============================================================================

/// Warns when Isar.open/openSync is used without closing in dispose.
///
/// Since: v4.13.0 | Rule version: v1
///
/// Isar instances hold file handles that must be released. Failure to close
/// causes resource leaks and can prevent database access in other parts.
///
/// **BAD:**
/// ```dart
/// class MyState extends State<MyWidget> {
///   late Isar isar;
///   void initState() {
///     isar = Isar.openSync([UserSchema]);
///   }
///   // Missing close in dispose!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyState extends State<MyWidget> {
///   late Isar isar;
///   void initState() {
///     isar = Isar.openSync([UserSchema]);
///   }
///   void dispose() {
///     isar.close();
///     super.dispose();
///   }
/// }
/// ```
class RequireIsarCloseOnDisposeRule extends SaropaLintRule {
  RequireIsarCloseOnDisposeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_isar_close_on_dispose',
    '[require_isar_close_on_dispose] If you do not close the Isar instance in dispose(), file handles and system resources will leak. This can cause database corruption, prevent reopening the database, and lead to crashes or data loss on app restart. {v1}',
    correctionMessage:
        'Always call isar.close() in your dispose() method to safely release resources and prevent leaks.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Look for Isar field declarations
      final List<String> isarFields = [];
      MethodDeclaration? disposeMethod;

      for (final member in node.members) {
        if (member is FieldDeclaration) {
          final type = member.fields.type;
          if (type is NamedType && type.name.lexeme == 'Isar') {
            for (final variable in member.fields.variables) {
              isarFields.add(variable.name.lexeme);
            }
          }
        }
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeMethod = member;
        }
      }

      if (isarFields.isEmpty) return;

      // Check if dispose calls close on isar fields
      if (disposeMethod == null) {
        // No dispose method at all - report on the class
        reporter.atNode(node);
        return;
      }

      final disposeBody = disposeMethod.body.toSource();
      for (final field in isarFields) {
        if (!disposeBody.contains('$field.close()') &&
            !disposeBody.contains('$field?.close()')) {
          reporter.atNode(disposeMethod);
        }
      }
    });
  }
}

// =============================================================================
// Isar Async Writes Rule
// =============================================================================

/// Warns when writeTxnSync is used in build methods.
///
/// Since: v4.13.0 | Rule version: v1
///
/// Synchronous database writes block the UI thread. Use writeTxn
/// (async) instead, especially in widget build methods.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   isar.writeTxnSync(() => isar.users.putSync(user));  // Blocks UI!
///   return Container();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void _saveUser() async {
///   await isar.writeTxn(() => isar.users.put(user));
/// }
/// ```
class PreferIsarAsyncWritesRule extends SaropaLintRule {
  PreferIsarAsyncWritesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_isar_async_writes',
    '[prefer_isar_async_writes] Using writeTxnSync in build methods will block the UI thread, causing your app to freeze, stutter, or become unresponsive. This leads to poor user experience and can trigger platform watchdogs to kill your app. {v1}',
    correctionMessage:
        'Always use writeTxn (async) instead of writeTxnSync in build methods or UI code. Refactor any synchronous database writes to be asynchronous to keep your app responsive.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'writeTxnSync') return;

      // Check if we're inside a build method
      AstNode? parent = node.parent;
      while (parent != null) {
        if (parent is MethodDeclaration && parent.name.lexeme == 'build') {
          reporter.atNode(node.methodName, code);
          return;
        }
        parent = parent.parent;
      }
    });
  }
}

// =============================================================================
// Isar Transaction Nesting Rule
// =============================================================================

/// Warns when writeTxn is called inside another writeTxn.
///
/// Since: v4.13.0 | Rule version: v1
///
/// Nested write transactions cause deadlocks in Isar. Each writeTxn
/// acquires an exclusive lock that cannot be acquired again.
///
/// **BAD:**
/// ```dart
/// await isar.writeTxn(() async {
///   await isar.writeTxn(() async {  // DEADLOCK!
///     await isar.users.put(user);
///   });
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// await isar.writeTxn(() async {
///   await isar.users.put(user);
///   await isar.posts.put(post);
/// });
/// ```
class AvoidIsarTransactionNestingRule extends SaropaLintRule {
  AvoidIsarTransactionNestingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_isar_transaction_nesting',
    '[avoid_isar_transaction_nesting] Calling writeTxn inside another writeTxn causes a deadlock: Isar cannot acquire a second write lock while the first is held. This will freeze your app and block all database writes until a restart. {v1}',
    correctionMessage:
        'Combine all write operations into a single writeTxn block to avoid deadlocks and ensure your app remains responsive.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final methodName = node.methodName.name;
      if (methodName != 'writeTxn' && methodName != 'writeTxnSync') return;

      // Check if we're inside another writeTxn
      AstNode? parent = node.parent;
      while (parent != null) {
        if (parent is MethodInvocation) {
          final parentMethod = parent.methodName.name;
          if (parentMethod == 'writeTxn' || parentMethod == 'writeTxnSync') {
            reporter.atNode(node.methodName, code);
            return;
          }
        }
        if (parent is FunctionExpression) {
          // Check if this function is the argument to writeTxn
          final funcParent = parent.parent;
          if (funcParent is ArgumentList) {
            final invocation = funcParent.parent;
            if (invocation is MethodInvocation) {
              final invokeMethod = invocation.methodName.name;
              if (invokeMethod == 'writeTxn' ||
                  invokeMethod == 'writeTxnSync') {
                // We're inside a writeTxn callback, now check if node is also writeTxn
                if (node != invocation) {
                  reporter.atNode(node.methodName, code);
                  return;
                }
              }
            }
          }
        }
        parent = parent.parent;
      }
    });
  }
}

// =============================================================================
// Isar Batch Operations Rule
// =============================================================================

/// Warns when put() is called in a loop instead of putAll().
///
/// Since: v4.13.0 | Rule version: v1
///
/// Individual put() calls in loops are ~100x slower than batch operations.
/// Isar optimizes putAll() for bulk inserts.
///
/// **BAD:**
/// ```dart
/// for (final user in users) {
///   await isar.users.put(user);  // Slow!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// await isar.users.putAll(users);  // Fast!
/// ```
class PreferIsarBatchOperationsRule extends SaropaLintRule {
  PreferIsarBatchOperationsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_isar_batch_operations',
    '[prefer_isar_batch_operations] Using put() in a loop for many records is extremely slow: each call triggers a separate database write. This can make your app hang or take minutes to save data. Batch operations like putAll() are up to 100x faster and prevent UI freezes. {v1}',
    correctionMessage:
        'Collect items into a list and use putAll() for batch writes instead of calling put() repeatedly. Refactor loops to use batch operations for better performance and user experience.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final methodName = node.methodName.name;
      if (methodName != 'put' && methodName != 'putSync') return;

      // Check if we're inside a for loop
      AstNode? parent = node.parent;
      while (parent != null) {
        if (parent is ForStatement ||
            parent is ForElement ||
            parent is ForEachParts) {
          reporter.atNode(node.methodName, code);
          return;
        }
        parent = parent.parent;
      }
    });
  }
}

// =============================================================================
// Isar Float Equality Rule
// =============================================================================

/// Warns when using equalTo() on double/float fields.
///
/// Since: v4.13.0 | Rule version: v1
///
/// Float equality is imprecise due to floating-point representation.
/// Use between() with a small epsilon for float comparisons.
///
/// **BAD:**
/// ```dart
/// isar.products.filter().priceEqualTo(19.99);  // May miss matches!
/// ```
///
/// **GOOD:**
/// ```dart
/// isar.products.filter().priceBetween(19.98, 20.00);
/// ```
class AvoidIsarFloatEqualityQueriesRule extends SaropaLintRule {
  AvoidIsarFloatEqualityQueriesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_isar_float_equality_queries',
    '[avoid_isar_float_equality_queries] Querying floats for exact equality is unreliable: due to rounding errors, you may miss matching records or get inconsistent results. This can break features that depend on accurate data retrieval. {v1}',
    correctionMessage:
        'Use .between(value - epsilon, value + epsilon) for float comparisons to ensure all relevant records are found and avoid subtle bugs.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final methodName = node.methodName.name;
      // Check for methods like priceEqualTo, amountEqualTo etc.
      if (!methodName.endsWith('EqualTo')) return;

      // Check if argument is a double literal
      final args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final firstArg = args.first;
      if (firstArg is DoubleLiteral) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

// =============================================================================
// Isar Inspector Debug Only Rule
// =============================================================================

/// Warns when Isar Inspector is used without kDebugMode guard.
///
/// Since: v4.13.0 | Rule version: v1
///
/// Isar Inspector exposes all database contents. It should only be
/// enabled in debug builds.
///
/// **BAD:**
/// ```dart
/// await Isar.open([UserSchema], inspector: true);  // Exposes data in prod!
/// ```
///
/// **GOOD:**
/// ```dart
/// await Isar.open([UserSchema], inspector: kDebugMode);
/// ```
class RequireIsarInspectorDebugOnlyRule extends SaropaLintRule {
  RequireIsarInspectorDebugOnlyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_isar_inspector_debug_only',
    '[require_isar_inspector_debug_only] Enabling Isar Inspector in production exposes internal database details and can create security risks or performance issues. Inspector should only be enabled in debug mode to protect user data and app integrity. {v1}',
    correctionMessage:
        'Set inspector: kDebugMode to ensure Inspector is only active during development. Never use inspector: true in production builds.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final methodName = node.methodName.name;
      if (methodName != 'open' && methodName != 'openSync') return;

      // Check target is Isar
      final target = node.target;
      if (target is! Identifier || target.name != 'Isar') return;

      // Look for inspector: true
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'inspector') {
          final value = arg.expression;
          if (value is BooleanLiteral && value.value == true) {
            reporter.atNode(arg);
          }
        }
      }
    });
  }
}

// =============================================================================
// Isar Clear in Production Rule
// =============================================================================

/// Warns when `Isar.clear()` is called without a debug mode guard.
///
/// Since: v4.8.5 | Updated: v4.13.0 | Rule version: v3
///
/// `Isar.clear()` deletes ALL data in the database. This should never
/// happen in production accidentally. Only flags `.clear()` on receivers
/// whose static type is `Isar` — does not flag `Map.clear()`,
/// `List.clear()`, `Set.clear()`, or other collection types.
///
/// **BAD:**
/// ```dart
/// await isar.clear();  // Deletes everything!
/// ```
///
/// **GOOD:**
/// ```dart
/// if (kDebugMode) {
///   await isar.clear();
/// }
/// ```
class AvoidIsarClearInProductionRule extends SaropaLintRule {
  AvoidIsarClearInProductionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_isar_clear_in_production',
    '[avoid_isar_clear_in_production] Calling isar.clear() will permanently delete ALL user data in the database. If this code runs in production, users will lose their data irreversibly, leading to catastrophic data loss. {v3}',
    correctionMessage:
        'Wrap isar.clear() in an if (kDebugMode) guard to ensure it only runs in development and never in production.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'clear') return;

      // Verify the receiver is an Isar instance to avoid false positives
      // on Map.clear(), List.clear(), Set.clear(), etc.
      final Expression? target = node.target;
      if (target == null) return;
      final String? typeName = target.staticType?.element?.name;
      if (typeName != 'Isar') return;

      // Check if inside mode constant guard
      AstNode? parent = node.parent;
      while (parent != null) {
        if (parent is IfStatement) {
          final condition = parent.expression.toSource();
          if (usesFlutterModeConstants(condition)) {
            return; // Properly guarded
          }
        }
        parent = parent.parent;
      }

      reporter.atNode(node.methodName, code);
    });
  }
}

// =============================================================================
// Isar Links Load Rule
// =============================================================================

/// Warns when IsarLinks properties are accessed without calling load().
///
/// Since: v4.13.0 | Rule version: v1
///
/// IsarLinks are lazily loaded. Accessing .length, .first, etc. without
/// calling load() first returns incorrect results.
///
/// **BAD:**
/// ```dart
/// final count = user.posts.length;  // Always 0 if not loaded!
/// ```
///
/// **GOOD:**
/// ```dart
/// await user.posts.load();
/// final count = user.posts.length;
/// ```
class RequireIsarLinksLoadRule extends SaropaLintRule {
  RequireIsarLinksLoadRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_isar_links_load',
    '[require_isar_links_load] Accessing IsarLinks without calling load() first will return incorrect or empty results. This leads to subtle data bugs, such as missing related records, and can break app features that depend on linked data. {v1}',
    correctionMessage:
        'Call await links.load() or links.loadSync() before accessing IsarLinks properties to ensure data is loaded and accurate.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _accessMethods = {
    'length',
    'first',
    'last',
    'isEmpty',
    'isNotEmpty',
    'single',
    'elementAt',
    'contains',
    'toList',
    'toSet',
    'forEach',
    'map',
    'where',
    'any',
    'every',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPropertyAccess((PropertyAccess node) {
      final propertyName = node.propertyName.name;
      if (!_accessMethods.contains(propertyName)) return;

      // This is a simplified check - in production, would need type analysis
      // to confirm the target is actually IsarLinks
      final targetSource = node.target?.toSource() ?? '';
      if (targetSource.contains('links') || targetSource.contains('Links')) {
        reporter.atNode(node.propertyName, code);
      }
    });
  }
}

// =============================================================================
// Isar Query Stream Rule
// =============================================================================

/// Warns when Timer-based polling is used instead of Isar's watch().
///
/// Since: v4.13.0 | Rule version: v1
///
/// Isar provides reactive queries via watch() that are more efficient
/// than periodic polling.
///
/// **BAD:**
/// ```dart
/// Timer.periodic(Duration(seconds: 1), (_) async {
///   final users = await isar.users.where().findAll();
///   setState(() => _users = users);
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// isar.users.where().watch().listen((users) {
///   setState(() => _users = users);
/// });
/// ```
class PreferIsarQueryStreamRule extends SaropaLintRule {
  PreferIsarQueryStreamRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_isar_query_stream',
    '[prefer_isar_query_stream] Using Timer.periodic or manual polling for reactive queries is inefficient and can drain battery, waste CPU, and miss real-time updates. Isar watch() streams are event-driven and update instantly when data changes. {v1}',
    correctionMessage:
        'Replace Timer.periodic polling with collection.where().watch().listen() to get instant, efficient updates and avoid unnecessary resource usage.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      // Check for Timer.periodic
      final constructorName = node.constructorName.toString();
      if (!constructorName.contains('Timer.periodic')) return;

      // Check if the callback contains Isar queries
      final args = node.argumentList.arguments;
      if (args.length < 2) return;

      final callback = args[1];
      final callbackSource = callback.toSource();

      if (callbackSource.contains('.where()') ||
          callbackSource.contains('.findAll()') ||
          callbackSource.contains('.findFirst()')) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

// =============================================================================
// Isar Web Limitations Rule
// =============================================================================

/// Warns when Isar sync APIs are used on web platform.
///
/// Since: v4.13.0 | Rule version: v1
///
/// Isar web uses IndexedDB which doesn't support synchronous operations.
/// Sync methods throw on web.
///
/// **BAD:**
/// ```dart
/// final users = isar.users.where().findAllSync();  // Throws on web!
/// ```
///
/// **GOOD:**
/// ```dart
/// final users = await isar.users.where().findAll();
/// ```
class AvoidIsarWebLimitationsRule extends SaropaLintRule {
  AvoidIsarWebLimitationsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_isar_web_limitations',
    '[avoid_isar_web_limitations] Isar sync APIs (e.g., putSync, getSync) will throw runtime errors or silently fail on web platforms. This can break your app for web users and cause data loss or missing features. {v1}',
    correctionMessage:
        'Replace all sync methods with async equivalents (e.g., put, get) to ensure your app works reliably on web and avoids runtime failures.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _syncMethods = {
    'findAllSync',
    'findFirstSync',
    'deleteAllSync',
    'putSync',
    'putAllSync',
    'getSync',
    'deleteSync',
    'countSync',
    'writeTxnSync',
    'openSync',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final methodName = node.methodName.name;
      if (_syncMethods.contains(methodName)) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

// =============================================================================
// Isar Index for Queries Rule
// =============================================================================

/// Warns when querying fields that should be indexed.
///
/// Since: v4.13.0 | Rule version: v1
///
/// Queries on non-indexed fields perform full table scans. Add @Index
/// to frequently queried fields.
///
/// **BAD:**
/// ```dart
/// // Without @Index on email field
/// isar.users.filter().emailEqualTo('test@test.com');  // Slow!
/// ```
///
/// **GOOD:**
/// ```dart
/// @collection
/// class User {
///   @Index()
///   String? email;  // Indexed for fast queries
/// }
/// ```
class PreferIsarIndexForQueriesRule extends SaropaLintRule {
  PreferIsarIndexForQueriesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_isar_index_for_queries',
    '[prefer_isar_index_for_queries] Querying fields without an @Index annotation forces Isar to scan the entire collection, resulting in slow queries and poor performance as your data grows. Indexed fields enable fast lookups and scalable apps. {v1}',
    correctionMessage:
        'Add @Index() annotation to any field you query frequently to ensure fast, indexed lookups and avoid performance bottlenecks.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // This rule would need full type resolution to be accurate.
    // For now, we provide a simplified implementation that warns
    // on filter() chains without prior index usage evidence.
    context.addMethodInvocation((MethodInvocation node) {
      final methodName = node.methodName.name;
      // Check for filter methods that suggest unindexed queries
      if (methodName == 'filter') {
        // Check if this is in a frequently-called method like build
        AstNode? parent = node.parent;
        while (parent != null) {
          if (parent is MethodDeclaration && parent.name.lexeme == 'build') {
            reporter.atNode(node.methodName, code);
            return;
          }
          parent = parent.parent;
        }
      }
    });
  }
}

// =============================================================================
// Isar Embedded Large Objects Rule
// =============================================================================

/// Warns when large objects are embedded in Isar collections.
///
/// Since: v4.13.0 | Rule version: v1
///
/// Embedded objects are duplicated in every record. Use IsarLinks
/// for large or shared objects.
///
/// **BAD:**
/// ```dart
/// @collection
/// class Order {
///   @embedded
///   LargeProduct? product;  // Duplicates product data in every order!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @collection
/// class Order {
///   final product = IsarLink<Product>();  // Links to shared product
/// }
/// ```
class AvoidIsarEmbeddedLargeObjectsRule extends SaropaLintRule {
  AvoidIsarEmbeddedLargeObjectsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_isar_embedded_large_objects',
    '[avoid_isar_embedded_large_objects] Using @embedded for large objects will duplicate the data in every record, causing excessive storage use and slow queries. For shared or large objects, this can make your database unmanageable. {v1}',
    correctionMessage:
        'Use IsarLink<T> instead of @embedded for large or shared objects to avoid duplication and keep your database efficient.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFieldDeclaration((FieldDeclaration node) {
      // Check for @embedded annotation
      bool hasEmbedded = false;
      for (final annotation in node.metadata) {
        if (annotation.name.name.toLowerCase() == 'embedded') {
          hasEmbedded = true;
          break;
        }
      }

      if (!hasEmbedded) return;

      // Warn on any embedded complex types
      final type = node.fields.type;
      if (type is NamedType) {
        final typeName = type.name.lexeme;
        // Skip simple types
        if (!{
          'String',
          'int',
          'double',
          'bool',
          'DateTime',
        }.contains(typeName)) {
          reporter.atNode(node.fields, code);
        }
      }
    });
  }
}

// =============================================================================
// Isar Lazy Links Rule
// =============================================================================

/// Warns when IsarLinks is used without .lazy for large collections.
///
/// Since: v4.13.0 | Rule version: v1
///
/// Regular IsarLinks loads all related objects eagerly. Use IsarLinks.lazy
/// for collections with many items.
///
/// **BAD:**
/// ```dart
/// final posts = IsarLinks<Post>();  // Loads ALL posts eagerly
/// ```
///
/// **GOOD:**
/// ```dart
/// final posts = IsarLinks<Post>.lazy();  // Loads on-demand
/// ```
class PreferIsarLazyLinksRule extends SaropaLintRule {
  PreferIsarLazyLinksRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_isar_lazy_links',
    '[prefer_isar_lazy_links] Using IsarLinks<T>() for large linked collections loads all linked records at once, which can slow down your app and waste memory. IsarLinks.lazy() loads records on demand for better performance. {v1}',
    correctionMessage:
        'Replace IsarLinks<T>() with IsarLinks<T>.lazy() for large or frequently accessed collections to keep your app fast and efficient.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final type = node.constructorName.type;
      final typeName = type.name.lexeme;
      if (typeName != 'IsarLinks') return;

      // Check if it's the lazy constructor
      final constructorName = node.constructorName.name?.name;
      if (constructorName != 'lazy') {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

// =============================================================================
// Isar Schema Breaking Changes Rule (Simplified)
// =============================================================================

/// Warns about potential Isar schema breaking changes.
///
/// Since: v4.13.0 | Rule version: v1
///
/// Removing fields, changing types, or renaming without @Name breaks migrations.
///
/// Note: Full detection requires comparing against previous schema versions,
/// which is beyond static analysis. This rule provides basic guidance.
class AvoidIsarSchemaBreakingChangesRule extends SaropaLintRule {
  AvoidIsarSchemaBreakingChangesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_isar_schema_breaking_changes',
    '[avoid_isar_schema_breaking_changes] Renaming, removing, or changing the type of a field in an Isar collection without using @Name will break migrations. This can cause data loss, failed upgrades, or app crashes for existing users. {v1}',
    correctionMessage:
        'When renaming a field, always add @Name("originalFieldName") to preserve the database mapping and ensure safe migrations.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // This is a documentation/awareness rule. Full schema comparison
    // would require cross-file/cross-version analysis.
    // We warn on @collection classes without any @Name annotations
    // as a reminder to use them for renamed fields.
    context.addClassDeclaration((ClassDeclaration node) {
      bool hasCollection = false;
      for (final annotation in node.metadata) {
        if (annotation.name.name.toLowerCase() == 'collection') {
          hasCollection = true;
          break;
        }
      }

      if (!hasCollection) return;

      // This rule is more of a reminder about using @Name for schema stability.
      // Full detection would require comparing against previous schema versions.
      // For now, we skip automated detection as it's beyond static analysis.
    });
  }
}

// // =============================================================================
// // Isar Non-Nullable Migration Rule
// // =============================================================================

// /// Warns when Isar fields are non-nullable without a default value.
// ///
// /// Changing a nullable field to non-nullable requires a default value
// /// for existing data.
// ///
// /// **BAD:**
// /// ```dart
// /// @collection
// /// class User {
// ///   String name = '';  // What about existing null values?
// /// }
// /// ```
// ///
// /// **GOOD:**
// /// ```dart
// /// @collection
// /// class User {
// ///   String? name;  // Keep nullable
// ///   // OR use migration to handle existing nulls
// /// }
// /// ```
// class RequireIsarNonNullableMigrationRule extends SaropaLintRule {
//   RequireIsarNonNullableMigrationRule() : super(code: _code);

//   @override
//   LintImpact get impact => LintImpact.high;

//   @override
//   RuleCost get cost => RuleCost.medium;

//   static const LintCode _code = LintCode(
//     'require_isar_non_nullable_migration',
//     problemMessage:
//         '[require_isar_non_nullable_migration] Making a field non-nullable without a default value will break migrations: existing database records that contain null values for this field will cause runtime deserialization errors, data loss, or schema upgrade failures when the app is updated.',
//     correctionMessage:
//         'Either keep the field nullable or provide a default value to ensure safe migrations, prevent data loss, and avoid runtime deserialization errors.',
//     severity: DiagnosticSeverity.ERROR,
//   );

//   @override
//   void runWithReporter(
//
//     SaropaDiagnosticReporter reporter,
//     SaropaContext context,
//   ) {
//     context.addClassDeclaration((ClassDeclaration node) {
//       bool hasCollection = false;
//       for (final annotation in node.metadata) {
//         if (annotation.name.name.toLowerCase() == 'collection') {
//           hasCollection = true;
//           break;
//         }
//       }

//       if (!hasCollection) return;

//       for (final member in node.members) {
//         if (member is FieldDeclaration) {
//           // Skip Id field
//           final type = member.fields.type;
//           if (type is NamedType && type.name.lexeme == 'Id') continue;

//           // Check for non-nullable fields without initializers
//           if (type is NamedType && type.question == null) {
//             for (final variable in member.fields.variables) {
//               if (variable.initializer == null) {
//                 // Non-nullable without default - potential migration issue
//                 reporter.atNode(variable);
//               }
//             }
//           }
//         }
//       }
//     });
//   }
// }

// =============================================================================
// Isar Nullable Field Rule (Replaces Non-Nullable Migration)
// =============================================================================

/// Enforces nullable types for all Isar fields to prevent migration crashes.
///
/// Since: v4.9.4 | Updated: v4.13.0 | Rule version: v3
///
/// Isar TypeAdapters bypass Dart constructors during hydration. If a field
/// is non-nullable but the disk record is from an older version (NULL),
/// the app will crash with a fatal TypeError.
///
/// **BAD:**
/// ```dart
/// @collection
/// class User {
///   String name = 'default';  // Crash if loading old record!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @collection
/// class User {
///   String? name;  // Safe
/// }
/// ```
class RequireIsarNullableFieldRule extends SaropaLintRule {
  RequireIsarNullableFieldRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_isar_nullable_field',
    '[require_isar_nullable_field] Isar TypeAdapters bypass constructors during hydration. Non-nullable fields trigger fatal TypeErrors when encountering NULL values from legacy disk records created in previous app versions where the field did not exist. {v3}',
    correctionMessage:
        'Convert the field to a nullable type (e.g., String?). This ensures the database safely loads legacy records. Handle the null state via a Domain Mapper or Repository to maintain strict application logic safely.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // 1. Check for @collection annotation
      bool hasCollection = false;
      for (final annotation in node.metadata) {
        if (annotation.name.name.toLowerCase() == 'collection') {
          hasCollection = true;
          break;
        }
      }
      if (!hasCollection) return;

      for (final member in node.members) {
        if (member is FieldDeclaration) {
          // 2. Skip static fields (not persisted by Isar)
          if (member.isStatic) continue;

          // 3. Skip fields with @ignore
          bool isIgnored = false;
          for (final annotation in member.metadata) {
            if (annotation.name.name.toLowerCase() == 'ignore') {
              isIgnored = true;
              break;
            }
          }
          if (isIgnored) continue;

          final type = member.fields.type;

          // 4. Skip Id field (Isar handles internally)
          if (type is NamedType && type.name.lexeme == 'Id') continue;

          // 5. Enforce Nullability
          // We check if the type definition lacks the '?' question mark.
          // We do NOT check for initializers anymore, as they are ignored by Isar readers.
          if (type is NamedType && type.question == null) {
            reporter.atNode(type);
          }
        }
      }
    });
  }
}

// =============================================================================
// Isar Composite Index Rule
// =============================================================================

/// Warns when multi-field queries lack composite indexes.
///
/// Since: v4.13.0 | Rule version: v1
///
/// Queries on multiple fields need composite @Index for efficiency.
///
/// **BAD:**
/// ```dart
/// isar.users.filter()
///   .firstNameEqualTo('John')
///   .lastNameEqualTo('Doe');  // No composite index!
/// ```
///
/// **GOOD:**
/// ```dart
/// @collection
/// class User {
///   @Index(composite: [CompositeIndex('lastName')])
///   String? firstName;
///   String? lastName;
/// }
/// ```
class PreferIsarCompositeIndexRule extends SaropaLintRule {
  PreferIsarCompositeIndexRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_isar_composite_index',
    '[prefer_isar_composite_index] Querying multiple fields together without a composite index will force Isar to scan every record, making queries slow and unscalable as your data grows. Composite indexes enable fast, efficient lookups for multi-field queries. {v1}',
    correctionMessage:
        'Add @Index(composite: [...]) for any field combinations you frequently query together to ensure fast, indexed lookups and scalable performance.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      // Check for chained filter conditions
      final methodName = node.methodName.name;
      if (!methodName.endsWith('EqualTo') &&
          !methodName.endsWith('StartsWith')) {
        return;
      }

      // Check if this is part of a chain
      final parent = node.parent;
      if (parent is MethodInvocation) {
        final parentMethod = parent.methodName.name;
        if (parentMethod.endsWith('EqualTo') ||
            parentMethod.endsWith('StartsWith')) {
          reporter.atNode(node.methodName, code);
        }
      }
    });
  }
}

// =============================================================================
// Isar String Contains Without Index Rule
// =============================================================================

/// Warns when string contains() is used without a full-text index.
///
/// Since: v4.13.0 | Rule version: v1
///
/// String contains queries without index perform full table scans.
/// Add @Index(type: IndexType.value) for text search fields.
///
/// **BAD:**
/// ```dart
/// isar.products.filter().nameContains('phone');  // Full scan!
/// ```
///
/// **GOOD:**
/// ```dart
/// @collection
/// class Product {
///   @Index(type: IndexType.value)
///   String? name;  // Indexed for contains queries
/// }
/// ```
class AvoidIsarStringContainsWithoutIndexRule extends SaropaLintRule {
  AvoidIsarStringContainsWithoutIndexRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_isar_string_contains_without_index',
    '[avoid_isar_string_contains_without_index] Running contains or matches queries on string fields without a full-text index will force Isar to scan every record, making queries extremely slow and potentially freezing your app as data grows. {v1}',
    correctionMessage:
        'Add @Index(type: IndexType.value) to the field being searched to enable fast, indexed text queries and prevent performance bottlenecks.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final methodName = node.methodName.name;
      // Check for contains-style methods
      if (methodName.endsWith('Contains') ||
          methodName.endsWith('Matches') ||
          methodName == 'contains') {
        // Check if this is in a filter context
        final targetSource = node.target?.toSource() ?? '';
        if (targetSource.contains('filter()') ||
            targetSource.contains('.filter')) {
          reporter.atNode(node.methodName, code);
        }
      }
    });
  }
}

/// Warns when Isar (or other single-subscription) streams are incorrectly cached or reused.
///
/// Isar streams must be created inline and not stored in variables or fields.
/// Caching or reusing these streams causes runtime errors.
///
/// **BAD:**
/// ```dart
/// final usersStream = isar.users.where().watch(); // BAD: cached
/// StreamBuilder(stream: usersStream, ...)
/// ```
///
/// **GOOD:**
/// ```dart
/// StreamBuilder(stream: isar.users.where().watch(), ...)
/// ```

/// Detects and prevents caching of Isar query streams, which must be created inline.
///
/// Since: v4.1.1 | Updated: v4.13.0 | Rule version: v2
///
/// # Why this matters
/// Isar's `.watch()` streams are single-subscription and must be created inline for each use.
/// Caching or reusing these streams (e.g., storing in a variable or field) leads to runtime errors:
///   - "Bad state: Stream has already been listened to."
///   - Data not updating in UI
///   - Subtle bugs when widgets rebuild
///
/// # What this rule catches
/// - Assigning the result of `isar.<collection>.where().watch()` (or similar) to a variable or field
/// - Storing Isar streams in class fields, top-level variables, or as properties
///
/// # False positives
/// - The rule uses a simple heuristic: it matches any variable/field assignment whose initializer contains both 'isar' and 'watch'.
///   This may catch some advanced patterns or false positives if those terms appear together in unrelated code.
///
/// # Performance
/// - The rule is fast: it only inspects variable and field initializers for the relevant string patterns.
/// - No recursion or deep AST traversal is performed.
///
/// # Quick fix
/// - (Planned) Will offer to inline the offending stream expression directly into the nearest StreamBuilder or listener.
///
/// # Impact
/// - LintImpact.high (runtime crash risk)
/// - RuleCost.medium (simple pattern match, low analysis cost)
///
/// # Aliases
/// - isar_stream_cache, isar_watch_cache, isar_stream_reuse
///
/// # Example
/// ```dart
/// // BAD:
/// final usersStream = isar.users.where().watch();
/// StreamBuilder(stream: usersStream, ...)
///
/// // GOOD:
/// StreamBuilder(stream: isar.users.where().watch(), ...)
/// ```
class AvoidCachedIsarStreamRule extends SaropaLintRule {
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  /// Prevents caching of Isar query streams (must be created inline).
  AvoidCachedIsarStreamRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'avoid_cached_isar_stream',
    '[avoid_cached_isar_stream] Caching or storing Isar/single-subscription streams in variables or fields will cause runtime errors: these streams can only be listened to once and must be created inline each time. If you cache them, your app will throw a StateError or fail to update as expected. {v2}',
    correctionMessage:
        'Always create Isar streams directly inside StreamBuilder, listeners, or widgets that consume them. Do NOT assign Isar streams to variables, fields, or properties. Refactor any code that stores an Isar stream so it is created inline at the point of use.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check top-level and local variable assignments
    context.addVariableDeclaration((VariableDeclaration node) {
      final Expression? init = node.initializer;
      if (init == null) return;
      final String source = init.toSource().toLowerCase();
      // Heuristic: look for isar stream creation
      if (source.contains('isar') && source.contains('watch')) {
        reporter.atNode(node);
      }
    });

    // Check class field assignments
    context.addFieldDeclaration((FieldDeclaration node) {
      for (final variable in node.fields.variables) {
        final Expression? init = variable.initializer;
        if (init == null) continue;
        final String source = init.toSource().toLowerCase();
        if (source.contains('isar') && source.contains('watch')) {
          reporter.atNode(variable);
        }
      }
    });
  }
}
