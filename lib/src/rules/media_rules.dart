// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Media (audio/video) rules for Flutter/Dart applications.
///
/// These rules detect common mistakes when handling audio and video
/// that can cause poor user experience or platform issues.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../saropa_lint_rule.dart';
import '../fixes/media/disable_autoplay_fix.dart';

/// Warns when autoPlay: true is set on audio/video players.
///
/// Since: v1.7.9 | Updated: v4.13.0 | Rule version: v3
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
  AvoidAutoplayAudioRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
        ({required CorrectionProducerContext context}) =>
            DisableAutoplayFix(context: context),
      ];

  static const LintCode _code = LintCode(
    'avoid_autoplay_audio',
    '[avoid_autoplay_audio] Autoplay is blocked on iOS/web and annoys users. Autoplaying audio is blocked on iOS/web and annoying to users. Require explicit user interaction to start playback. {v3}',
    correctionMessage:
        'Set autoPlay: false and require user interaction to play. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addNamedExpression((NamedExpression node) {
      if (node.name.label.name != 'autoPlay' &&
          node.name.label.name != 'autoplay') {
        return;
      }

      final Expression value = node.expression;
      if (value is BooleanLiteral && value.value) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when CameraController is created without explicit resolution preset.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v2
///
/// Camera resolution affects performance, battery, and storage.
/// Always specify the desired resolution for your use case.
///
/// **BAD:**
/// ```dart
/// final controller = CameraController(camera, ResolutionPreset.max);
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use appropriate resolution for your use case
/// final controller = CameraController(
///   camera,
///   ResolutionPreset.medium, // Good for video calls
/// );
/// ```
class PreferCameraResolutionSelectionRule extends SaropaLintRule {
  PreferCameraResolutionSelectionRule() : super(code: _code);

  /// Performance/battery consideration.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_camera_resolution_selection',
    '[prefer_camera_resolution_selection] CameraController with max resolution. Prefer app-specific needs. Camera resolution affects performance, battery, and storage. Always specify the desired resolution for your use case. {v2}',
    correctionMessage:
        'Use ResolutionPreset.medium for video calls, .high for photos. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name.lexeme;

      if (typeName != 'CameraController') {
        return;
      }

      // Check second argument for resolution preset
      final args = node.argumentList.arguments;
      if (args.length < 2) {
        return;
      }

      final resolutionArg = args[1].toSource();
      if (resolutionArg.contains('max') ||
          resolutionArg.contains('ultraHigh')) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when AudioPlayer is used without audio session configuration.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v2
///
/// Audio session determines how your app interacts with other audio.
/// Without configuration, audio may behave unexpectedly.
///
/// **BAD:**
/// ```dart
/// final player = AudioPlayer();
/// await player.play(UrlSource(url));
/// ```
///
/// **GOOD:**
/// ```dart
/// final session = await AudioSession.instance;
/// await session.configure(AudioSessionConfiguration.music());
/// final player = AudioPlayer();
/// await player.play(UrlSource(url));
/// ```
class PreferAudioSessionConfigRule extends SaropaLintRule {
  PreferAudioSessionConfigRule() : super(code: _code);

  /// Audio UX issue - unexpected behavior with other apps.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_audio_session_config',
    '[prefer_audio_session_config] AudioPlayer used without audio session config. May conflict with other audio. Audio session determines how your app interacts with other audio. Without configuration, audio may behave unexpectedly. {v2}',
    correctionMessage:
        'Configure AudioSession.instance before playing audio. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((node) {
      final methodName = node.methodName.name;

      // Check for play method on audio player
      if (methodName != 'play' && methodName != 'setUrl') {
        return;
      }

      final targetSource = node.target?.toSource().toLowerCase() ?? '';
      if (!targetSource.contains('player') && !targetSource.contains('audio')) {
        return;
      }

      // Find enclosing method
      AstNode? current = node.parent;
      MethodDeclaration? enclosingMethod;

      while (current != null) {
        if (current is MethodDeclaration) {
          enclosingMethod = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingMethod == null) {
        return;
      }

      final methodSource = enclosingMethod.toSource().toLowerCase();

      // Check for audio session configuration
      if (methodSource.contains('audiosession') ||
          methodSource.contains('audio_session')) {
        return;
      }

      reporter.atNode(node);
    });
  }
}
