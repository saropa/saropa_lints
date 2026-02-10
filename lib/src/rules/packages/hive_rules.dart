// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Hive database rules for Flutter applications.
///
/// These rules detect common Hive database anti-patterns, security issues,
/// and best practices violations.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../saropa_lint_rule.dart';
import '../../type_annotation_utils.dart';

// =============================================================================
// Shared Utilities
// =============================================================================

// Cached regex patterns for performance
final RegExp _boxTargetPattern = RegExp(r'\bbox\b|box$|^box|_box');
final RegExp _boxFieldPattern = RegExp(r'\bbox$|_box\b|^box$');

/// Check if an expression target looks like a Hive box.
/// Uses word boundary matching to avoid false positives like 'infobox'.
bool _isHiveBoxTarget(Expression? target) {
  if (target == null) return false;

  final String source = target.toSource().toLowerCase();

  // Check for exact 'box' variable or common patterns like myBox, userBox
  // Use word boundary to avoid matching 'infobox', 'checkbox', etc.
  return _boxTargetPattern.hasMatch(source);
}

/// Check if a field declaration or variable name indicates a Hive Box type.
bool _isHiveBoxField(String typeSource, String variableName) {
  final String typeLower = typeSource.toLowerCase();
  final String nameLower = variableName.toLowerCase();

  // Type contains Box (LazyBox, Box<T>, etc.)
  if (typeLower.contains('box<') || typeLower == 'box') {
    return true;
  }

  // Variable name ends with 'box' or contains '_box'
  return _boxFieldPattern.hasMatch(nameLower);
}

// =============================================================================
// Hive Rules
// =============================================================================

/// Warns when Hive.openBox is called without verifying Hive.init was called.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v4
///
/// Alias: hive_init_check, ensure_hive_initialized
///
/// Hive must be initialized before opening boxes. Forgetting to call
/// Hive.init() or Hive.initFlutter() causes runtime errors.
///
/// **BAD:**
/// ```dart
/// void main() async {
///   final box = await Hive.openBox('myBox'); // Crashes!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void main() async {
///   await Hive.initFlutter();
///   final box = await Hive.openBox('myBox');
/// }
/// ```
class RequireHiveInitializationRule extends SaropaLintRule {
  const RequireHiveInitializationRule() : super(code: _code);

  /// HEURISTIC: This rule cannot verify cross-file initialization.
  /// It serves as a reminder to ensure init is called somewhere.
  /// Impact is low since this is informational, not a definite bug.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_hive_initialization',
    problemMessage:
        '[require_hive_initialization] Hive.openBox() or Hive.openLazyBox() was called without a visible Hive.init() or Hive.initFlutter() call in this file. Opening a box before initialization throws a HiveError at runtime. {v4}',
    correctionMessage:
        'Call Hive.initFlutter() in main() before any openBox() calls. This rule cannot verify cross-file initialization, so suppress the warning if Hive.init() is called in a separate startup file.',
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
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: hive_type_adapter, hive_custom_type
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
        '@HiveType annotation. Storing will throw a HiveError at runtime. {v2}',
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
      if (!_isHiveBoxTarget(node.target)) return;

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
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: close_hive_box, hive_box_leak
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
        '[require_hive_box_close] Hive database box opened but not closed in dispose. This leaves file handles open, prevents database compaction, causes memory leaks, and can lead to data corruption or app crashes over time. Unclosed boxes may also block updates and degrade device performance. {v3}',
    correctionMessage:
        'Always call box.close() in dispose() or when the box is no longer needed. Audit all Hive usage for proper cleanup and add tests for resource management. Document cleanup logic for maintainability.',
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
            final String nameStr = variable.name.lexeme;

