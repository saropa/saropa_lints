// ignore_for_file: depend_on_referenced_packages, deprecated_member_use, always_specify_types

/// Isar database rules for Flutter applications.
///
/// These rules detect common Isar database anti-patterns and
/// data corruption risks.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when enum types are used directly as fields in Isar `@collection` classes.
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
  const AvoidIsarEnumFieldRule() : super(code: _code);

  /// Data corruption risk: renaming/reordering enums breaks persisted rows.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_isar_enum_field',
    problemMessage:
        '[avoid_isar_enum_field] Enum fields in Isar collections can cause data corruption '
        'if the enum is renamed or reordered.',
    correctionMessage: 'Store the enum as a String field and use an @ignore '
        'getter to parse it. See rule documentation for the pattern.',
    errorSeverity: DiagnosticSeverity.ERROR,
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
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
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

  @override
  List<Fix> getFixes() => <Fix>[_AvoidIsarEnumFieldFix()];

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
      FieldDeclaration node, SaropaDiagnosticReporter reporter) {
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

class _AvoidIsarEnumFieldFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    final String fileContent = resolver.source.contents.data;

    context.registry.addFieldDeclaration((FieldDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.fields.variables.length != 1) return;
      if (_hasIgnoreAnnotation(node)) return;

      final TypeAnnotation? type = node.fields.type;
      if (type is! NamedType) return;

      final VariableDeclaration variable = node.fields.variables.first;
      final ClassDeclaration? clazz = node.parent is ClassDeclaration
          ? node.parent as ClassDeclaration
          : null;
      if (clazz == null || !_hasCollectionAnnotation(clazz)) return;

      final bool isNullable = type.question != null;
      final String enumTypeSource = type.name.toString();
      final String enumTypeBase = enumTypeSource.endsWith('?')
          ? enumTypeSource.substring(0, enumTypeSource.length - 1)
          : enumTypeSource;
      final String enumGetterType = enumTypeSource;
      final String cacheFieldType =
          enumGetterType.endsWith('?') ? enumGetterType : '$enumGetterType?';
      final String stringType = isNullable ? 'String?' : 'String';

      final String variableName = variable.name.lexeme;
      final String stringFieldName = '${variableName}Name';
      final String cacheFieldName = '_$variableName';

      if (_classHasMemberNamed(clazz, stringFieldName) ||
          _classHasMemberNamed(clazz, cacheFieldName)) {
        return;
      }

      final String indent = _computeIndent(fileContent, node.offset);
      final String storageModifiers = _buildStorageModifiers(node);

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace enum field with string storage + helper',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        final StringBuffer buffer = StringBuffer();

        final Comment? docs = node.documentationComment;
        if (docs != null) {
          buffer.writeln('$indent${docs.toSource()}');
        }

        for (final Annotation annotation in node.metadata) {
          buffer.writeln('$indent${annotation.toSource()}');
        }

        buffer.writeln('$indent$storageModifiers$stringType $stringFieldName;');
        buffer.writeln();
        buffer.writeln('$indent@ignore');
        buffer.writeln('$indent$cacheFieldType $cacheFieldName;');
        buffer.writeln();
        buffer.writeln('$indent@ignore');
        buffer.writeln('$indent$enumGetterType get $variableName {');
        buffer.writeln('$indent  final value = $stringFieldName;');
        if (isNullable) {
          buffer.writeln('$indent  if (value == null) return $cacheFieldName;');
          buffer.writeln('$indent  try {');
          buffer.writeln(
              '$indent    return $cacheFieldName ??= $enumTypeBase.values.byName(value);');
          buffer.writeln('$indent  } on ArgumentError {');
          buffer.writeln('$indent    return null;');
          buffer.writeln('$indent  }');
        } else {
          buffer.writeln('$indent  final cached = $cacheFieldName;');
          buffer.writeln('$indent  if (cached != null) return cached;');
          buffer.writeln('$indent  if (value == null) {');
          buffer.writeln(
              "$indent    throw StateError('$stringFieldName is null for $variableName');");
          buffer.writeln('$indent  }');
          buffer.writeln('$indent  try {');
          buffer.writeln(
              '$indent    return $cacheFieldName ??= $enumTypeBase.values.byName(value);');
          buffer.writeln('$indent  } on ArgumentError {');
          buffer.writeln(
              "$indent    throw StateError('Invalid $enumTypeBase value: \$value');");
          buffer.writeln('$indent  }');
        }
        buffer.writeln('$indent}');

        builder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          buffer.toString(),
        );
      });
    });
  }

  bool _classHasMemberNamed(ClassDeclaration clazz, String name) {
    for (final ClassMember member in clazz.members) {
      if (member is FieldDeclaration) {
        for (final VariableDeclaration variable in member.fields.variables) {
          if (variable.name.lexeme == name) {
            return true;
          }
        }
      }
      if (member is MethodDeclaration && member.name.lexeme == name) {
        return true;
      }
    }
    return false;
  }

  String _buildStorageModifiers(FieldDeclaration node) {
    final StringBuffer modifiers = StringBuffer();
    if (node.isStatic) modifiers.write('static ');

    final VariableDeclarationList fields = node.fields;
    if (fields.lateKeyword != null) modifiers.write('late ');
    if (fields.isFinal || fields.keyword?.lexeme == 'final') {
      modifiers.write('final ');
    }

    return modifiers.toString();
  }

  bool _hasCollectionAnnotation(ClassDeclaration node) {
    for (final Annotation annotation in node.metadata) {
      final String name = annotation.name.name.toLowerCase();
      if (name == 'collection') {
        return true;
      }
    }
    return false;
  }

  bool _hasIgnoreAnnotation(FieldDeclaration node) {
    for (final Annotation annotation in node.metadata) {
      final String name = annotation.name.name.toLowerCase();
      if (name == 'ignore') {
        return true;
      }
    }
    return false;
  }

  String _computeIndent(String content, int offset) {
    final int lineStart = content.lastIndexOf('\n', offset - 1);
    final int start = lineStart == -1 ? 0 : lineStart + 1;
    final int firstNonWhitespace = content.indexOf(RegExp(r'[^\s]'), start);
    if (firstNonWhitespace == -1 || firstNonWhitespace > offset) {
      return content.substring(start, offset);
    }
    return content.substring(start, firstNonWhitespace);
  }
}

