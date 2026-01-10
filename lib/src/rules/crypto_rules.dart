// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Cryptography and security rules for Flutter/Dart applications.
///
/// These rules detect common cryptographic mistakes that can
/// lead to security vulnerabilities.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when encryption keys appear to be hardcoded.
///
/// Hardcoded encryption keys in source code can be extracted from
/// compiled applications (APK, IPA). Keys should be stored securely
/// or derived at runtime.
///
/// **BAD:**
/// ```dart
/// final key = encrypt.Key.fromUtf8('my-secret-key-123');
/// final encrypter = Encrypter(AES(key));
/// ```
///
/// **GOOD:**
/// ```dart
/// // Load from secure storage
/// final keyString = await secureStorage.read(key: 'encryption_key');
/// final key = encrypt.Key.fromUtf8(keyString!);
///
/// // Or derive from user password
/// final key = deriveKey(password, salt);
/// ```
class AvoidHardcodedEncryptionKeysRule extends SaropaLintRule {
  const AvoidHardcodedEncryptionKeysRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_encryption_keys',
    problemMessage:
        'Hardcoded encryption key can be extracted from compiled app.',
    correctionMessage: 'Load key from secure storage or derive at runtime.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _keyMethods = <String>{
    'fromUtf8',
    'fromBase64',
    'fromBase16',
    'fromSecureRandom',
    'fromLength',
  };

  static const Set<String> _keyClasses = <String>{
    'Key',
    'SecretKey',
    'EncryptionKey',
    'AesKey',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (!_keyMethods.contains(methodName)) return;

      // Check if it's on a Key-like class
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      bool isKeyClass = false;
      for (final String keyClass in _keyClasses) {
        if (targetSource.contains(keyClass)) {
          isKeyClass = true;
          break;
        }
      }

      if (!isKeyClass) return;

      // Check if argument is a string literal
      if (node.argumentList.arguments.isNotEmpty) {
        final Expression firstArg = node.argumentList.arguments.first;
        if (firstArg is StringLiteral) {
          reporter.atNode(firstArg, code);
        }
      }
    });

    // Also check for direct key assignments
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      // Check variable name patterns
      final String varName = node.name.lexeme.toLowerCase();
      if (!varName.contains('key') &&
          !varName.contains('secret') &&
          !varName.contains('password')) {
        return;
      }

      // Check if initialized with a string literal
      final Expression? initializer = node.initializer;
      if (initializer is StringLiteral) {
        final String value = initializer.toSource();
        // Skip short strings that are likely not keys
        if (value.length > 10) {
          reporter.atNode(initializer, code);
        }
      }
    });
  }
}

/// Warns when Random() is used for cryptographic purposes.
///
/// Random() uses a predictable PRNG that can be reverse-engineered.
/// Use Random.secure() for any security-sensitive random generation.
///
/// **BAD:**
/// ```dart
/// final random = Random();
/// final iv = List.generate(16, (_) => random.nextInt(256));
/// ```
///
/// **GOOD:**
/// ```dart
/// final random = Random.secure();
/// final iv = List.generate(16, (_) => random.nextInt(256));
/// ```
class PreferSecureRandomForCryptoRule extends SaropaLintRule {
  const PreferSecureRandomForCryptoRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'prefer_secure_random_for_crypto',
    problemMessage:
        'Random() is predictable. Use Random.secure() for security.',
    correctionMessage:
        'Replace Random() with Random.secure() for cryptographic use.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name2.lexeme;
      final String? constructorName = node.constructorName.name?.name;

      // Only flag Random() without .secure()
      if (typeName != 'Random') return;
      if (constructorName == 'secure') return;

      // Check if used in security-related context
      // Look at variable name or usage patterns
      AstNode? current = node.parent;
      while (current != null) {
        if (current is VariableDeclaration) {
          final String varName = current.name.lexeme.toLowerCase();
          if (_securityIndicators.any((s) => varName.contains(s))) {
            reporter.atNode(node, code);
            return;
          }
        }
        if (current is MethodDeclaration) {
          final String methodName = current.name.lexeme.toLowerCase();
          if (_securityIndicators.any((s) => methodName.contains(s))) {
            reporter.atNode(node, code);
            return;
          }
        }
        current = current.parent;
      }
    });
  }

  static const List<String> _securityIndicators = <String>[
    'encrypt',
    'decrypt',
    'key',
    'iv',
    'nonce',
    'salt',
    'token',
    'secret',
    'hash',
    'sign',
    'auth',
    'password',
    'credential',
    'cipher',
  ];

  @override
  List<Fix> getFixes() => <Fix>[_UseSecureRandomFix()];
}

