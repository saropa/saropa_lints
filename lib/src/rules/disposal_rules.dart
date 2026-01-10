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
/// Alias: dispose_media_player, media_player_leak, require_video_player_controller_dispose
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
/// Alias: dispose_tab_controller, tab_controller_leak
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

// ============================================================================
// Generic Controller Dispose Rules
// ============================================================================

/// Helper to check if a class extends `State<T>`.
bool _extendsState(ClassDeclaration node) {
  final ExtendsClause? extendsClause = node.extendsClause;
  if (extendsClause == null) return false;
  return extendsClause.superclass.name.lexeme == 'State';
}

/// Helper to find fields that are instantiated by this class (not passed in).
///
/// Only returns fields that are either:
/// - Initialized inline with `Type()` constructor
/// - Assigned in `initState` with `Type()` constructor
///
/// Fields assigned from parameters, callbacks, or external sources are excluded.
List<String> _findOwnedFieldsOfType(ClassDeclaration node, String typeName) {
  // Track all fields of this type and whether they're owned
  final Map<String, bool> fieldOwnership = <String, bool>{};

  for (final ClassMember member in node.members) {
    if (member is FieldDeclaration) {
      final String? declaredType = member.fields.type?.toSource();
      if (declaredType != null &&
          (declaredType == typeName || declaredType == '$typeName?')) {
        for (final VariableDeclaration variable in member.fields.variables) {
          final String fieldName = variable.name.lexeme;
          // Check if initialized inline with constructor call
          final Expression? initializer = variable.initializer;
          if (initializer != null) {
            final String initSource = initializer.toSource();
            // Check for constructor call: TypeName() or TypeName.named()
            if (initSource.startsWith('$typeName(') ||
                initSource.startsWith('$typeName.')) {
              fieldOwnership[fieldName] = true;
            } else {
              fieldOwnership[fieldName] = false;
            }
          } else {
            // No inline initializer - check initState later
            fieldOwnership[fieldName] = false;
          }
        }
      }
    }
  }

  // Check initState for constructor assignments
  for (final ClassMember member in node.members) {
    if (member is MethodDeclaration && member.name.lexeme == 'initState') {
      final String initStateBody = member.body.toSource();
      for (final String fieldName in fieldOwnership.keys) {
        if (!fieldOwnership[fieldName]!) {
          // Look for: fieldName = TypeName( or _fieldName = TypeName(
          final RegExp assignPattern = RegExp(
            '${RegExp.escape(fieldName)}\\s*=\\s*$typeName[.(]',
          );
          if (assignPattern.hasMatch(initStateBody)) {
            fieldOwnership[fieldName] = true;
          }
        }
      }
      break;
    }
  }

  // Return only owned fields
  return fieldOwnership.entries
      .where((MapEntry<String, bool> e) => e.value)
      .map((MapEntry<String, bool> e) => e.key)
      .toList();
}

/// Helper to get the dispose method body as a string.
String? _getDisposeMethodBody(ClassDeclaration node) {
  for (final ClassMember member in node.members) {
    if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
      return member.body.toSource();
    }
  }
  return null;
}

/// Helper to check if a field is disposed in the dispose body.
bool _isFieldDisposed(String fieldName, String? disposeBody) {
  if (disposeBody == null) return false;
  return disposeBody.contains('$fieldName.dispose(') ||
      disposeBody.contains('$fieldName?.dispose(');
}

/// Helper to report undisposed fields.
void _reportUndisposedFields(
  ClassDeclaration node,
  List<String> fieldNames,
  String? disposeBody,
  SaropaDiagnosticReporter reporter,
  LintCode code,
) {
  for (final String name in fieldNames) {
    if (!_isFieldDisposed(name, disposeBody)) {
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            if (variable.name.lexeme == name) {
              reporter.atNode(variable, code);
            }
          }
        }
      }
    }
  }
}

