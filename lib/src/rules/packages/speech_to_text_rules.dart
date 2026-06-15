// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// speech_to_text package lint rules.
///
/// Ensures SpeechToText is stopped in dispose() to release the microphone and
/// stop background processing when the widget is torn down.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../saropa_lint_rule.dart';
import '../../target_matcher_utils.dart';

/// Warns when SpeechToText is not stopped in dispose.
///
/// Since: v2.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: dispose_speech_to_text, speech_to_text_leak
///
/// SpeechToText must be stopped when the widget is disposed to release
/// microphone resources and stop background processing.
///
/// **BAD:**
/// ```dart
/// class _VoiceState extends State<Voice> {
///   final SpeechToText _speech = SpeechToText();
///
///   void startListening() async {
///     await _speech.listen(onResult: (result) {});
///   }
///   // Missing stop in dispose!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _VoiceState extends State<Voice> {
///   final SpeechToText _speech = SpeechToText();
///
///   void startListening() async {
///     await _speech.listen(onResult: (result) {});
///   }
///
///   @override
///   void dispose() {
///     _speech.stop();
///     super.dispose();
///   }
/// }
/// ```
class RequireSpeechStopOnDisposeRule extends SaropaLintRule {
  RequireSpeechStopOnDisposeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_speech_stop_on_dispose',
    '[require_speech_stop_on_dispose] A SpeechToText recognizer that is not '
        'stopped in dispose keeps the microphone active after the screen '
        'closes, draining the battery, leaving the operating-system recording '
        'indicator on, and blocking other apps from capturing audio until the '
        'session is finally released. {v2}',
    correctionMessage:
        'Add _speech.stop() in dispose() to release microphone resources.',
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
      // Find SpeechToText fields
      final List<String> speechFieldNames = <String>[];
      final speechToTextPattern = RegExp(r'\bSpeechToText\b');
      for (final ClassMember member in node.bodyMembers) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toSource();
          if (typeName != null && speechToTextPattern.hasMatch(typeName)) {
            for (final VariableDeclaration variable
                in member.fields.variables) {
              speechFieldNames.add(variable.name.lexeme);
            }
          }
        }
      }

      if (speechFieldNames.isEmpty) return;

      // Find dispose method
      MethodDeclaration? disposeMethod;
      for (final ClassMember member in node.bodyMembers) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeMethod = member;
          break;
        }
      }

      // Check if speech is stopped
      for (final String name in speechFieldNames) {
        final bool isStopped =
            disposeMethod != null &&
            (isFieldCleanedUp(name, 'stop', disposeMethod.body) ||
                isFieldCleanedUp(name, 'cancel', disposeMethod.body));

        if (!isStopped) {
          for (final ClassMember member in node.bodyMembers) {
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
