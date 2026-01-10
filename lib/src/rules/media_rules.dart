// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Media (audio/video) rules for Flutter/Dart applications.
///
/// These rules detect common mistakes when handling audio and video
/// that can cause poor user experience or platform issues.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when autoPlay: true is set on audio/video players.
///
/// Autoplaying audio is blocked on iOS/web and annoying to users.
/// Require explicit user interaction to start playback.
///
/// **BAD:**
/// ```dart
/// VideoPlayerController.asset('video.mp4')..initialize()..play();
/// AudioPlayer()..setUrl(url)..play(); // Auto-plays on load
/// BetterPlayerController(configuration: BetterPlayerConfiguration(autoPlay: true));
/// ```
///
/// **GOOD:**
/// ```dart
/// VideoPlayerController.asset('video.mp4')..initialize();
/// // User presses play button to start
///
/// BetterPlayerController(configuration: BetterPlayerConfiguration(autoPlay: false));
/// ```
class AvoidAutoplayAudioRule extends SaropaLintRule {
  const AvoidAutoplayAudioRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'avoid_autoplay_audio',
    problemMessage: 'Autoplay is blocked on iOS/web and annoys users.',
    correctionMessage: 'Set autoPlay: false and require user interaction to play.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addNamedExpression((NamedExpression node) {
      if (node.name.label.name != 'autoPlay' && node.name.label.name != 'autoplay') {
        return;
      }

      final Expression value = node.expression;
      if (value is BooleanLiteral && value.value) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_DisableAutoplayFix()];
}

class _DisableAutoplayFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addNamedExpression((NamedExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final Expression value = node.expression;
      if (value is! BooleanLiteral || !value.value) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Set autoPlay to false',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          value.sourceRange,
          'false',
        );
      });
    });
  }
}
