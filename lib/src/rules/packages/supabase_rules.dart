// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Supabase-specific lint rules for Flutter/Dart applications.
///
/// These rules ensure proper Supabase usage patterns including
/// error handling, key security, and realtime subscription cleanup.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../saropa_lint_rule.dart';

// =============================================================================
// SUPABASE RULES
// =============================================================================

/// Warns when Supabase calls lack try-catch error handling.
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
  const RequireSupabaseErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_supabase_error_handling',
    problemMessage:
        '[require_supabase_error_handling] Supabase operation called without error handling crashes when the network is unavailable, authentication tokens expire, or the database rejects the query. Users see an unhandled exception crash screen instead of a friendly error message, causing data loss and a broken user experience.',
    correctionMessage:
        'Wrap Supabase operations in a try-catch block that handles PostgrestException and network errors, and display user-friendly messages with retry options.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Look for the .from('table') pattern which is unique to Supabase
    context.registry.addMethodInvocation((MethodInvocation node) {
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

      reporter.atNode(node, code);
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddTryCatchTodoFix(code)];
}

/// Warns when Supabase anon key is hardcoded in source code.
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
  const AvoidSupabaseAnonKeyInCodeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_supabase_anon_key_in_code',
    problemMessage:
        '[avoid_supabase_anon_key_in_code] Hardcoded keys can be extracted '
        'from app binary. Attackers gain direct access to your Supabase project.',
    correctionMessage:
        'Use environment variables or secure configuration for API keys.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  // Supabase JWT tokens start with this pattern
  static final RegExp _jwtPattern = RegExp(r'eyJ[A-Za-z0-9_-]{20,}');

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
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
            reporter.atNode(node, code);
            return;
          }
          if (current is FunctionBody || current is ClassDeclaration) break;
          current = current.parent;
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddEnvVarTodoFix()];
}

/// Warns when Supabase realtime subscriptions are not unsubscribed in dispose.
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
  const RequireSupabaseRealtimeUnsubscribeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_supabase_realtime_unsubscribe',
    problemMessage:
        '[require_supabase_realtime_unsubscribe] Unsubscribed channel keeps '
        'WebSocket open, leaking connections and receiving stale updates.',
    correctionMessage:
        'Add channel.unsubscribe() in dispose() to prevent memory leaks.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
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
        final bool isUnsubscribed = disposeBody != null &&
            (disposeBody.contains('$name.unsubscribe(') ||
                disposeBody.contains('$name?.unsubscribe(') ||
                disposeBody.contains('removeChannel'));

        if (!isUnsubscribed) {
          for (final ClassMember member in node.members) {
            if (member is FieldDeclaration) {
              for (final VariableDeclaration variable
                  in member.fields.variables) {
                if (variable.name.lexeme == name) {
                  reporter.atNode(variable, code);
                }
              }
            }
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddDisposeTodoFix('unsubscribe()')];
}

// =============================================================================
// FIX CLASSES
// =============================================================================

class _AddTryCatchTodoFix extends DartFix {
  // ignore: avoid_unused_constructor_parameters
  _AddTryCatchTodoFix(LintCode _);

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

      // Find the statement containing this method invocation
      AstNode? statementNode = node.parent;
      while (statementNode != null && statementNode is! Statement) {
        statementNode = statementNode.parent;
      }

      if (statementNode == null) return;

      // Get the indentation of the current statement
      final int statementOffset = statementNode.offset;
      final String sourceCode = resolver.source.contents.data;
      int lineStart = statementOffset;
      while (lineStart > 0 && sourceCode[lineStart - 1] != '\n') {
        lineStart--;
      }
      final String leadingWhitespace =
          sourceCode.substring(lineStart, statementOffset);
      final String indent =
          leadingWhitespace.isEmpty ? '  ' : leadingWhitespace;

      final String statementSource = statementNode.toSource();

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Wrap in try-catch',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(statementNode!.offset, statementNode.length),
          'try {\n$indent  $statementSource\n$indent} catch (e) {\n$indent  // Handle error\n$indent  rethrow;\n$indent}',
        );
      });
    });
  }
}

class _AddEnvVarTodoFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK: Use environment variable',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Use environment variable or secure storage instead\n',
        );
      });
    });
  }
}

class _AddDisposeTodoFix extends DartFix {
  _AddDisposeTodoFix(this._methodCall);
  final String _methodCall;

  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      // Find the full field declaration (including semicolon)
      AstNode? fieldDecl = node.parent?.parent;
      if (fieldDecl is! FieldDeclaration) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add FIXME reminder for $_methodCall',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Find where the semicolon is and insert comment before it
        final String fieldSource = fieldDecl.toSource();
        final int semicolonIndex = fieldSource.lastIndexOf(';');
        if (semicolonIndex == -1) return;

        builder.addSimpleInsertion(
          fieldDecl.offset + semicolonIndex,
          ' // FIXME: Add $_methodCall in dispose()',
        );
      });
    });
  }
}