/// Warns when TextEditingController is not disposed.
///
/// Alias: dispose_text_controller, text_controller_leak
///
/// TextEditingController attaches listeners that must be released.
/// Very common issue in forms.
///
/// This rule only flags controllers that are **created** by this class
/// (via inline initialization or in `initState`). Controllers passed in
/// from callbacks, widget parameters, or external sources are correctly
/// excluded since disposal responsibility belongs to the owner.
///
/// **BAD:**
/// ```dart
/// class _FormPageState extends State<FormPage> {
///   final TextEditingController _emailController = TextEditingController();
///   // Missing dispose!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _FormPageState extends State<FormPage> {
///   final TextEditingController _emailController = TextEditingController();
///
///   @override
///   void dispose() {
///     _emailController.dispose();
///     super.dispose();
///   }
/// }
/// ```
///
/// **OK (externally owned - not flagged):**
/// ```dart
/// class _AutocompleteState extends State<MyAutocomplete> {
///   TextEditingController? _controller; // Assigned from Autocomplete callback
///   // No dispose needed - Autocomplete widget owns this controller
/// }
/// ```
class RequireTextEditingControllerDisposeRule extends SaropaLintRule {
  const RequireTextEditingControllerDisposeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'require_text_editing_controller_dispose',
    problemMessage:
        'TextEditingController must be disposed to prevent memory leaks.',
    correctionMessage: 'Add _textController.dispose() in the dispose() method.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      if (!_extendsState(node)) return;

      // Only check controllers that are actually created by this class,
      // not ones passed in from callbacks (e.g., Autocomplete's fieldViewBuilder)
      final List<String> fieldNames =
          _findOwnedFieldsOfType(node, 'TextEditingController');
      if (fieldNames.isEmpty) return;

      final String? disposeBody = _getDisposeMethodBody(node);
      _reportUndisposedFields(node, fieldNames, disposeBody, reporter, code);
    });
  }
}

/// Warns when PageController is not disposed.
///
/// Alias: dispose_page_controller, page_controller_leak
///
/// PageController holds scroll position and listeners that must be
/// released to prevent memory leaks.
///
/// This rule only flags controllers that are **created** by this class
/// (via inline initialization or in `initState`). Controllers passed in
/// from callbacks or external sources are correctly excluded.
///
/// **BAD:**
/// ```dart
/// class _OnboardingPageState extends State<OnboardingPage> {
///   final PageController _pageController = PageController();
///   // Missing dispose!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _OnboardingPageState extends State<OnboardingPage> {
///   final PageController _pageController = PageController();
///
///   @override
///   void dispose() {
///     _pageController.dispose();
///     super.dispose();
///   }
/// }
/// ```
class RequirePageControllerDisposeRule extends SaropaLintRule {
  const RequirePageControllerDisposeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'require_page_controller_dispose',
    problemMessage: 'PageController must be disposed to prevent memory leaks.',
    correctionMessage: 'Add _pageController.dispose() in the dispose() method.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      if (!_extendsState(node)) return;

      // Only check controllers that are actually created by this class
      final List<String> fieldNames =
          _findOwnedFieldsOfType(node, 'PageController');
      if (fieldNames.isEmpty) return;

      final String? disposeBody = _getDisposeMethodBody(node);
      _reportUndisposedFields(node, fieldNames, disposeBody, reporter, code);
    });
  }
}

