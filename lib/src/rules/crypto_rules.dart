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
/// Since: v1.7.9 | Updated: v4.13.0 | Rule version: v5
///
/// Alias: no_hardcoded_key, hardcoded_secret_key, embedded_encryption_key
///
/// Hardcoded encryption keys in source code can be extracted from
/// compiled applications (APK, IPA). Keys should be stored securely
/// or derived at runtime.
///
/// **Quick fix available:** Adds a comment for manual secure key loading.
///
/// ## Detection approach
///
/// This rule ONLY detects calls to encryption library Key constructors with
/// string literals, e.g. `Key.fromUtf8('secret')`. This is reliable because
/// it requires both:
/// 1. A known encryption Key class (Key, SecretKey, CipherKey, etc.)
/// 2. A key construction method (fromUtf8, fromBase64, etc.)
/// 3. A hardcoded string literal argument
///
/// We intentionally do NOT flag variables just because they have "key" in
/// their name. Variable name matching produces too many false positives:
/// - `jsonKeyName` (JSON field names)
/// - `primaryKey` (database keys)
/// - `keyboardShortcut`, `hotkey` (UI)
/// - `searchKeyword`, `keyPath`, etc.
///
/// The word "key" is too common in programming to be a reliable indicator.
///
/// **BAD:**
/// ```dart
/// final key = encrypt.Key.fromUtf8('my-secret-key-123');
/// final key = CipherKey.fromUtf8('hardcoded-secret');
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

  @override
  RuleCost get cost => RuleCost.low;

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m1, OwaspMobile.m10},
        web: <OwaspWeb>{OwaspWeb.a02},
      );

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_encryption_keys',
    problemMessage:
        '[avoid_hardcoded_encryption_keys] Hardcoded encryption keys present in source code or binaries can be easily extracted by attackers using reverse engineering tools. Once exposed, these keys allow adversaries to decrypt all user data protected by the key, resulting in a complete compromise of confidentiality for every user of your application. This vulnerability is especially critical in mobile and web apps, where binaries are distributed to end users. Hardcoded keys are often found in test code, examples, or as quick fixes, but they must never be used in production or shipped code. Attackers routinely scan for such patterns, and automated tools can detect and extract these secrets within minutes of release. {v5}',
    correctionMessage:
        'Never store encryption keys directly in your source code, configuration files, or application binaries. Instead, load keys securely at runtime from protected sources such as secure storage (e.g., Android Keystore, iOS Keychain, server APIs, or environment variables), or derive them from user input (such as passwords) using a secure key derivation function (KDF) with a unique salt. Review your codebase for any hardcoded secrets, and refactor to ensure that all cryptographic keys are dynamically loaded or derived at runtime. Document your key management strategy and ensure that secrets are never committed to version control or distributed with your app.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// Methods used to construct encryption keys from data.
  static const Set<String> _keyMethods = <String>{
    'fromUtf8',
    'fromBase64',
    'fromBase16',
    'fromSecureRandom',
    'fromLength',
  };

  /// Known encryption Key classes from popular Dart crypto libraries:
  /// - encrypt package: Key
  /// - crypto_x package: CipherKey
  /// - cryptography package: SecretKey
  /// - Custom implementations: EncryptionKey, AesKey
  static const Set<String> _keyClasses = <String>{
    'Key',
    'SecretKey',
    'EncryptionKey',
    'AesKey',
    'CipherKey',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only flag encryption library Key constructors with string literals.
    // This approach is reliable because it requires a specific class + method
    // + literal combination that unambiguously indicates a hardcoded key.

    // Handle static method calls like SomeKey.fromUtf8(...)
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (!_keyMethods.contains(methodName)) return;

      // Check if it's on a Key-like class
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (!_keyClasses.any(targetSource.contains)) return;

      // Check if argument is a string literal (hardcoded key)
      if (node.argumentList.arguments.isNotEmpty) {
        final Expression firstArg = node.argumentList.arguments.first;
        if (firstArg is StringLiteral) {
          reporter.atNode(firstArg, code);
        }
      }
    });

    // Handle named constructors like Key.fromUtf8(...), Key.fromBase64(...)
    // The encrypt package uses named constructors, not static methods.
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final ConstructorName constructorName = node.constructorName;
      final String typeName = constructorName.type.name.lexeme;

      // Check if it's a Key-like class
      if (!_keyClasses.contains(typeName)) return;

      // Check if it's a named constructor we care about
      final SimpleIdentifier? name = constructorName.name;
      if (name == null) return;
      if (!_keyMethods.contains(name.name)) return;

      // Check if argument is a string literal (hardcoded key)
      if (node.argumentList.arguments.isNotEmpty) {
        final Expression firstArg = node.argumentList.arguments.first;
        if (firstArg is StringLiteral) {
          reporter.atNode(firstArg, code);
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddSecureKeyLoadingCommentFix()];
}

class _AddSecureKeyLoadingCommentFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    // Handle both method invocations and instance creation expressions
    context.registry.addStringLiteral((StringLiteral node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      // Find the containing statement
      AstNode? current = node;
      while (current != null && current is! ExpressionStatement) {
        current = current.parent;
      }
      if (current == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add secure key loading comment',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          current!.offset,
          '// HACK: Load key from secure storage or environment, not hardcoded\n    ',
        );
      });
    });
  }
}

/// Warns when Random() is used for cryptographic purposes.
///
/// Since: v1.7.9 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: use_secure_random, random_vs_secure_random, insecure_random
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

  @override
  RuleCost get cost => RuleCost.low;

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m10},
        web: <OwaspWeb>{OwaspWeb.a02},
      );

  static const LintCode _code = LintCode(
    name: 'prefer_secure_random_for_crypto',
    // cspell:ignore PRNG CSPRNG
    problemMessage:
        '[prefer_secure_random_for_crypto] The default Random() constructor in Dart uses a seed based on the current system time, making its output predictable and vulnerable to attack. If Random() is used to generate cryptographic keys, initialization vectors (IVs), nonces, tokens, or any value intended to protect sensitive data, attackers can reproduce the same sequence of random numbers and break your security. This flaw has led to real-world breaches where cryptographic protections were bypassed due to weak randomness. Only a cryptographically secure random number generator (CSPRNG) can provide the unpredictability required for security-critical operations. {v3}',
    correctionMessage:
        'Replace every use of Random() in cryptographic or security-sensitive contexts with Random.secure(), which leverages the operating system’s cryptographically secure random number generator. This ensures that generated values are truly unpredictable and cannot be reproduced by attackers. Audit your codebase for any use of Random() related to encryption, authentication, token generation, or any feature that relies on secrecy. Update all such instances to use Random.secure(), and add tests or code reviews to prevent future regressions. Document the importance of using CSPRNGs for all cryptographic operations in your project guidelines.',
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
        // Also check local functions (FunctionDeclaration)
        if (current is FunctionDeclaration) {
          final String funcName = current.name.lexeme.toLowerCase();
          if (_securityIndicators.any((s) => funcName.contains(s))) {
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
/// Since: v1.7.9 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: no_md5, no_sha1, weak_hash_algorithm, insecure_hash
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

  @override
  RuleCost get cost => RuleCost.low;

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m10},
        web: <OwaspWeb>{OwaspWeb.a02},
      );

  static const LintCode _code = LintCode(
    name: 'avoid_deprecated_crypto_algorithms',
    // cspell:ignore preimage
    problemMessage:
        '[avoid_deprecated_crypto_algorithms] The use of outdated cryptographic algorithms such as MD5, SHA1, DES, 3DES, and RC4 exposes your application to well-known attacks. These algorithms have been broken by the security community: MD5 and SHA1 are vulnerable to collision and preimage attacks, allowing attackers to forge digital signatures or tamper with data. DES and 3DES have insufficient key lengths and are susceptible to brute-force attacks, while RC4 is vulnerable to several biases and key recovery attacks. Continuing to use these algorithms puts all encrypted or hashed data at risk of compromise, regardless of other security measures. {v2}',
    correctionMessage:
        'Replace all uses of deprecated algorithms with modern, secure alternatives. For hashing, use SHA-256 or stronger (SHA-384, SHA-512) for integrity, and HMAC with a strong hash for authentication. For encryption, use AES-256 in a secure mode (e.g., GCM or CBC with random IVs). For password storage, use dedicated password hashing algorithms like bcrypt, scrypt, or Argon2. Review your codebase, dependencies, and third-party libraries for any references to MD5, SHA1, DES, 3DES, or RC4, and refactor to use only cryptographically secure primitives. Document your cryptographic choices and ensure all team members are aware of the risks of deprecated algorithms.',
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

// cspell:ignore ciphertext
/// Warns when static or reused IVs are detected in encryption.
///
/// Since: v1.7.9 | Updated: v4.13.0 | Rule version: v4
///
/// Alias: static_iv, reused_iv, iv_reuse, nonce_reuse
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

  @override
  RuleCost get cost => RuleCost.low;

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m10},
        web: <OwaspWeb>{OwaspWeb.a02},
      );

  // cspell:ignore ciphertexts plaintexts
  static const LintCode _code = LintCode(
    name: 'require_unique_iv_per_encryption',
    problemMessage:
        '[require_unique_iv_per_encryption] Using a static or reused initialization vector (IV) with the same encryption key enables attackers to detect patterns in your encrypted data. When the same IV is used for multiple encryption operations, identical plaintexts will always produce identical ciphertexts, making it possible for adversaries to infer relationships between messages, perform replay attacks, or even recover plaintexts in some encryption modes. This breaks the fundamental guarantee of confidentiality provided by encryption and has led to serious vulnerabilities in real-world systems. {v4}',
    correctionMessage:
        'Always generate a new, random IV for every encryption operation, especially when using block cipher modes like CBC or GCM. Use secure random number generators (such as IV.fromSecureRandom(16)) to ensure IVs are unpredictable and unique for each message. Never use a constant, hardcoded, or reused IV, even for testing or non-production code. If you need to decrypt data later, store the IV alongside the ciphertext (it does not need to be secret, only unique per key). Review your codebase for static or reused IVs and refactor to generate fresh IVs for every encryption. Educate your team about the risks of IV reuse and document best practices in your project.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// Checks if a variable name indicates an IV/nonce variable.
  /// Avoids false positives like "activity", "private", "derivative".
  static bool _isIvVariableName(String originalName) {
    final String lowerName = originalName.toLowerCase();

    // Snake_case patterns: my_iv, iv_value, _iv_
    if (lowerName.contains('_iv_') ||
        lowerName.endsWith('_iv') ||
        lowerName.startsWith('iv_')) {
      return true;
    }

    // CamelCase patterns: myIv, encryptionIV
    // Capital I after lowercase = word boundary
    return RegExp(r'[a-z]I[Vv]').hasMatch(originalName);
  }

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

      for (final VariableDeclaration variable in node.fields.variables) {
        // Check variable name for IV-related patterns
        final String originalName = variable.name.lexeme;
        final String lowerName = originalName.toLowerCase();
        final bool hasIvName = lowerName == 'iv' ||
            lowerName == 'nonce' ||
            _isIvVariableName(originalName);

        // Check if type or initializer references IV class
        final String fieldSource = node.toSource();
        final bool hasIvClass =
            fieldSource.contains('IV.') || fieldSource.contains('IV(');

        if (hasIvName || hasIvClass) {
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

      final String originalName = node.name.lexeme;
      final String lowerName = originalName.toLowerCase();
      if (lowerName == 'iv' ||
          lowerName == 'nonce' ||
          _isIvVariableName(originalName)) {
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

  @override
  List<Fix> getFixes() => <Fix>[_UseSecureRandomIvFix()];
}

class _UseSecureRandomIvFix extends DartFix {
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

      final String methodName = node.methodName.name;
      if (methodName != 'fromUtf8' && methodName != 'fromBase64') return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Use IV.fromSecureRandom(16)',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          'IV.fromSecureRandom(16)',
        );
      });
    });
  }
}