            if (_isHiveBoxField(typeStr, nameStr)) {
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
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: encrypt_hive_sensitive, hive_security
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
        'Anyone with device access can read sensitive user data. {v2}',
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

      // Check if target is a Hive box
      if (!_isHiveBoxTarget(node.target)) return;

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
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: hive_hardcoded_key, secure_hive_key
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
        'Anyone decompiling the app can decrypt all stored user data. {v2}',
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

/// Warns when database is opened but no close() method found.
///
/// Since: v1.7.8 | Updated: v4.13.0 | Rule version: v4
///
/// Alias: database_close, hive_database_leak
///
/// Database connections should be closed when no longer needed to
/// prevent resource leaks.
///
/// **BAD:**
/// ```dart
/// class MyService {
///   late Box _box;
///   Future<void> init() async {
///     _box = await Hive.openBox('data');
///   }
///   // No dispose method!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyService {
///   late Box _box;
///   Future<void> init() async {
///     _box = await Hive.openBox('data');
///   }
///   Future<void> dispose() async {
///     await _box.close();
///   }
/// }
/// ```
class RequireHiveDatabaseCloseRule extends SaropaLintRule {
  const RequireHiveDatabaseCloseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_hive_database_close',
    problemMessage:
        '[require_hive_database_close] Database opened but no close() method found. This creates a resource leak risk, leading to memory exhaustion, file locks, and possible data loss. Unclosed databases can prevent compaction and degrade app reliability. {v4}',
    correctionMessage:
        'Add a dispose() method that calls database.close(). Audit all database usage for proper closure and add tests for resource cleanup. Document disposal logic for maintainability.',
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
/// Since: v1.7.8 | Updated: v4.13.0 | Rule version: v3
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_type_adapter_registration',
    problemMessage:
        '[require_type_adapter_registration] Hive box opened with a custom type but the corresponding TypeAdapter may not be registered. Unregistered adapters cause HiveError at runtime, preventing all read and write operations on the box, which leads to app crashes and complete data inaccessibility. {v3}',
    correctionMessage:
        'Call Hive.registerAdapter() for every custom type before opening boxes that use it. Without registration, your app will crash or lose data when reading or writing.',
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
/// Since: v1.7.8 | Updated: v4.13.0 | Rule version: v4
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_lazy_box_for_large',
    problemMessage:
        '[prefer_lazy_box_for_large] Regular box loads all entries into memory at once. Regular boxes load all data into memory at open time. For large datasets, use lazy boxes that load values on demand. {v4}',
    correctionMessage:
        'Use Hive.openLazyBox() for collections that may grow large. Verify the change works correctly with existing tests and add coverage for the new behavior.',
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

// =============================================================================
// ROADMAP_NEXT Part 7 Rules
// =============================================================================

/// Warns when @HiveType typeIds may conflict or change.
///
/// Since: v2.3.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: hive_type_id, manage_hive_type_ids
///
/// Hive typeIds must be unique and stable. Changing or duplicating typeIds
/// corrupts stored data. Track typeIds in a central registry.
///
/// **BAD:**
/// ```dart
/// @HiveType(typeId: 0) // Same as User!
/// class Settings extends HiveObject { ... }
///
/// @HiveType(typeId: 0)
/// class User extends HiveObject { ... }
/// ```
///
/// **GOOD:**
/// ```dart
/// // In hive_type_ids.dart:
/// // 0 = User
/// // 1 = Settings
/// // 2 = Product
///
/// @HiveType(typeId: 0)
/// class User extends HiveObject { ... }
///
/// @HiveType(typeId: 1)
/// class Settings extends HiveObject { ... }
/// ```
class RequireHiveTypeIdManagementRule extends SaropaLintRule {
  const RequireHiveTypeIdManagementRule() : super(code: _code);

  // INFO severity - advisory rule to encourage documentation, not a crash risk
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_hive_type_id_management',
    problemMessage:
        '[require_hive_type_id_management] @HiveType found. Ensure typeId is unique and documented in a central registry. Hive typeIds must be unique and stable. Changing or duplicating typeIds corrupts stored data. Track typeIds in a central registry. {v2}',
    correctionMessage:
        'Create a hive_type_ids.dart file to track all typeIds and prevent conflicts. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAnnotation((Annotation node) {
      final String annotationName = node.name.name;
      if (annotationName != 'HiveType') return;

      // Check if there's a comment above documenting the typeId
      final AstNode? parent = node.parent;
      if (parent is ClassDeclaration) {
        final String? docComment = parent.documentationComment?.toSource();
        if (docComment != null &&
            (docComment.contains('typeId') ||
                docComment.contains('type_id') ||
                docComment.contains('Hive type'))) {
          return; // Has documentation
        }
      }

      // Check if in a file that looks like a registry
      final String filePath = resolver.source.fullName.toLowerCase();
      if (filePath.contains('type_id') ||
          filePath.contains('hive_type') ||
          filePath.contains('registry')) {
        return; // Already in a registry file
      }

      reporter.atNode(node, code);
    });
  }
}

