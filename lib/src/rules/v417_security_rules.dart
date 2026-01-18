// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

// =============================================================================
// v4.1.7 Rules - Security Best Practices
// =============================================================================

/// Warns when sensitive data is copied to clipboard.
///
/// `[HEURISTIC]` - Detects Clipboard.setData with sensitive variable names.
///
/// Clipboard contents are accessible to other apps. Don't copy passwords,
/// tokens, secrets, or API keys to the clipboard.
///
/// **BAD:**
/// ```dart
/// void copyPassword(String password) {
///   Clipboard.setData(ClipboardData(text: password)); // Accessible to other apps!
/// }
///
/// void shareToken() {
///   Clipboard.setData(ClipboardData(text: apiKey)); // Security risk!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void copyPublicId(String userId) {
///   Clipboard.setData(ClipboardData(text: userId)); // OK - public data
/// }
/// ```
class AvoidSensitiveDataInClipboardRule extends SaropaLintRule {
  const AvoidSensitiveDataInClipboardRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_sensitive_data_in_clipboard',
    problemMessage:
        '[avoid_sensitive_data_in_clipboard] Sensitive data copied to clipboard. Accessible to other apps.',
    correctionMessage:
        'Avoid copying passwords, tokens, secrets, or API keys to clipboard.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static final RegExp _sensitivePattern = RegExp(
    r'\b(password|passwd|pwd|secret|token|apiKey|api_key|accessToken|'
    r'access_token|refreshToken|refresh_token|privateKey|private_key|'
    r'secretKey|secret_key|credential|authToken|bearer|jwt|pin|otp)\b',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'setData') return;

      // Check if called on Clipboard
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Clipboard') return;

      // Check the argument for sensitive patterns
      for (final Expression arg in node.argumentList.arguments) {
        final String argSource = arg.toSource();
        if (_sensitivePattern.hasMatch(argSource)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when clipboard paste is used without validation.
///
/// `[HEURISTIC]` - Detects Clipboard.getData without validation.
///
/// Pasted content can be unexpected format or malicious.
/// Validate clipboard data before using it.
///
/// **BAD:**
/// ```dart
/// void pasteApiKey() async {
///   final data = await Clipboard.getData('text/plain');
///   _apiKey = data?.text ?? ''; // No validation!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void pasteApiKey() async {
///   final data = await Clipboard.getData('text/plain');
///   final text = data?.text ?? '';
///   if (_isValidApiKeyFormat(text)) {
///     _apiKey = text;
///   }
/// }
/// ```
class RequireClipboardPasteValidationRule extends SaropaLintRule {
  const RequireClipboardPasteValidationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_clipboard_paste_validation',
    problemMessage:
        '[require_clipboard_paste_validation] Clipboard data used without validation.',
    correctionMessage:
        'Validate clipboard content format and sanitize before using.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'getData') return;

      // Check if called on Clipboard
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Clipboard') return;

      // Check if the result is used directly without validation
      final AstNode? parent = node.parent;
      if (parent is AwaitExpression) {
        final AstNode? awaitParent = parent.parent;
        if (awaitParent is VariableDeclaration) {
          // Check if there's validation logic nearby
          final AstNode? block = _findContainingBlock(awaitParent);
          if (block != null && !_hasValidationLogic(block)) {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }

  AstNode? _findContainingBlock(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is Block) return current;
      if (current is FunctionBody) return current;
      current = current.parent;
    }
    return null;
  }

  bool _hasValidationLogic(AstNode block) {
    final String source = block.toSource();
    // Check for common validation patterns
    return source.contains('isValid') ||
        source.contains('validate') ||
        source.contains('RegExp') ||
        source.contains('.contains(') ||
        source.contains('.startsWith(') ||
        source.contains('.length');
  }
}

/// Warns when encryption keys are stored as class fields.
///
/// `[HEURISTIC]` - Detects fields with key-related names.
///
/// Keys kept in memory can be extracted from memory dumps.
/// Load keys on demand and clear after use.
///
/// **BAD:**
/// ```dart
/// class EncryptionService {
///   final String encryptionKey; // Stays in memory!
///   final Uint8List privateKey; // Extractable from dump!
///
///   EncryptionService(this.encryptionKey, this.privateKey);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class EncryptionService {
///   Future<String> encrypt(String data) async {
///     final key = await _loadKeyFromSecureStorage();
///     try {
///       return _encrypt(data, key);
///     } finally {
///       _clearKey(key); // Clear after use
///     }
///   }
/// }
/// ```
class AvoidEncryptionKeyInMemoryRule extends SaropaLintRule {
  const AvoidEncryptionKeyInMemoryRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_encryption_key_in_memory',
    problemMessage:
        '[avoid_encryption_key_in_memory] Encryption key stored as class field. Can be extracted from memory.',
    correctionMessage:
        'Load keys on demand from secure storage and clear after use.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static final RegExp _keyFieldPattern = RegExp(
    r'\b(encryption|private|secret|aes|rsa|hmac).*key\b',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      for (final VariableDeclaration variable in node.fields.variables) {
        final String fieldName = variable.name.lexeme;

        if (_keyFieldPattern.hasMatch(fieldName)) {
          // Check if it's a final field (stored persistently)
          if (node.fields.isFinal || node.fields.isConst) {
            reporter.atNode(variable, code);
          }
        }
      }
    });
  }
}