// =============================================================================
// require_secure_key_generation
// =============================================================================

/// Warns when encryption keys are generated from predictable byte patterns.
///
/// Since: v4.14.0 | Rule version: v2
///
/// Alias: secure_key_generation, predictable_key
///
/// Complementary to `avoid_hardcoded_encryption_keys` which catches string
/// literal keys. This rule detects **non-string** predictable patterns:
/// - `Key(Uint8List.fromList([1, 2, 3, ...]))` — hardcoded byte arrays
/// - `Key(List.filled(16, 0))` — predictable fill patterns
/// - `Key.fromLength(N)` — uses `dart:math` Random (NOT SecureRandom)
///
/// These patterns produce deterministic or guessable keys that compromise
/// all encrypted data.
///
/// **BAD:**
/// ```dart
/// final key = Key(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8,
///   9, 10, 11, 12, 13, 14, 15, 16]));
/// final key = Key.fromLength(16); // uses dart:math Random, not secure
/// final key = Key(List.filled(32, 0));
/// ```
///
/// **GOOD:**
/// ```dart
/// final key = Key.fromSecureRandom(32);
/// final key = Key(SecureRandom(32).bytes);
/// final keyStr = await secureStorage.read(key: 'enc_key');
/// final key = Key.fromUtf8(keyStr!);
/// ```
///
/// **OWASP:** [M5:Insecure-Communication] [M9:Reverse-Engineering]
class RequireSecureKeyGenerationRule extends SaropaLintRule {
  const RequireSecureKeyGenerationRule() : super(code: _code);

