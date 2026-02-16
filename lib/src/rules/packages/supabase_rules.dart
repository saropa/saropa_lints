// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Supabase-specific lint rules for Flutter/Dart applications.
///
/// These rules ensure proper Supabase usage patterns including
/// error handling, key security, and realtime subscription cleanup.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../saropa_lint_rule.dart';

// =============================================================================
// SUPABASE RULES
// =============================================================================

/// Warns when Supabase calls lack try-catch error handling.
///
/// Since: v2.2.0 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: supabase_try_catch, handle_supabase_errors
///
/// Supabase operations can fail due to network issues, auth problems, or
/// database constraints. Unhandled errors will crash the app.
///
/// **BAD:**
/// ```dart
/// Future<void> fetchData() async {
///   final response = await supabase.from('users').select();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> fetchData() async {
///   try {
///     final response = await supabase.from('users').select();
///   } on PostgrestException catch (e) {
///     // Handle database error
///   }
/// }
/// ```
class RequireSupabaseErrorHandlingRule extends SaropaLintRule {
  RequireSupabaseErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_supabase_error_handling',
    '[require_supabase_error_handling] Supabase operation called without error handling crashes when the network is unavailable, authentication tokens expire, or the database rejects the query. Users see an unhandled exception crash screen instead of a friendly error message, causing data loss and a broken user experience. {v3}',
    correctionMessage:
        'Wrap Supabase operations in a try-catch block that handles PostgrestException and network errors, and display user-friendly messages with retry options.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Look for the .from('table') pattern which is unique to Supabase
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'from') return;

      // Must be called on something containing 'supabase' or 'Supabase'
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('supabase')) return;

      // Found a supabase.from() call - now check if it's in a try-catch
      AstNode? current = node.parent;
      while (current != null) {
        if (current is TryStatement) return; // Has try-catch, OK
        if (current is FunctionBody) break;
        current = current.parent;
      }

      reporter.atNode(node);
    });
  }
}

/// Warns when Supabase anon key is hardcoded in source code.
///
/// Since: v2.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: no_supabase_key_in_code, supabase_key_security
///
/// Supabase anon keys should come from environment variables or secure storage,
/// not hardcoded in source files that may be committed to version control.
///
/// **BAD:**
/// ```dart
/// final supabase = Supabase.initialize(
///   url: 'https://xxx.supabase.co',
///   anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// final supabase = Supabase.initialize(
///   url: Env.supabaseUrl,
///   anonKey: Env.supabaseAnonKey,
/// );
/// ```
class AvoidSupabaseAnonKeyInCodeRule extends SaropaLintRule {
  AvoidSupabaseAnonKeyInCodeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_supabase_anon_key_in_code',
    '[avoid_supabase_anon_key_in_code] Hardcoded keys can be extracted '
        'from app binary. Attackers gain direct access to your Supabase project. {v2}',
    correctionMessage:
        'Use environment variables or secure configuration for API keys.',
    severity: DiagnosticSeverity.ERROR,
  );

  // Supabase JWT tokens start with this pattern
  static final RegExp _jwtPattern = RegExp(r'eyJ[A-Za-z0-9_-]{20,}');

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;
      if (value.length < 50) return; // JWT tokens are long

      if (_jwtPattern.hasMatch(value)) {
        // Check if it's in a Supabase context
        AstNode? current = node.parent;
        while (current != null) {
          final String source = current.toSource();
          if (source.contains('Supabase') ||
              source.contains('anonKey') ||
              source.contains('supabase')) {
            reporter.atNode(node);
            return;
          }
          if (current is FunctionBody || current is ClassDeclaration) break;
          current = current.parent;
        }
      }
    });
  }
}

/// Warns when Supabase realtime subscriptions are not unsubscribed in dispose.
///
/// Since: v2.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: supabase_realtime_dispose, unsubscribe_supabase_channel
///
/// Supabase realtime channels must be unsubscribed when the widget is disposed
/// to prevent memory leaks and unexpected behavior.
///
/// **BAD:**
/// ```dart
/// class _ChatState extends State<Chat> {
///   late RealtimeChannel _channel;
///
///   @override
///   void initState() {
///     super.initState();
///     _channel = supabase.channel('room').subscribe();
///   }
///   // Missing unsubscribe in dispose!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _ChatState extends State<Chat> {
///   late RealtimeChannel _channel;
///
///   @override
///   void initState() {
///     super.initState();
///     _channel = supabase.channel('room').subscribe();
///   }
///
///   @override
///   void dispose() {
///     _channel.unsubscribe();
///     super.dispose();
///   }
/// }
/// ```
class RequireSupabaseRealtimeUnsubscribeRule extends SaropaLintRule {
  RequireSupabaseRealtimeUnsubscribeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_supabase_realtime_unsubscribe',
    '[require_supabase_realtime_unsubscribe] Unsubscribed channel keeps '
        'WebSocket open, leaking connections and receiving stale updates. {v2}',
    correctionMessage:
        'Add channel.unsubscribe() in dispose() to prevent memory leaks.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'State') return;

      // Find RealtimeChannel fields
      final List<String> channelNames = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toSource();
          if (typeName != null && typeName.contains('RealtimeChannel')) {
            for (final VariableDeclaration variable
                in member.fields.variables) {
              channelNames.add(variable.name.lexeme);
            }
          }
        }
      }

      if (channelNames.isEmpty) return;

      // Find dispose method
      String? disposeBody;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeBody = member.body.toSource();
          break;
        }
      }

      // Check if channels are unsubscribed
      for (final String name in channelNames) {
        final bool isUnsubscribed =
            disposeBody != null &&
            (disposeBody.contains('$name.unsubscribe(') ||
                disposeBody.contains('$name?.unsubscribe(') ||
                disposeBody.contains('removeChannel'));

        if (!isUnsubscribed) {
          for (final ClassMember member in node.members) {
            if (member is FieldDeclaration) {
              for (final VariableDeclaration variable
                  in member.fields.variables) {
                if (variable.name.lexeme == name) {
                  reporter.atNode(variable);
                }
              }
            }
          }
        }
      }
    });
  }
}

// =============================================================================
// FIX CLASSES
// =============================================================================