/// Warns when @HiveField indices are reused within the same class.
///
/// Since: v2.3.9 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: hive_field_duplicate, hive_field_conflict
///
/// @HiveField indices must be unique within a class. Reusing an index
/// causes data corruption as Hive cannot distinguish between fields.
///
/// **BAD:**
/// ```dart
/// @HiveType(typeId: 0)
/// class User extends HiveObject {
///   @HiveField(0)
///   final String name;
///
///   @HiveField(0) // Duplicate index!
///   final String email;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @HiveType(typeId: 0)
/// class User extends HiveObject {
///   @HiveField(0)
///   final String name;
///
///   @HiveField(1)
///   final String email;
/// }
/// ```
class AvoidHiveFieldIndexReuseRule extends SaropaLintRule {
  const AvoidHiveFieldIndexReuseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_hive_field_index_reuse',
    problemMessage:
        '[avoid_hive_field_index_reuse] Reusing Hive field indexes across different fields or types can corrupt your database, cause data loss, and make migrations impossible. This can result in users losing critical data or experiencing app crashes after updates. Always assign unique field indexes and never change them after release. See https://docs.hivedb.dev/#/adapters/fields. {v3}',
    correctionMessage:
        'Ensure each Hive field has a unique, immutable index and avoid reusing or changing indexes after deployment. See https://docs.hivedb.dev/#/adapters/fields for guidance.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if this is a HiveType class
      bool isHiveType = false;
      for (final metadata in node.metadata) {
        if (metadata.name.name == 'HiveType') {
          isHiveType = true;
          break;
        }
      }

      if (!isHiveType) return;

      // Collect all @HiveField indices and their annotations
      final Map<int, List<Annotation>> fieldIndices = <int, List<Annotation>>{};

      for (final member in node.members) {
        if (member is FieldDeclaration) {
          for (final metadata in member.metadata) {
            if (metadata.name.name == 'HiveField') {
              final int? index = _extractHiveFieldIndex(metadata);
              if (index != null) {
                fieldIndices.putIfAbsent(index, () => <Annotation>[]);
                fieldIndices[index]!.add(metadata);
              }
            }
          }
        }
      }

      // Report duplicates
      for (final entry in fieldIndices.entries) {
        if (entry.value.length > 1) {
          // Report all occurrences of the duplicate
          for (final annotation in entry.value) {
            reporter.atNode(annotation, code);
          }
        }
      }
    });
  }

  /// Extracts the index value from a @HiveField annotation.
  int? _extractHiveFieldIndex(Annotation annotation) {
    final ArgumentList? args = annotation.arguments;
    if (args == null || args.arguments.isEmpty) return null;

    final Expression firstArg = args.arguments.first;
    if (firstArg is IntegerLiteral) {
      return firstArg.value;
    }

    return null;
  }
}

// =============================================================================
// NEW RULES v2.3.11
// =============================================================================

/// Warns when @HiveField on nullable fields lacks defaultValue.
///
/// Since: v2.3.11 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: hive_field_default, hive_migration_safe, hive_nullable_field
///
/// When adding new nullable fields to existing Hive types, they need
/// defaultValue for existing data that was stored before the field existed.
///
/// **BAD:**
/// ```dart
/// @HiveType(typeId: 1)
/// class User {
///   @HiveField(0)
///   String? nickname; // Existing data won't have this field!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @HiveType(typeId: 1)
/// class User {
///   @HiveField(0, defaultValue: null)
///   String? nickname; // Safe for existing data
/// }
/// ```
class RequireHiveFieldDefaultValueRule extends SaropaLintRule {
  const RequireHiveFieldDefaultValueRule() : super(code: _code);

  /// Missing defaults cause crashes when reading existing data.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_hive_field_default_value',
    problemMessage:
        '[require_hive_field_default_value] @HiveField on nullable field without defaultValue. This can cause existing data to fail to load, trigger runtime exceptions, and break migrations. Missing defaults may result in silent data loss or corrupted records after schema changes. {v2}',
    correctionMessage:
        'Add defaultValue parameter: @HiveField(0, defaultValue: ...) for all nullable fields. Audit schema migrations for missing defaults and add tests for data integrity. Document migration logic for maintainability.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      // Check if field has @HiveField annotation
      final Annotation? hiveFieldAnnotation =
          node.metadata.cast<Annotation?>().firstWhere(
                (Annotation? a) => a?.name.name == 'HiveField',
                orElse: () => null,
              );

      if (hiveFieldAnnotation == null) return;

      // Check if the type is nullable
      final TypeAnnotation? type = node.fields.type;
      if (type == null) return;

      // Check if outer type is nullable
      if (!isOuterTypeNullable(type)) return;