class _UseSecureRandomFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Use Random.secure()',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          'Random.secure()',
        );
      });
    });
  }
}

/// Warns when deprecated cryptographic algorithms are used.
///
/// MD5 and SHA1 are broken for security purposes. DES and 3DES
/// are also deprecated. Use modern algorithms instead.
///
/// **BAD:**
/// ```dart
/// final hash = md5.convert(utf8.encode(data));
/// final hash = sha1.convert(utf8.encode(data));
/// ```
///
/// **GOOD:**
/// ```dart
/// final hash = sha256.convert(utf8.encode(data));
/// // Or use SHA-512, HMAC, bcrypt, Argon2 for passwords
/// ```
class AvoidDeprecatedCryptoAlgorithmsRule extends SaropaLintRule {
  const AvoidDeprecatedCryptoAlgorithmsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'avoid_deprecated_crypto_algorithms',
    problemMessage:
        'Deprecated cryptographic algorithm. Use SHA-256 or stronger.',
    correctionMessage:
        'Replace MD5/SHA1 with SHA-256+. Replace DES with AES-256.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _deprecatedAlgorithms = <String>{
    'md5',
    'MD5',
    'sha1',
    'SHA1',
    'des',
    'DES',
    '3des',
    'TripleDES',
    'rc4',
    'RC4',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check for method invocations like md5.convert()
    context.registry.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target is SimpleIdentifier) {
        final String targetName = target.name;
        if (_deprecatedAlgorithms.contains(targetName)) {
          reporter.atNode(target, code);
        }
      }
    });

    // Check for constructor calls like MD5()
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name2.lexeme;
      if (_deprecatedAlgorithms.contains(typeName)) {
        reporter.atNode(node, code);
      }
    });

    // Check for prefixed identifiers like crypto.md5
    context.registry.addPrefixedIdentifier((PrefixedIdentifier node) {
      final String identifierName = node.identifier.name;
      if (_deprecatedAlgorithms.contains(identifierName)) {
        reporter.atNode(node.identifier, code);
      }
    });
  }
}

/// Warns when static or reused IVs are detected in encryption.
///
/// Reusing an IV (Initialization Vector) with the same key breaks
/// the security of most encryption modes. Each encryption operation
/// should use a unique, randomly generated IV.
///
/// **BAD:**
/// ```dart
/// static final iv = IV.fromLength(16);  // Static IV!
///
/// String encrypt(String data) {
///   return encrypter.encrypt(data, iv: iv).base64;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// String encrypt(String data) {
///   final iv = IV.fromSecureRandom(16);  // Fresh IV each time
///   final encrypted = encrypter.encrypt(data, iv: iv);
///   return '${iv.base64}:${encrypted.base64}';  // Store IV with ciphertext
/// }
/// ```
class RequireUniqueIvPerEncryptionRule extends SaropaLintRule {
  const RequireUniqueIvPerEncryptionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'require_unique_iv_per_encryption',
    problemMessage: 'Static or reused IV breaks encryption security.',
    correctionMessage:
        'Generate a new random IV for each encryption operation.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check for static IV fields
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      final bool isStatic = node.isStatic;
      if (!isStatic) return;

      final String fieldSource = node.toSource();
      if (fieldSource.contains('IV.') ||
          fieldSource.contains('iv') ||
          fieldSource.contains('IV ')) {
        for (final VariableDeclaration variable in node.fields.variables) {
          reporter.atNode(variable, code);
        }
      }
    });

    // Check for const IV
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      final VariableDeclarationList? parent =
          node.parent is VariableDeclarationList
              ? node.parent as VariableDeclarationList
              : null;
      if (parent == null) return;

      final bool isConst = parent.isConst;
      if (!isConst) return;

      final String varName = node.name.lexeme.toLowerCase();
      // Check for exact 'iv' or 'nonce', or compound names like 'myIv', 'ivValue'
      // Avoid matching words like 'private', 'derivative'
      if (varName == 'iv' ||
          varName == 'nonce' ||
          varName.startsWith('iv') ||
          varName.endsWith('iv') ||
          varName.contains('_iv') ||
          varName.contains('iv_')) {
        reporter.atNode(node, code);
      }
    });

    // Check for IV.fromUtf8 with a literal (fixed IV)
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'fromUtf8' && methodName != 'fromBase64') return;

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (!targetSource.contains('IV')) return;

      // Check if argument is a string literal (fixed IV)
      if (node.argumentList.arguments.isNotEmpty) {
        final Expression firstArg = node.argumentList.arguments.first;
        if (firstArg is StringLiteral) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}