/// Warns when Timer.periodic is used without WidgetsBindingObserver lifecycle handling.
///
/// Alias: pause_timer_on_background, timer_lifecycle
///
/// Periodic timers continue firing when the app is backgrounded, wasting
/// battery and causing issues when callbacks reference disposed state.
/// Use WidgetsBindingObserver to pause/resume timers on lifecycle changes.
///
/// **BAD:**
/// ```dart
/// class _ClockState extends State<Clock> {
///   Timer? _timer;
///
///   @override
///   void initState() {
///     super.initState();
///     _timer = Timer.periodic(Duration(seconds: 1), (_) => setState(() {}));
///   }
///   // Timer fires in background, wasting battery!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _ClockState extends State<Clock> with WidgetsBindingObserver {
///   Timer? _timer;
///
///   @override
///   void initState() {
///     super.initState();
///     WidgetsBinding.instance.addObserver(this);
///     _startTimer();
///   }
///
///   @override
///   void didChangeAppLifecycleState(AppLifecycleState state) {
///     if (state == AppLifecycleState.paused) {
///       _timer?.cancel();
///     } else if (state == AppLifecycleState.resumed) {
///       _startTimer();
///     }
///   }
///
///   @override
///   void dispose() {
///     WidgetsBinding.instance.removeObserver(this);
///     _timer?.cancel();
///     super.dispose();
///   }
/// }
/// ```
class RequireLifecycleObserverRule extends SaropaLintRule {
  const RequireLifecycleObserverRule() : super(code: _code);

  /// Important for battery life and app stability.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_lifecycle_observer',
    problemMessage: 'Timer.periodic should pause when app is backgrounded.',
    correctionMessage:
        'Add WidgetsBindingObserver and handle didChangeAppLifecycleState.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for Timer.periodic
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (targetSource != 'Timer') return;
      if (node.methodName.name != 'periodic') return;

      // Check if inside StatefulWidget with WidgetsBindingObserver
      AstNode? current = node.parent;
      ClassDeclaration? enclosingClass;

      while (current != null) {
        if (current is ClassDeclaration) {
          enclosingClass = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingClass == null) return;
      if (!_extendsState(enclosingClass)) return;

      // Check for WidgetsBindingObserver mixin
      final String classSource = enclosingClass.toSource();
      final bool hasLifecycleObserver =
          classSource.contains('WidgetsBindingObserver') &&
              classSource.contains('didChangeAppLifecycleState');

      if (!hasLifecycleObserver) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when WebSocketChannel is used without proper cleanup in dispose.
///
/// Alias: close_websocket, websocket_leak
///
/// WebSocket connections must be closed when the widget is disposed to
/// prevent memory leaks and connection issues.
///
/// **BAD:**
/// ```dart
/// class MyState extends State<MyWidget> {
///   late WebSocketChannel channel;
///
///   @override
///   void initState() {
///     super.initState();
///     channel = WebSocketChannel.connect(uri);
///   }
///   // Missing dispose!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyState extends State<MyWidget> {
///   late WebSocketChannel channel;
///
///   @override
///   void initState() {
///     super.initState();
///     channel = WebSocketChannel.connect(uri);
///   }
///
///   @override
///   void dispose() {
///     channel.sink.close();
///     super.dispose();
///   }
/// }
/// ```
class AvoidWebsocketMemoryLeakRule extends SaropaLintRule {
  const AvoidWebsocketMemoryLeakRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_websocket_memory_leak',
    problemMessage: 'WebSocketChannel must be closed in dispose().',
    correctionMessage: 'Add channel.sink.close() to dispose method.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      if (!_extendsState(node)) return;

      // Find WebSocketChannel fields
      final List<String> wsFields = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toString();
          if (typeName != null &&
              (typeName.contains('WebSocketChannel') ||
                  typeName.contains('IOWebSocketChannel') ||
                  typeName.contains('HtmlWebSocketChannel'))) {
            for (final VariableDeclaration variable
                in member.fields.variables) {
              wsFields.add(variable.name.lexeme);
            }
          }
        }
      }

      if (wsFields.isEmpty) return;