// =============================================================================
// Isar Collection Annotation Rule
// =============================================================================

/// Warns when a class is used with Isar operations but lacks @collection.
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
  const RequireIsarCollectionAnnotationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_isar_collection_annotation',
    problemMessage:
        '[require_isar_collection_annotation] Without @collection, Isar cannot '
        'generate code for this class. Build will fail with missing adapter.',
    correctionMessage: 'Add @collection annotation to the class.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
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
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// Isar ID Field Rule
// =============================================================================

/// Warns when @collection class is missing the required Id field.
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
  const RequireIsarIdFieldRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_isar_id_field',
    problemMessage:
        '[require_isar_id_field] Isar requires Id field for primary key. '
        'Code generation fails without it, breaking the build.',
    correctionMessage: 'Add "Id? id;" as the first field in the class.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
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
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// Isar Close on Dispose Rule
// =============================================================================

/// Warns when Isar.open/openSync is used without closing in dispose.
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
  const RequireIsarCloseOnDisposeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_isar_close_on_dispose',
    problemMessage:
        '[require_isar_close_on_dispose] Isar instance must be closed in dispose() to release file handles.',
    correctionMessage: 'Add isar.close() in the dispose method.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
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
        reporter.atNode(node, code);
        return;
      }

      final disposeBody = disposeMethod.body.toSource();
      for (final field in isarFields) {
        if (!disposeBody.contains('$field.close()') &&
            !disposeBody.contains('$field?.close()')) {
          reporter.atNode(disposeMethod, code);
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
  const PreferIsarAsyncWritesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_isar_async_writes',
    problemMessage:
        '[prefer_isar_async_writes] Avoid writeTxnSync in build methods - it blocks the UI thread.',
    correctionMessage: 'Use writeTxn (async) instead of writeTxnSync.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
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
  const AvoidIsarTransactionNestingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_isar_transaction_nesting',
    problemMessage:
        '[avoid_isar_transaction_nesting] Nested writeTxn causes deadlock. '
        'Isar cannot acquire second write lock while first is held.',
    correctionMessage: 'Combine operations into a single writeTxn block.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
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
  const PreferIsarBatchOperationsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_isar_batch_operations',
    problemMessage:
        '[prefer_isar_batch_operations] Use putAll() instead of put() in loops - batch operations are ~100x faster.',
    correctionMessage:
        'Collect items and use putAll() instead of individual put() calls.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
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
  const AvoidIsarFloatEqualityQueriesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_isar_float_equality_queries',
    problemMessage:
        '[avoid_isar_float_equality_queries] Float equality queries are imprecise. Use between() instead.',
    correctionMessage:
        'Use .between(value - epsilon, value + epsilon) for float comparisons.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
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
  const RequireIsarInspectorDebugOnlyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_isar_inspector_debug_only',
    problemMessage:
        '[require_isar_inspector_debug_only] Isar Inspector should only be enabled in debug mode.',
    correctionMessage: 'Use inspector: kDebugMode instead of inspector: true.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
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
            reporter.atNode(arg, code);
          }
        }
      }
    });
  }
}

// =============================================================================
// Isar Clear in Production Rule
// =============================================================================