      // Check if defaultValue is provided
      final ArgumentList? args = hiveFieldAnnotation.arguments;
      if (args == null) {
        reporter.atNode(hiveFieldAnnotation, code);
        return;
      }

      final bool hasDefaultValue = args.arguments.any((Expression arg) {
        if (arg is NamedExpression) {
          return arg.name.label.name == 'defaultValue';
        }
        return false;
      });

      if (!hasDefaultValue) {
        reporter.atNode(hiveFieldAnnotation, code);
      }
    });
  }
}

/// Warns when Hive.openBox is called before registering all adapters.
///
/// Since: v2.3.11 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: hive_adapter_order, hive_register_before_open
///
/// TypeAdapters must be registered before opening boxes that use them.
/// Opening a box before registering the adapter causes a runtime error.
///
/// **BAD:**
/// ```dart
/// void main() async {
///   await Hive.initFlutter();
///   final box = await Hive.openBox<User>('users'); // Crash!
///   Hive.registerAdapter(UserAdapter()); // Too late
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void main() async {
///   await Hive.initFlutter();
///   Hive.registerAdapter(UserAdapter());
///   final box = await Hive.openBox<User>('users');
/// }
/// ```
class RequireHiveAdapterRegistrationOrderRule extends SaropaLintRule {
  const RequireHiveAdapterRegistrationOrderRule() : super(code: _code);

  /// Wrong order causes runtime crash.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_hive_adapter_registration_order',
    problemMessage:
        '[require_hive_adapter_registration_order] Opening box before registering '
        'adapters throws HiveError. Adapters must be registered first. {v2}',
    correctionMessage:
        'Ensure all Hive.registerAdapter() calls appear before Hive.openBox().',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionBody((FunctionBody body) {
      if (body is! BlockFunctionBody) return;

      int? firstOpenBoxLine;
      int? lastRegisterAdapterLine;
      MethodInvocation? openBoxNode;

      // Collect line numbers for openBox and registerAdapter
      body.accept(_HiveOrderVisitor(
        onOpenBox: (MethodInvocation node) {
          final int line = node.offset;
          if (firstOpenBoxLine == null || line < firstOpenBoxLine!) {
            firstOpenBoxLine = line;
            openBoxNode = node;
          }
        },
        onRegisterAdapter: (MethodInvocation node) {
          final int line = node.offset;
          if (lastRegisterAdapterLine == null ||
              line > lastRegisterAdapterLine!) {
            lastRegisterAdapterLine = line;
          }
        },
      ));

      // If registerAdapter appears after openBox, report
      if (firstOpenBoxLine != null &&
          lastRegisterAdapterLine != null &&
          lastRegisterAdapterLine! > firstOpenBoxLine! &&
          openBoxNode != null) {
        reporter.atNode(openBoxNode!, code);
      }
    });
  }
}

class _HiveOrderVisitor extends RecursiveAstVisitor<void> {
  _HiveOrderVisitor({
    required this.onOpenBox,
    required this.onRegisterAdapter,
  });

  final void Function(MethodInvocation) onOpenBox;
  final void Function(MethodInvocation) onRegisterAdapter;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String methodName = node.methodName.name;
    final Expression? target = node.target;

    if (target is SimpleIdentifier && target.name == 'Hive') {
      if (methodName.startsWith('openBox') ||
          methodName.startsWith('openLazyBox')) {
        onOpenBox(node);
      } else if (methodName == 'registerAdapter') {
        onRegisterAdapter(node);
      }
    }

    super.visitMethodInvocation(node);
  }
}

/// Warns when nested objects in @HiveType don't have their own adapters.
///
/// Since: v2.3.11 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: hive_nested_adapter, hive_custom_field_type
///
/// Hive can't serialize nested objects unless they have TypeAdapters too.
/// Each custom class used as a field needs @HiveType annotation.
///
/// **BAD:**
/// ```dart
/// @HiveType(typeId: 1)
/// class User {
///   @HiveField(0)
///   Address address; // Address has no TypeAdapter!
/// }
/// class Address { ... } // Missing @HiveType
/// ```
///
/// **GOOD:**
/// ```dart
/// @HiveType(typeId: 1)
/// class User {
///   @HiveField(0)
///   Address address;
/// }
/// @HiveType(typeId: 2)
/// class Address { ... }
/// ```
class RequireHiveNestedObjectAdapterRule extends SaropaLintRule {
  const RequireHiveNestedObjectAdapterRule() : super(code: _code);