      // Check dispose method for close calls
      final Set<String> closedFields = <String>{};
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          final String disposeSource = member.toSource();
          for (final String field in wsFields) {
            if (disposeSource.contains('$field.sink.close') ||
                disposeSource.contains('$field.close')) {
              closedFields.add(field);
            }
          }
        }
      }

      // Report unclosed channels
      for (final String field in wsFields) {
        if (!closedFields.contains(field)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when VideoPlayerController field is not disposed.
///
/// Alias: dispose_video_controller, video_controller_leak
///
/// VideoPlayerController holds resources that must be released when
/// the widget is disposed to prevent memory leaks.
///
/// **BAD:**
/// ```dart
/// class MyState extends State<MyWidget> {
///   late VideoPlayerController _controller;
///
///   @override
///   void initState() {
///     super.initState();
///     _controller = VideoPlayerController.network(url);
///   }
///   // Missing dispose!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyState extends State<MyWidget> {
///   late VideoPlayerController _controller;
///
///   @override
///   void initState() {
///     super.initState();
///     _controller = VideoPlayerController.network(url);
///   }
///
///   @override
///   void dispose() {
///     _controller.dispose();
///     super.dispose();
///   }
/// }
/// ```
class RequireVideoPlayerControllerDisposeRule extends SaropaLintRule {
  const RequireVideoPlayerControllerDisposeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'require_video_player_controller_dispose',
    problemMessage: 'VideoPlayerController must be disposed.',
    correctionMessage: 'Add _controller.dispose() to dispose method.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      if (!_extendsState(node)) return;

      // Find VideoPlayerController fields
      final List<String> vpFields = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toString();
          if (typeName != null && typeName.contains('VideoPlayerController')) {
            for (final VariableDeclaration variable
                in member.fields.variables) {
              vpFields.add(variable.name.lexeme);
            }
          }
        }
      }

      if (vpFields.isEmpty) return;

      // Check dispose method
      final Set<String> disposedFields = <String>{};
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          final String disposeSource = member.toSource();
          for (final String field in vpFields) {
            if (disposeSource.contains('$field.dispose()')) {
              disposedFields.add(field);
            }
          }
        }
      }

      // Report undisposed controllers
      for (final String field in vpFields) {
        if (!disposedFields.contains(field)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when StreamSubscription is not cancelled in dispose().
///
/// Alias: cancel_stream_subscription, stream_subscription_leak
///
/// StreamSubscription holds references that prevent garbage collection
/// and will continue to receive events after the widget is disposed,
/// potentially causing setState on unmounted widgets.
///
/// **BAD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   StreamSubscription? _subscription;
///
///   @override
///   void initState() {
///     super.initState();
///     _subscription = myStream.listen((data) => setState(() {}));
///   }
///   // Missing cancel - stream will fire after dispose!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   StreamSubscription? _subscription;
///
///   @override
///   void initState() {
///     super.initState();
///     _subscription = myStream.listen((data) => setState(() {}));
///   }
///
///   @override
///   void dispose() {
///     _subscription?.cancel();
///     super.dispose();
///   }
/// }
/// ```
class RequireStreamSubscriptionCancelRule extends SaropaLintRule {
  const RequireStreamSubscriptionCancelRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'require_stream_subscription_cancel',
    problemMessage: 'StreamSubscription must be cancelled in dispose().',
    correctionMessage: 'Add _subscription?.cancel() to dispose method.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      if (!_extendsState(node)) return;

      // Find StreamSubscription fields
      final List<String> subscriptionFields = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toString();
          if (typeName != null && typeName.contains('StreamSubscription')) {
            for (final VariableDeclaration variable
                in member.fields.variables) {
              subscriptionFields.add(variable.name.lexeme);
            }
          }
        }
      }

      if (subscriptionFields.isEmpty) return;

      // Check dispose method for cancel calls
      final Set<String> cancelledFields = <String>{};
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          final String disposeSource = member.toSource();
          for (final String field in subscriptionFields) {
            // Check for various cancel patterns
            if (disposeSource.contains('$field.cancel()') ||
                disposeSource.contains('$field?.cancel()')) {
              cancelledFields.add(field);
            }
          }
        }
      }

      // Report uncancelled subscriptions
      for (final String field in subscriptionFields) {
        if (!cancelledFields.contains(field)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}
