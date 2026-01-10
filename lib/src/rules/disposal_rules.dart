// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Disposal rules for Flutter/Dart applications.
///
/// These rules ensure that controllers and resources that require
/// explicit disposal are properly cleaned up in dispose() methods.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when VideoPlayerController or AudioPlayer is not disposed.
///
/// Media players hold native resources that must be released.
/// Failing to dispose keeps hardware locked and causes memory leaks.
///
/// **BAD:**
/// ```dart
/// class _VideoPageState extends State<VideoPage> {
///   late VideoPlayerController _controller;
///
///   @override
///   void initState() {
///     super.initState();
///     _controller = VideoPlayerController.asset('video.mp4');
///     _controller.initialize();
///   }
///   // Missing dispose - video hardware stays locked!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _VideoPageState extends State<VideoPage> {
///   late VideoPlayerController _controller;
///
///   @override
///   void initState() {
///     super.initState();
///     _controller = VideoPlayerController.asset('video.mp4');
///     _controller.initialize();
///   }
///
///   @override
///   void dispose() {
///     _controller.dispose();
///     super.dispose();
///   }
/// }
/// ```
class RequireMediaPlayerDisposeRule extends SaropaLintRule {
  const RequireMediaPlayerDisposeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'require_media_player_dispose',
    problemMessage:
        'Media player controller must be disposed to release hardware resources.',
    correctionMessage:
        'Add controller.dispose() in the dispose() method before super.dispose().',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _mediaControllerTypes = <String>{
    'VideoPlayerController',
    'AudioPlayer',
    'AudioCache',
    'AssetsAudioPlayer',
    'AudioPlayerHandler',
    'JustAudioPlayer',
    'ChewieController',
    'BetterPlayerController',
    'FlickManager',
    'PodPlayerController',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends State<T>
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'State') return;

      // Find media controller fields
      final List<String> controllerNames = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toSource();
          if (typeName != null) {
            for (final String controllerType in _mediaControllerTypes) {
              if (typeName.contains(controllerType)) {
                for (final VariableDeclaration variable
                    in member.fields.variables) {
                  controllerNames.add(variable.name.lexeme);
                }
              }
            }
          }
        }
      }

      if (controllerNames.isEmpty) return;

      // Find dispose method
      String? disposeBody;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeBody = member.body.toSource();
          break;
        }
      }

      // Check if controllers are disposed
      for (final String name in controllerNames) {
        final bool isDisposed = disposeBody != null &&
            (disposeBody.contains('$name.dispose(') ||
                disposeBody.contains('$name?.dispose('));

        if (!isDisposed) {
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
}

/// Warns when TabController is not disposed.
///
/// TabController with vsync must be disposed to free animation resources.
///
/// **BAD:**
/// ```dart
/// class _TabPageState extends State<TabPage>
///     with SingleTickerProviderStateMixin {
///   late TabController _tabController;
///
///   @override
///   void initState() {
///     super.initState();
///     _tabController = TabController(length: 3, vsync: this);
///   }
///   // Missing dispose!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _TabPageState extends State<TabPage>
///     with SingleTickerProviderStateMixin {
///   late TabController _tabController;
///
///   @override
///   void initState() {
///     super.initState();
///     _tabController = TabController(length: 3, vsync: this);
///   }
///
///   @override
///   void dispose() {
///     _tabController.dispose();
///     super.dispose();
///   }
/// }
/// ```
class RequireTabControllerDisposeRule extends SaropaLintRule {
  const RequireTabControllerDisposeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'require_tab_controller_dispose',
    problemMessage:
        'TabController must be disposed to free animation resources.',
    correctionMessage:
        'Add _tabController.dispose() in the dispose() method before super.dispose().',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if extends State<T>
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'State') return;

      // Find TabController fields
      final List<String> controllerNames = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toSource();
          final String fieldSource = member.toSource();
          if ((typeName != null && typeName.contains('TabController')) ||
              fieldSource.contains('TabController(')) {
            for (final VariableDeclaration variable
                in member.fields.variables) {
              controllerNames.add(variable.name.lexeme);
            }
          }
        }
      }

      if (controllerNames.isEmpty) return;

      // Find dispose method
      String? disposeBody;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeBody = member.body.toSource();
          break;
        }
      }

      // Check if controllers are disposed
      for (final String name in controllerNames) {
        final bool isDisposed = disposeBody != null &&
            (disposeBody.contains('$name.dispose(') ||
                disposeBody.contains('$name?.dispose('));

        if (!isDisposed) {
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
}