  /// Missing nested adapter causes runtime crash.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_hive_nested_object_adapter',
    problemMessage:
        '[require_hive_nested_object_adapter] Nested custom type without adapter '
        'causes runtime crash when Hive tries to serialize the object. {v2}',
    correctionMessage:
        'Add @HiveType annotation to the nested class or use a primitive type.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// Primitive types that don't need adapters.
  static const Set<String> _primitiveTypes = <String>{
    'String',
    'int',
    'double',
    'bool',
    'num',
    'DateTime',
    'Uint8List',
    'List',
    'Map',
    'Set',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      // Check if field has @HiveField annotation
      final bool hasHiveField = node.metadata.any(
        (Annotation a) => a.name.name == 'HiveField',
      );

      if (!hasHiveField) return;

      // Check if the type is a custom class
      final TypeAnnotation? type = node.fields.type;
      if (type == null) return;

      // Extract base type name via AST for reliable primitive check
      if (type is! NamedType) return;
      final String baseType = type.name.lexeme;

      // If it's not a primitive, warn
      if (!_primitiveTypes.contains(baseType)) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when duplicate Hive box names are used.
///
/// Since: v2.3.11 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: hive_box_name_unique, hive_duplicate_box
///
/// Box names must be unique across the application. Using the same name
/// for different types causes data corruption or type errors.
///
/// **BAD:**
/// ```dart
/// // In users_service.dart
/// final usersBox = await Hive.openBox<User>('data');
/// // In settings_service.dart
/// final settingsBox = await Hive.openBox<Settings>('data'); // Same name!
/// ```
///
/// **GOOD:**
/// ```dart
/// final usersBox = await Hive.openBox<User>('users');
/// final settingsBox = await Hive.openBox<Settings>('settings');
/// ```
class AvoidHiveBoxNameCollisionRule extends SaropaLintRule {
  const AvoidHiveBoxNameCollisionRule() : super(code: _code);

  /// HEURISTIC: This rule checks for common generic box names
  /// that are likely to cause collisions. Cross-file detection
  /// requires static analysis of the entire codebase.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_hive_box_name_collision',
    problemMessage:
        '[avoid_hive_box_name_collision] Generic Hive box name may cause collision. Use a specific name. Box names must be unique across the application. Using the same name for different types causes data corruption or type errors. {v2}',
    correctionMessage:
        'Use a unique, descriptive box name like "users" or "settings". Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Common generic names that are likely to cause collisions.
  static const Set<String> _genericNames = <String>{
    'data',
    'box',
    'cache',
    'store',
    'db',
    'database',
    'storage',
    'main',
    'default',
    'app',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!methodName.startsWith('openBox') &&
          !methodName.startsWith('openLazyBox')) {
        return;
      }

      // Check if target is Hive
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Hive') return;

      // Get the box name argument
      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      if (firstArg is! SimpleStringLiteral) return;

      final String boxName = firstArg.value.toLowerCase();
      if (_genericNames.contains(boxName)) {
        reporter.atNode(firstArg, code);
      }
    });
  }
}

// =============================================================================
// prefer_hive_value_listenable
// =============================================================================

/// Use box.listenable() with ValueListenableBuilder for reactive UI.
///
/// Since: v2.6.0 | Updated: v4.13.0 | Rule version: v3
///
/// Manually calling setState after Hive updates is error-prone.
/// Use ValueListenableBuilder with box.listenable() for reactive updates.
///
/// **BAD:**
/// ```dart
/// void _saveItem(Item item) async {
///   await box.put(item.id, item);
///   setState(() {});  // Manual!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// ValueListenableBuilder(
///   valueListenable: box.listenable(),
///   builder: (context, Box<Item> box, _) {
///     return ListView(children: box.values.map(...).toList());
///   },
/// )
/// ```
class PreferHiveValueListenableRule extends SaropaLintRule {
  const PreferHiveValueListenableRule() : super(code: _code);

  /// UI may not update after Hive changes.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_hive_value_listenable',
    problemMessage:
        '[prefer_hive_value_listenable] Manual setState after Hive changes is error-prone. Manually calling setState after Hive updates is error-prone. Use ValueListenableBuilder with box.listenable() for reactive updates. {v3}',
    correctionMessage:
        'Use ValueListenableBuilder with box.listenable() for reactive UI. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'setState') return;

      // Look for Hive operations in the same function body
      final FunctionBody? body = node.thisOrAncestorOfType<FunctionBody>();
      if (body == null) return;