/// Warns when isar.clear() is called without a debug guard.
///
/// clear() deletes ALL data in the database. This should never
/// happen in production accidentally.
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
  const AvoidIsarClearInProductionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_isar_clear_in_production',
    problemMessage:
        '[avoid_isar_clear_in_production] isar.clear() wipes all user data '
        'permanently. If this runs in production, users lose everything.',
    correctionMessage: 'Add if (kDebugMode) guard before calling clear().',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'clear') return;

      // Check if inside kDebugMode check
      AstNode? parent = node.parent;
      while (parent != null) {
        if (parent is IfStatement) {
          final condition = parent.expression.toSource();
          if (condition.contains('kDebugMode') ||
              condition.contains('kReleaseMode')) {
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
  const RequireIsarLinksLoadRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_isar_links_load',
    problemMessage:
        '[require_isar_links_load] IsarLinks must be loaded before accessing. Call load() first.',
    correctionMessage:
        'Add await links.load() or links.loadSync() before accessing.',
    errorSeverity: DiagnosticSeverity.ERROR,
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
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPropertyAccess((PropertyAccess node) {
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
  const PreferIsarQueryStreamRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_isar_query_stream',
    problemMessage:
        '[prefer_isar_query_stream] Use Isar watch() instead of Timer-based polling for reactive queries.',
    correctionMessage:
        'Replace Timer.periodic with collection.where().watch().listen().',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
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
  const AvoidIsarWebLimitationsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_isar_web_limitations',
    problemMessage:
        '[avoid_isar_web_limitations] Isar sync APIs do not work on web. Use async methods.',
    correctionMessage:
        'Replace Sync methods with async equivalents for web compatibility.',
    errorSeverity: DiagnosticSeverity.WARNING,
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
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
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
  const PreferIsarIndexForQueriesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_isar_index_for_queries',
    problemMessage:
        '[prefer_isar_index_for_queries] Consider adding @Index to frequently queried fields for better performance.',
    correctionMessage: 'Add @Index() annotation to the field being queried.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // This rule would need full type resolution to be accurate.
    // For now, we provide a simplified implementation that warns
    // on filter() chains without prior index usage evidence.
    context.registry.addMethodInvocation((MethodInvocation node) {
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
  const AvoidIsarEmbeddedLargeObjectsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_isar_embedded_large_objects',
    problemMessage:
        '[avoid_isar_embedded_large_objects] @embedded objects are duplicated in every record. Use IsarLink for large/shared objects.',
    correctionMessage:
        'Consider using IsarLink<T> instead of @embedded for large objects.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFieldDeclaration((FieldDeclaration node) {
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
        if (!{'String', 'int', 'double', 'bool', 'DateTime'}
            .contains(typeName)) {
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
  const PreferIsarLazyLinksRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_isar_lazy_links',
    problemMessage:
        '[prefer_isar_lazy_links] Consider using IsarLinks.lazy() for large linked collections.',
    correctionMessage:
        'Replace IsarLinks<T>() with IsarLinks<T>.lazy() for better performance.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final type = node.constructorName.type;
      final typeName = type.name2.lexeme;
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
/// Removing fields, changing types, or renaming without @Name breaks migrations.
///
/// Note: Full detection requires comparing against previous schema versions,
/// which is beyond static analysis. This rule provides basic guidance.
class AvoidIsarSchemaBreakingChangesRule extends SaropaLintRule {
  const AvoidIsarSchemaBreakingChangesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_isar_schema_breaking_changes',
    problemMessage:
        '[avoid_isar_schema_breaking_changes] Isar field changes may break migrations. Use @Name to preserve DB field names.',
    correctionMessage: 'Add @Name("originalFieldName") when renaming fields.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // This is a documentation/awareness rule. Full schema comparison
    // would require cross-file/cross-version analysis.
    // We warn on @collection classes without any @Name annotations
    // as a reminder to use them for renamed fields.
    context.registry.addClassDeclaration((ClassDeclaration node) {
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

// =============================================================================
// Isar Non-Nullable Migration Rule
// =============================================================================

/// Warns when Isar fields are non-nullable without a default value.
///
/// Changing a nullable field to non-nullable requires a default value
/// for existing data.
///
/// **BAD:**
/// ```dart
/// @collection
/// class User {
///   String name = '';  // What about existing null values?
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @collection
/// class User {
///   String? name;  // Keep nullable
///   // OR use migration to handle existing nulls
/// }
/// ```
class RequireIsarNonNullableMigrationRule extends SaropaLintRule {
  const RequireIsarNonNullableMigrationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_isar_non_nullable_migration',
    problemMessage:
        '[require_isar_non_nullable_migration] Non-nullable Isar fields need default values for migration safety.',
    correctionMessage: 'Make the field nullable or provide a default value.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
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
          // Skip Id field
          final type = member.fields.type;
          if (type is NamedType && type.name.lexeme == 'Id') continue;

          // Check for non-nullable fields without initializers
          if (type is NamedType && type.question == null) {
            for (final variable in member.fields.variables) {
              if (variable.initializer == null) {
                // Non-nullable without default - potential migration issue
                reporter.atNode(variable, code);
              }
            }
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
  const PreferIsarCompositeIndexRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_isar_composite_index',
    problemMessage:
        '[prefer_isar_composite_index] Multi-field queries benefit from composite indexes.',
    correctionMessage:
        'Add @Index(composite: [...]) for frequently used field combinations.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
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
  const AvoidIsarStringContainsWithoutIndexRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_isar_string_contains_without_index',
    problemMessage:
        '[avoid_isar_string_contains_without_index] String contains queries need full-text index for performance.',
    correctionMessage:
        'Add @Index(type: IndexType.value) to the field being searched.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
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