  /// Predictable keys are extractable from binaries — critical security flaw.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m5, OwaspMobile.m10},
        web: <OwaspWeb>{OwaspWeb.a02},
      );

  static const LintCode _code = LintCode(
    name: 'require_secure_key_generation',
    problemMessage:
        '[require_secure_key_generation] Encryption key generated from a '
        'predictable source. Key.fromLength() uses dart:math Random which is '
        'NOT cryptographically secure. Hardcoded byte arrays in '
        'Uint8List.fromList() or List.filled() produce deterministic keys '
        'extractable from compiled binaries. Predictable keys compromise all '
        'data encrypted with them and cannot be rotated without data loss. {v2}',
    correctionMessage:
        'Use Key.fromSecureRandom(32) for AES-256 or Key.fromSecureRandom(16) '
        'for AES-128. For runtime keys, load from secure storage or derive '
        'from user credentials with a proper KDF.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// Known encryption Key class names from popular Dart crypto libraries
  static const Set<String> _keyClasses = <String>{
    'Key',
    'SecretKey',
    'EncryptionKey',
    'AesKey',
    'CipherKey',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Detect Key.fromLength(N) — uses dart:math Random, not SecureRandom
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'fromLength') return;

      final Expression? target = node.target;
      if (target is SimpleIdentifier && _keyClasses.contains(target.name)) {
        reporter.atNode(node, code);
      }
    });

    // Detect Key(literal_list) or Key(Uint8List.fromList([...]))
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name2.lexeme;
      if (!_keyClasses.contains(typeName)) return;

      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression firstArg = args.first;

      // Key([1, 2, 3, ...]) — direct list literal
      if (firstArg is ListLiteral) {
        reporter.atNode(node, code);
        return;
      }

      // Key(Uint8List.fromList([...])) or Key(List.filled(N, M))
      if (firstArg is MethodInvocation) {
        final String method = firstArg.methodName.name;
        if (method == 'fromList' || method == 'filled') {
          final NodeList<Expression> innerArgs =
              firstArg.argumentList.arguments;
          if (innerArgs.isNotEmpty && innerArgs.first is ListLiteral) {
            reporter.atNode(node, code);
          } else if (method == 'filled') {
            // List.filled always produces predictable output
            reporter.atNode(node, code);
          }
        }
      }
    });
  }
}