      final String bodySource = body.toSource();

      // Check for Hive put/delete operations
      if ((bodySource.contains('.put(') ||
              bodySource.contains('.delete(') ||
              bodySource.contains('.add(') ||
              bodySource.contains('.putAll(') ||
              bodySource.contains('.deleteAll(')) &&
          (bodySource.contains('box') || bodySource.contains('Box'))) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// NEW ROADMAP STAR RULES - Hive/SharedPrefs Rules
// =============================================================================

/// Warns when Box is used instead of LazyBox for potentially large collections.
///
/// Since: v4.1.4 | Updated: v4.13.0 | Rule version: v3
///
/// LazyBox loads entries on-demand, avoiding memory issues with large datasets.
/// Regular Box loads all entries into memory at once.
///
/// **BAD:**
/// ```dart
/// late Box<Message> messagesBox;
/// // If messagesBox has 100,000 entries, all are loaded into memory!
/// ```
///
/// **GOOD:**
/// ```dart
/// late LazyBox<Message> messagesBox;
/// // Entries loaded on-demand, memory-efficient
/// ```
class PreferHiveLazyBoxRule extends SaropaLintRule {
  const PreferHiveLazyBoxRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_hive_lazy_box',
    problemMessage:
        '[prefer_hive_lazy_box] Consider using LazyBox for potentially large '
        'collections. Regular Box loads all entries into memory. {v3}',
    correctionMessage:
        'Use Hive.openLazyBox() instead of Hive.openBox() for large datasets.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check for field declarations with Box<T> type
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      final String? typeName = node.fields.type?.toSource();
      if (typeName == null) return;

      // Check for Box<T> but not LazyBox<T>
      if (typeName.startsWith('Box<') && !typeName.contains('Lazy')) {
        // Heuristic: warn if the type suggests a collection
        // (messages, items, logs, history, etc.)
        for (final variable in node.fields.variables) {
          final name = variable.name.lexeme.toLowerCase();
          if (_suggestsLargeCollection(name)) {
            reporter.atNode(variable, code);
          }
        }
      }
    });

    // Also check for Hive.openBox calls
    context.registry.addMethodInvocation((MethodInvocation node) {
      final target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Hive') return;

      if (node.methodName.name != 'openBox') return;

      // Check the box name argument
      final args = node.argumentList.arguments;
      if (args.isNotEmpty) {
        final firstArg = args.first;
        if (firstArg is StringLiteral) {
          final boxName = firstArg.stringValue?.toLowerCase() ?? '';
          if (_suggestsLargeCollection(boxName)) {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }

  bool _suggestsLargeCollection(String name) {
    const largeCollectionHints = <String>[
      'message',
      'chat',
      'log',
      'history',
      'event',
      'notification',
      'item',
      'record',
      'cache',
      'data',
      'entry',
      'transaction',
    ];
    return largeCollectionHints.any((hint) => name.contains(hint));
  }

  @override
  List<Fix> getFixes() => [_PreferHiveLazyBoxFix()];
}

/// Quick fix for [PreferHiveLazyBoxRule].
///
/// Replaces `Hive.openBox()` with `Hive.openLazyBox()` for better memory
/// efficiency with large collections. LazyBox loads entries on demand rather
/// than loading everything into memory at once.
class _PreferHiveLazyBoxFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Hive') return;
      if (node.methodName.name != 'openBox') return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Replace openBox with openLazyBox',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.methodName.sourceRange,
          'openLazyBox',
        );
      });
    });
  }
}

/// Warns when Uint8List or binary data is stored in Hive.
///
/// Since: v4.1.4 | Updated: v4.13.0 | Rule version: v2
///
/// Hive is not optimized for large binary data. Store file paths instead
/// and keep binary data in the file system.
///
/// **BAD:**
/// ```dart
/// @HiveType(typeId: 0)
/// class Photo {
///   @HiveField(0)
///   Uint8List imageBytes; // Large binary data in Hive!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @HiveType(typeId: 0)
/// class Photo {
///   @HiveField(0)
///   String imagePath; // Store path, not bytes
/// }
/// ```
class AvoidHiveBinaryStorageRule extends SaropaLintRule {
  const AvoidHiveBinaryStorageRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_hive_binary_storage',
    problemMessage:
        '[avoid_hive_binary_storage] Storing Uint8List/binary data in Hive. '
        'This degrades performance for large files. {v2}',
    correctionMessage:
        'Store file paths instead and keep binary data in the file system.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _binaryTypes = <String>{
    'Uint8List',
    'List<int>',
    'ByteData',
    'ByteBuffer',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if class has @HiveType annotation
      bool isHiveType = false;
      for (final annotation in node.metadata) {
        if (annotation.name.name == 'HiveType') {
          isHiveType = true;
          break;
        }
      }

