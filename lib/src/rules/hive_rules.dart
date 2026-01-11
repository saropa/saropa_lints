// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Hive database rules for Flutter applications.
///
/// These rules detect common Hive database anti-patterns, security issues,
/// and best practices violations.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

// =============================================================================
// Shared Utilities
// =============================================================================

/// Check if an expression target looks like a Hive box.
/// Uses word boundary matching to avoid false positives like 'infobox'.
bool _isHiveBoxTarget(Expression? target) {
  if (target == null) return false;

  final String source = target.toSource().toLowerCase();

  // Check for exact 'box' variable or common patterns like myBox, userBox
  // Use word boundary to avoid matching 'infobox', 'checkbox', etc.
  final boxPattern = RegExp(r'\bbox\b|box$|^box|_box');
  return boxPattern.hasMatch(source);
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
  final boxPattern = RegExp(r'\bbox$|_box\b|^box$');
  return boxPattern.hasMatch(nameLower);
}

// =============================================================================
// Hive Rules
// =============================================================================

/// Warns when Hive.openBox is called without verifying Hive.init was called.
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

  static const LintCode _code = LintCode(
    name: 'require_hive_initialization',
    problemMessage:
        'Hive.openBox called. Verify Hive.init() or Hive.initFlutter() is called in main().',
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

  static const LintCode _code = LintCode(
    name: 'require_hive_type_adapter',
    problemMessage:
        'Storing object in Hive. Ensure class has @HiveType annotation.',
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

  static const LintCode _code = LintCode(
    name: 'require_hive_box_close',
    problemMessage: 'Hive box opened but not closed in dispose. Resource leak.',
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

  static const LintCode _code = LintCode(
    name: 'prefer_hive_encryption',
    problemMessage: 'Sensitive data stored in unencrypted Hive box.',
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

  static const LintCode _code = LintCode(
    name: 'require_hive_encryption_key_secure',
    problemMessage:
        'Hardcoded Hive encryption key. Can be extracted from app binary.',
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

// =============================================================================
// ROADMAP_NEXT Part 7 Rules
// =============================================================================

/// Warns when @HiveType typeIds may conflict or change.
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

  static const LintCode _code = LintCode(
    name: 'require_hive_type_id_management',
    problemMessage:
        '@HiveType found. Ensure typeId is unique and documented in a central registry.',
    correctionMessage:
        'Create a hive_type_ids.dart file to track all typeIds and prevent conflicts.',
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
