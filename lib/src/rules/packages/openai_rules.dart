// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// OpenAI (chat_gpt_sdk) lint rules.
///
/// These rules guard against the two most common OpenAI integration mistakes:
/// hardcoding an API key in source, and calling the API without error handling.
/// The error-handling rule targets the `chat_gpt_sdk` package's `OpenAI` class
/// method names; the key-in-code rule is SDK-agnostic (it matches the `sk-`
/// secret pattern in any string literal).
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../saropa_lint_rule.dart';

/// Warns when OpenAI API key pattern is found in source code.
///
/// Since: v2.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: no_openai_key_in_code, openai_key_security
///
/// OpenAI API keys (sk-...) should never be hardcoded in source files.
/// They should come from environment variables or secure storage.
///
/// **BAD:**
/// ```dart
/// final openAI = OpenAI.instance.build(
///   token: 'sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxx',
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// final openAI = OpenAI.instance.build(
///   token: Env.openAiKey,
/// );
/// ```
class AvoidOpenaiKeyInCodeRule extends SaropaLintRule {
  AvoidOpenaiKeyInCodeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_openai_key_in_code',
    '[avoid_openai_key_in_code] A hardcoded OpenAI API key is compiled into '
        'the app binary as a plain string, so anyone can extract it with basic '
        'reverse engineering and issue requests billed to your account, '
        'exhausting quota and tripping rate limits until the leaked key is '
        'detected and rotated. {v2}',
    correctionMessage:
        'Use environment variables or secure configuration for API keys.',
    severity: DiagnosticSeverity.ERROR,
  );

  // OpenAI keys start with sk- followed by alphanumeric characters
  static final RegExp _openAiKeyPattern = RegExp(r'sk-[a-zA-Z0-9]{20,}');

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;
      if (_openAiKeyPattern.hasMatch(value)) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when OpenAI API calls (chat_gpt_sdk) lack try-catch error handling.
///
/// Since: v2.2.0 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: openai_try_catch, handle_openai_errors
///
/// OpenAI API calls can fail due to rate limits, network issues, or invalid
/// requests. Without error handling, the app may crash unexpectedly.
///
/// **Note:** This rule targets the chat_gpt_sdk package's OpenAI class methods.
///
/// **BAD:**
/// ```dart
/// Future<String> chat(String message) async {
///   final response = await openAI.onChatCompletion(request: request);
///   return response!.choices.first.message!.content;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<String?> chat(String message) async {
///   try {
///     final response = await openAI.onChatCompletion(request: request);
///     return response?.choices.first.message?.content;
///   } catch (e) {
///     // Handle API error
///     return null;
///   }
/// }
/// ```
class RequireOpenaiErrorHandlingRule extends SaropaLintRule {
  RequireOpenaiErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_openai_error_handling',
    '[require_openai_error_handling] OpenAI API call without error handling crashes when the service returns rate limit errors (429), the API is temporarily unavailable (503), or the request exceeds token limits. Users see an unhandled exception crash screen instead of graceful fallback behavior, causing lost context and a broken experience. {v3}',
    correctionMessage:
        'Wrap OpenAI API calls in a try-catch block that handles rate limits with exponential backoff and service errors with user-friendly fallback messages.',
    severity: DiagnosticSeverity.WARNING,
  );

  // chat_gpt_sdk specific method names
  static const Set<String> _openAiMethods = <String>{
    'onChatCompletion',
    'onCompletion',
    'generateImage',
    'onModeration',
    'createEmbeddings',
    'audioTranscription',
    'audioTranslation',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_openAiMethods.contains(methodName)) return;

      // Validate target looks like OpenAI instance
      final Expression? target = node.target;
      if (target != null) {
        final String targetSource = target.toSource().toLowerCase();
        // Should be called on something containing 'openai' or 'gpt'
        if (!RegExp(r'\b(openai|gpt|_ai)\b').hasMatch(targetSource)) {
          return;
        }
      }

      // Check if wrapped in try-catch
      AstNode? current = node.parent;
      while (current != null) {
        if (current is TryStatement) return;
        if (current is FunctionBody) break;
        current = current.parent;
      }

      reporter.atNode(node);
    });
  }
}