      if (!isHiveType) return;

      // Check fields for binary types
      for (final member in node.members) {
        if (member is FieldDeclaration) {
          final typeName = member.fields.type?.toSource();
          if (typeName != null &&
              _binaryTypes.any((t) => typeName.contains(t))) {
            for (final variable in member.fields.variables) {
              reporter.atNode(variable, code);
            }
          }
        }
      }
    });
  }
}

// =============================================================================
// require_hive_migration_strategy
// =============================================================================

/// Warns when @HiveType class is modified without migration strategy.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: hive_migration, hive_schema_change
///
/// Adding/removing/reordering @HiveField annotations breaks existing data.
/// Document migration strategy or use defaultValue for new fields.
///
/// **BAD:**
/// ```dart
/// // Version 2 - removed email, renamed name to fullName
/// @HiveType(typeId: 0)
/// class User {
///   @HiveField(0) // Was 'name', now 'fullName' - data corrupted!
///   final String fullName;
///   // email field removed - existing data orphaned
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Version 2 - properly migrated
/// @HiveType(typeId: 0)
/// class User {
///   @HiveField(0) // Keep original index for 'name'
///   final String name;
///
///   @HiveField(2, defaultValue: '') // New field with default
///   final String fullName;
///
///   @HiveField(1) // Keep email field index even if not used
///   @Deprecated('Use newEmail instead')
///   final String? email;
/// }
///
/// // Or create a new type with migration
/// @HiveType(typeId: 1) // New typeId for breaking changes
/// class UserV2 { ... }
/// ```
class RequireHiveMigrationStrategyRule extends SaropaLintRule {
  const RequireHiveMigrationStrategyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_hive_migration_strategy',
    problemMessage:
        '[require_hive_migration_strategy] @HiveType with gaps in @HiveField '
        'indices. This suggests fields were removed without migration. {v2}',
    correctionMessage:
        'Keep all @HiveField indices even for removed fields, or create new typeId for breaking changes.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if this is a HiveType class
      bool isHiveType = false;
      for (final annotation in node.metadata) {
        if (annotation.name.name == 'HiveType') {
          isHiveType = true;
          break;
        }
      }

      if (!isHiveType) return;

      // Collect all @HiveField indices
      final List<int> indices = <int>[];

      for (final member in node.members) {
        if (member is FieldDeclaration) {
          for (final annotation in member.metadata) {
            if (annotation.name.name == 'HiveField') {
              final index = _extractHiveFieldIndex(annotation);
              if (index != null) {
                indices.add(index);
              }
            }
          }
        }
      }

      if (indices.isEmpty) return;

      // Sort and check for gaps
      indices.sort();

      // Check for gaps in indices (suggests removed fields)
      for (int i = 0; i < indices.length - 1; i++) {
        if (indices[i + 1] - indices[i] > 1) {
          // Gap found - might indicate removed field without migration
          reporter.atNode(node, code);
          return;
        }
      }

      // Check if indices don't start at 0 (suggests early fields removed)
      if (indices.isNotEmpty && indices.first > 0) {
        reporter.atNode(node, code);
      }
    });
  }

  int? _extractHiveFieldIndex(Annotation annotation) {
    final args = annotation.arguments;
    if (args == null || args.arguments.isEmpty) return null;

    final firstArg = args.arguments.first;
    if (firstArg is IntegerLiteral) {
      return firstArg.value;
    }

    return null;
  }
}

// =============================================================================
// Hive Synchronous in UI Rules
// =============================================================================

/// Warns when synchronous Hive box operations (get, put, delete, add) are
///
/// Since: v4.12.0 | Updated: v4.13.0 | Rule version: v2
///
/// called inside build() or initState() methods.
///
/// Hive synchronous operations perform disk I/O on the main thread. In
/// build() this blocks frame rendering; in initState() it delays widget
/// display. Both cause UI jank and ANR (Application Not Responding) dialogs.
///
/// **BAD:**
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   final name = box.get('name'); // Blocks UI rendering!
///   return Text(name ?? 'Unknown');
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// String? _name;
///
/// @override
/// void initState() {
///   super.initState();
///   _loadName();
/// }
///
/// Future<void> _loadName() async {
///   final name = await compute((_) => box.get('name'), null);
///   setState(() => _name = name);
/// }
/// ```
class AvoidHiveSynchronousInUiRule extends SaropaLintRule {
  const AvoidHiveSynchronousInUiRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_hive_synchronous_in_ui',
    problemMessage:
        '[avoid_hive_synchronous_in_ui] Synchronous Hive box operation (get, put, delete, add) is called inside a build() or initState() method. These operations perform disk I/O on the main isolate, blocking frame rendering and causing visible UI jank. On slower devices or with large boxes, this can trigger ANR (Application Not Responding) dialogs, force-close the app, and create a poor user experience that leads to negative app store reviews. {v2}',
    correctionMessage:
        'Move the Hive operation to an async method and use setState() or a state management solution to update the UI when the data is ready. For large operations, use compute() or Isolate.run() to offload to a background isolate.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Hive box methods that perform synchronous I/O.
  static const Set<String> _syncHiveMethods = <String>{
    'get',
    'getAt',
    'put',
    'putAt',
    'putAll',
    'add',
    'addAll',
    'delete',
    'deleteAt',
    'deleteAll',
    'clear',
    'compact',
  };

  /// UI lifecycle methods where sync I/O should be avoided.
  static const Set<String> _uiMethods = <String>{
    'build',
    'initState',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!_syncHiveMethods.contains(node.methodName.name)) return;

      // Check if target looks like a Hive box
      if (!_isHiveBoxTarget(node.target)) return;

      // Check if inside build() or initState()
      AstNode? current = node.parent;
      while (current != null) {
        if (current is MethodDeclaration &&
            _uiMethods.contains(current.name.lexeme)) {
          reporter.atNode(node, code);
          return;
        }
        current = current.parent;
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_WrapHiveInAsyncCommentFix()];
}

class _WrapHiveInAsyncCommentFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Add TODO: move Hive operation to async method',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '/* TODO: move to async method or use compute() */ ',
        );
      });
    });
  }
}

// =============================================================================
// require_hive_web_subdirectory
// =============================================================================

/// Warns when Hive.initFlutter() is called without a subDir parameter on
///
/// Since: v4.14.0 | Rule version: v2
///
/// web platform.
///
/// Alias: hive_web_subdir, hive_web_init
///
/// On web, Hive stores data in IndexedDB. Without an explicit subDir,
/// multiple apps on the same domain share the same Hive storage, causing
/// data conflicts and overwrites. Always specify a subDir unique to your app.
///
/// **BAD:**
/// ```dart
/// await Hive.initFlutter(); // No subDir - shared storage on web!
/// ```
///
/// **GOOD:**
/// ```dart
/// await Hive.initFlutter('my_app_data');
/// ```
class RequireHiveWebSubdirectoryRule extends SaropaLintRule {
  const RequireHiveWebSubdirectoryRule() : super(code: _code);

  /// Missing subDir causes data conflicts between web apps on same domain.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_hive_web_subdirectory',
    problemMessage:
        '[require_hive_web_subdirectory] Hive.initFlutter() called without a '
        'subDir parameter. On web platforms, Hive stores data in IndexedDB. '
        'Without an explicit subdirectory, multiple apps deployed on the same '
        'domain will share the same Hive storage namespace, causing data '
        'conflicts, overwrites, and potential data loss between applications. '
        'This is especially critical for web deployments. {v2}',
    correctionMessage:
        'Pass a unique subdirectory name to Hive.initFlutter(), e.g., '
        "Hive.initFlutter('my_app_data'). Use your app's package name or a "
        'unique identifier to avoid storage conflicts.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for initFlutter method
      if (node.methodName.name != 'initFlutter') return;

      // Check if target is Hive
      final Expression? target = node.target;
      if (target == null) return;
      if (target is! SimpleIdentifier || target.name != 'Hive') return;

      // Check if subDir argument is provided
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) {
        // No arguments at all - missing subDir
        reporter.atNode(node, code);
        return;
      }

      // Check if first positional arg is a non-empty string
      final Expression firstArg = args.first;
      if (firstArg is StringLiteral) {
        final String? value = firstArg.stringValue;
        if (value == null || value.isEmpty) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddHiveSubDirFix()];
}

class _AddHiveSubDirFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.methodName.name != 'initFlutter') return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Add subdirectory parameter',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          "Hive.initFlutter('my_app_data')",
        );
      });
    });
  }
}
