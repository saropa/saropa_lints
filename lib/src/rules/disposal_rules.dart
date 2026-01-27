// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Disposal rules for Flutter/Dart applications.
///
/// These rules ensure that controllers and resources that require
/// explicit disposal are properly cleaned up in dispose() methods.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
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

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_media_player_dispose',
    problemMessage:
        '[require_media_player_dispose] Undisposed media controller holds '
        'audio/video hardware, blocking other apps and draining battery. This can cause resource leaks, app crashes, and poor user experience.',
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

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_tab_controller_dispose',
    problemMessage:
        '[require_tab_controller_dispose] Undisposed TabController leaks '
        'AnimationController, causing memory exhaustion over time.',
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
///
/// Recognizes direct `.dispose()` calls and method names containing "dispose"
/// (e.g., `.disposeSafe()`, `.safeDispose()`), with both `.` and `?.` syntax.
bool _isFieldDisposed(String fieldName, String? disposeBody) {
  if (disposeBody == null) return false;

  // Match fieldName.dispose( or fieldName?.dispose(
  // Also match fieldName.xxxDisposezzz( or fieldName?.xxxDisposezzz(
  final RegExp disposePattern = RegExp(
    '${RegExp.escape(fieldName)}\\??\\.' // fieldName. or fieldName?.
    r'\w*[Dd]ispose\w*\(', // any method containing "dispose"
  );
  return disposePattern.hasMatch(disposeBody);
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

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_text_editing_controller_dispose',
    problemMessage:
        'When a State class creates a TextEditingController for a TextField, search bar, or form input and fails to dispose of it in dispose(), the controller’s internal listeners and text buffers will persist after the widget is removed from the widget tree. This can cause memory leaks, input lag, and unpredictable or stale text field behavior, especially in dynamic forms, chat UIs, or lists where widgets are frequently created and destroyed. In severe cases, this can lead to app slowdowns or crashes due to uncollected resources. Always dispose of every TextEditingController in the owning State object’s dispose() method to ensure proper cleanup. See: https://api.flutter.dev/flutter/widgets/TextEditingController-class.html',
    correctionMessage:
        'For every State class that owns a TextEditingController (for a TextField, search, or form), call controller.dispose() in the dispose() method before calling super.dispose(). This ensures all listeners and buffers are released when the widget is removed, preventing memory leaks, input lag, and unpredictable text field state. Review your widget’s lifecycle and always pair controller creation with proper disposal. See: https://api.flutter.dev/flutter/widgets/TextEditingController-class.html',
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

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_page_controller_dispose',
    problemMessage:
        'Not disposing of a PageController when a widget is removed from the tree can cause memory leaks and continued resource usage, leading to performance issues and potential crashes in long-running apps. This is especially critical in apps with dynamic navigation or frequent page changes. See https://api.flutter.dev/flutter/widgets/PageController/dispose.html.',
    correctionMessage:
        'Dispose of your PageController in the widget’s dispose method to ensure all resources are released and prevent memory leaks. See https://api.flutter.dev/flutter/widgets/PageController/dispose.html for best practices.',
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_lifecycle_observer',
    problemMessage:
        '[require_lifecycle_observer] Long-running timers, streams, or background tasks must be paused or stopped when the app is backgrounded. Failing to observe lifecycle changes can drain battery, consume CPU, and cause stale callbacks to execute when the app resumes, leading to inconsistent state and poor user experience. This may also violate platform guidelines and result in app store rejection.',
    correctionMessage:
        'Implement WidgetsBindingObserver and handle didChangeAppLifecycleState to pause, stop, or clean up background tasks when the app is not active. Document lifecycle handling to ensure resources are managed correctly and the app remains responsive.',
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
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'avoid_websocket_memory_leak',
    problemMessage:
        '[avoid_websocket_memory_leak] WebSocketChannel is not closed in dispose(). This leaves network connections open, wasting bandwidth, battery, and server resources. Unclosed sockets can also cause app crashes or server-side issues.',
    correctionMessage:
        'Call channel.sink.close() in dispose() to properly close the WebSocket connection and free resources.',
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

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_video_player_controller_dispose',
    problemMessage:
        'When a State class creates a VideoPlayerController for a video widget (such as a video player, gallery, carousel, or story view) and does not dispose of it in dispose(), the controller will keep video and audio resources alive after the widget is removed from the widget tree. This can cause memory leaks, background playback, battery drain, and even prevent other apps from acquiring audio focus. In video-heavy UIs or dynamic lists, this can quickly exhaust device resources and degrade app performance. Always dispose of every VideoPlayerController in the owning State object’s dispose() method to ensure proper cleanup. See: https://pub.dev/packages/video_player#disposing',
    correctionMessage:
        'For every State class that owns a VideoPlayerController (for a video player, gallery, carousel, or story view), call controller.dispose() in the dispose() method before calling super.dispose(). This ensures all video and audio resources are released when the widget is removed, preventing leaks, background playback, and resource exhaustion. Review your widget’s lifecycle and always pair controller creation with proper disposal. See: https://pub.dev/packages/video_player#disposing',
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
/// Alias: cancel_stream_subscription, stream_subscription_leak, avoid_unassigned_stream_subscriptions
///
/// StreamSubscription holds references that prevent garbage collection
/// and will continue to receive events after the widget is disposed,
/// potentially causing setState on unmounted widgets.
///
/// This rule detects both single subscriptions and collections of
/// subscriptions (List, Set, LinkedHashSet, HashSet, Iterable, Queue).
///
/// **Supported cancellation patterns:**
/// - Single: `_subscription?.cancel()` or `_subscription.cancel()`
/// - Collection for-in: `for (final sub in _subs) { sub.cancel(); }`
/// - Collection forEach: `_subs.forEach((s) => s.cancel())`
///
/// **Quick fix available:** Adds cancel() calls for uncancelled subscriptions.
/// Creates dispose() method if missing.
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
/// **GOOD (single subscription):**
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
///
/// **GOOD (collection of subscriptions):**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   final List<StreamSubscription<void>> _subscriptions = [];
///
///   @override
///   void dispose() {
///     for (final sub in _subscriptions) {
///       sub.cancel();
///     }
///     super.dispose();
///   }
/// }
/// ```
class RequireStreamSubscriptionCancelRule extends SaropaLintRule {
  const RequireStreamSubscriptionCancelRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_stream_subscription_cancel',
    problemMessage:
        '[require_stream_subscription_cancel] StreamSubscription field without cancel(). '
        'Callbacks fire after State disposal, causing setState errors and memory leaks.',
    correctionMessage:
        'Add _sub?.cancel() in dispose(), or for-in loop for collections.',
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

      // Track single subscriptions and collection subscriptions separately
      final List<String> singleSubscriptionFields = <String>[];
      final List<String> collectionSubscriptionFields = <String>[];

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toString();
          if (typeName != null && typeName.contains('StreamSubscription')) {
            for (final VariableDeclaration variable
                in member.fields.variables) {
              final String fieldName = variable.name.lexeme;
              // Check if it's a collection type (List, Set, Iterable, etc.)
              if (_isCollectionType(typeName)) {
                collectionSubscriptionFields.add(fieldName);
              } else {
                singleSubscriptionFields.add(fieldName);
              }
            }
          }
        }
      }

      // If no subscription fields found, nothing to check
      if (singleSubscriptionFields.isEmpty &&
          collectionSubscriptionFields.isEmpty) {
        return;
      }

      // Check dispose method for cancel calls
      final Set<String> cancelledFields = <String>{};
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          final String disposeSource = member.toSource();

          // Check single subscription fields for direct cancel patterns
          for (final String field in singleSubscriptionFields) {
            if (disposeSource.contains('$field.cancel()') ||
                disposeSource.contains('$field?.cancel()')) {
              cancelledFields.add(field);
            }
          }

          // Check collection subscription fields for iteration-based cancel
          for (final String field in collectionSubscriptionFields) {
            if (_hasCollectionCancellation(disposeSource, field)) {
              cancelledFields.add(field);
            }
          }
        }
      }

      // Report uncancelled single subscriptions
      for (final String field in singleSubscriptionFields) {
        if (!cancelledFields.contains(field)) {
          reporter.atNode(node, code);
          return;
        }
      }

      // Report uncancelled collection subscriptions
      for (final String field in collectionSubscriptionFields) {
        if (!cancelledFields.contains(field)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }

  /// Checks if a type string represents a collection type.
  bool _isCollectionType(String typeName) {
    return typeName.startsWith('List<') ||
        typeName.startsWith('Set<') ||
        typeName.startsWith('LinkedHashSet<') ||
        typeName.startsWith('HashSet<') ||
        typeName.startsWith('Iterable<') ||
        typeName.startsWith('Queue<');
  }

  /// Checks if the dispose method contains proper cancellation for a
  /// collection of subscriptions.
  ///
  /// Recognized patterns:
  /// - `for (final x in field) { x.cancel(); }`
  /// - `field.forEach((x) => x.cancel())`
  /// - `field.forEach((x) { x.cancel(); })`
  bool _hasCollectionCancellation(String disposeSource, String field) {
    // Pattern 1: for-in loop iterating over the field with cancel on loop var
    // Captures the loop variable name and verifies .cancel() is called on it.
    //
    // Regex captures: `for (final/var Type? loopVar in field)`
    // Group 1 = loop variable name (word before " in field")
    final RegExp forInPattern = RegExp(
      r'for\s*\([^)]*?(\w+)\s+in\s+' + RegExp.escape(field) + r'\s*\)',
    );
    final RegExpMatch? forInMatch = forInPattern.firstMatch(disposeSource);
    if (forInMatch != null) {
      final String loopVar = forInMatch.group(1)!;
      // Verify the loop variable has .cancel() called on it
      if (disposeSource.contains('$loopVar.cancel()')) {
        return true;
      }
    }

    // Pattern 2: forEach with cancel on parameter
    // Captures: `field.forEach((param) => param.cancel())` or block body
    final RegExp forEachPattern = RegExp(
      RegExp.escape(field) + r'\.forEach\s*\(\s*\((\w+)\)',
    );
    final RegExpMatch? forEachMatch = forEachPattern.firstMatch(disposeSource);
    if (forEachMatch != null) {
      final String param = forEachMatch.group(1)!;
      // Verify the parameter has .cancel() called on it
      if (disposeSource.contains('$param.cancel()')) {
        return true;
      }
    }

    return false;
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddStreamSubscriptionCancelFix()];
}

/// Quick fix that adds cancel() calls for StreamSubscription fields.
class _AddStreamSubscriptionCancelFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      // Collect uncancelled subscription fields
      final List<_SubscriptionField> uncancelledFields = <_SubscriptionField>[];

      // Find all subscription fields
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toString();
          if (typeName != null && typeName.contains('StreamSubscription')) {
            final bool isNullable = typeName.endsWith('?');
            final bool isCollection = _isCollectionType(typeName);

            for (final VariableDeclaration variable
                in member.fields.variables) {
              uncancelledFields.add(_SubscriptionField(
                name: variable.name.lexeme,
                isNullable: isNullable,
                isCollection: isCollection,
              ));
            }
          }
        }
      }

      if (uncancelledFields.isEmpty) return;

      // Find existing dispose method
      MethodDeclaration? disposeMethod;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeMethod = member;
          break;
        }
      }

      // Check which fields are already cancelled
      if (disposeMethod != null) {
        final String disposeSource = disposeMethod.body.toSource();
        uncancelledFields.removeWhere((field) {
          if (field.isCollection) {
            return _hasCollectionCancellationInSource(
                disposeSource, field.name);
          } else {
            return disposeSource.contains('${field.name}.cancel()') ||
                disposeSource.contains('${field.name}?.cancel()');
          }
        });
      }

      if (uncancelledFields.isEmpty) return;

      // Generate cancel code
      final StringBuffer cancelCode = StringBuffer();
      for (final _SubscriptionField field in uncancelledFields) {
        if (field.isCollection) {
          cancelCode.writeln(
              '    for (final sub in ${field.name}) {\n      sub.cancel();\n    }');
        } else if (field.isNullable) {
          cancelCode.writeln('    ${field.name}?.cancel();');
        } else {
          cancelCode.writeln('    ${field.name}.cancel();');
        }
      }

      if (disposeMethod != null) {
        // Insert cancel calls before super.dispose()
        final String bodySource = disposeMethod.body.toSource();
        final int superDisposeIndex = bodySource.indexOf('super.dispose()');

        if (superDisposeIndex != -1) {
          final int bodyOffset = disposeMethod.body.offset;
          final int insertOffset = bodyOffset + superDisposeIndex;

          final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
            message: 'Add cancel() for StreamSubscription fields',
            priority: 1,
          );

          changeBuilder.addDartFileEdit((builder) {
            builder.addSimpleInsertion(
              insertOffset,
              '${cancelCode.toString().trimRight()}\n    ',
            );
          });
        }
      } else {
        // Create new dispose method
        int insertOffset = node.rightBracket.offset;

        // Find a good insertion point (after fields/constructors)
        for (final ClassMember member in node.members) {
          if (member is FieldDeclaration || member is ConstructorDeclaration) {
            insertOffset = member.end;
          }
        }

        final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
          message: 'Add dispose() method with cancel()',
          priority: 1,
        );

        changeBuilder.addDartFileEdit((builder) {
          builder.addSimpleInsertion(
            insertOffset,
            '\n\n  @override\n  void dispose() {\n${cancelCode}    super.dispose();\n  }',
          );
        });
      }
    });
  }

  /// Checks if a type string represents a collection type.
  bool _isCollectionType(String typeName) {
    return typeName.startsWith('List<') ||
        typeName.startsWith('Set<') ||
        typeName.startsWith('LinkedHashSet<') ||
        typeName.startsWith('HashSet<') ||
        typeName.startsWith('Iterable<') ||
        typeName.startsWith('Queue<');
  }

  /// Checks if dispose source has collection cancellation for a field.
  bool _hasCollectionCancellationInSource(String disposeSource, String field) {
    // Check for-in pattern
    final RegExp forInPattern = RegExp(
      r'for\s*\([^)]*?(\w+)\s+in\s+' + RegExp.escape(field) + r'\s*\)',
    );
    final RegExpMatch? forInMatch = forInPattern.firstMatch(disposeSource);
    if (forInMatch != null) {
      final String loopVar = forInMatch.group(1)!;
      if (disposeSource.contains('$loopVar.cancel()')) {
        return true;
      }
    }

    // Check forEach pattern
    final RegExp forEachPattern = RegExp(
      RegExp.escape(field) + r'\.forEach\s*\(\s*\((\w+)\)',
    );
    final RegExpMatch? forEachMatch = forEachPattern.firstMatch(disposeSource);
    if (forEachMatch != null) {
      final String param = forEachMatch.group(1)!;
      if (disposeSource.contains('$param.cancel()')) {
        return true;
      }
    }

    return false;
  }
}

/// Helper class to track subscription field metadata.
class _SubscriptionField {
  const _SubscriptionField({
    required this.name,
    required this.isNullable,
    required this.isCollection,
  });

  final String name;
  final bool isNullable;
  final bool isCollection;
}

// =============================================================================
// Part 2: Additional Dispose Pattern Rules
// =============================================================================

/// Warns when an owned ChangeNotifier-derived field is not disposed.
///
/// Alias: dispose_change_notifier, change_notifier_leak
///
/// Covers: ChangeNotifier, ValueNotifier, ScrollController,
/// AnimationController, FocusNode. Other controller types
/// (TextEditingController, PageController, TabController) have dedicated
/// rules and are excluded to avoid duplicate violations.
///
/// Only flags fields that are **owned** by this class — i.e., initialized
/// inline with a constructor call or assigned in `initState`. Fields received
/// from callbacks, parameters, or external sources are not flagged.
///
/// Disposal is recognized via direct `.dispose()` calls as well as method
/// names containing "dispose" (e.g., `.disposeSafe()`, `.safeDispose()`).
///
/// **BAD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   final MyNotifier _notifier = MyNotifier();
///   // Missing dispose — listeners leak!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   final MyNotifier _notifier = MyNotifier();
///
///   @override
///   void dispose() {
///     _notifier.dispose();
///     super.dispose();
///   }
/// }
/// ```
class RequireChangeNotifierDisposeRule extends SaropaLintRule {
  const RequireChangeNotifierDisposeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_change_notifier_dispose',
    problemMessage:
        '[require_change_notifier_dispose] Failing to dispose a ChangeNotifier (or ValueNotifier, etc.) in the dispose() method causes it to retain all listeners and references in the widget tree, resulting in memory leaks and potential crashes when notifications are sent to unmounted widgets. This is a common source of subtle bugs and degraded performance in Flutter apps.',
    correctionMessage:
        'Always call notifier.dispose() in your widget’s dispose() method before calling super.dispose(). This ensures all listeners are removed and resources are released. Audit your codebase for all ChangeNotifier instances and verify they are disposed properly.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  // Types with dedicated disposal rules (RequireTextEditingControllerDisposeRule,
  // RequirePageControllerDisposeRule, RequireTabControllerDisposeRule) are
  // excluded to avoid duplicate violations.
  static const Set<String> _changeNotifierTypes = <String>{
    'ChangeNotifier',
    'ValueNotifier',
    'ScrollController',
    'AnimationController',
    'FocusNode',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      if (!_extendsState(node)) return;

      // Find owned ChangeNotifier-derived fields using the same
      // ownership detection as sibling disposal rules
      final List<String> notifierFields = <String>[];
      for (final String notifierType in _changeNotifierTypes) {
        notifierFields.addAll(_findOwnedFieldsOfType(node, notifierType));
      }

      if (notifierFields.isEmpty) return;

      final String? disposeBody = _getDisposeMethodBody(node);
      _reportUndisposedFields(
          node, notifierFields, disposeBody, reporter, code);
    });
  }
}

/// Warns when ReceivePort is not closed in dispose().
///
/// Alias: close_receive_port, receive_port_leak
///
/// ReceivePort holds isolate communication resources that must be closed.
///
/// **BAD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   late ReceivePort _receivePort;
///
///   @override
///   void initState() {
///     super.initState();
///     _receivePort = ReceivePort();
///   }
///   // Missing close!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   late ReceivePort _receivePort;
///
///   @override
///   void initState() {
///     super.initState();
///     _receivePort = ReceivePort();
///   }
///
///   @override
///   void dispose() {
///     _receivePort.close();
///     super.dispose();
///   }
/// }
/// ```
class RequireReceivePortCloseRule extends SaropaLintRule {
  const RequireReceivePortCloseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_receive_port_close',
    problemMessage:
        'Leaving a ReceivePort open after it is no longer needed can cause memory leaks and keep isolates alive unnecessarily, leading to wasted resources and potential app instability. This can also prevent garbage collection of related objects. See https://dart.dev/guides/libraries/concurrency#isolates.',
    correctionMessage:
        'Close the ReceivePort when it is no longer needed to free resources and allow isolates to terminate cleanly. See https://dart.dev/guides/libraries/concurrency#isolates for best practices.',
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

      // Find ReceivePort fields
      final List<String> portFields = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toSource();
          if (typeName != null && typeName.contains('ReceivePort')) {
            for (final VariableDeclaration variable
                in member.fields.variables) {
              portFields.add(variable.name.lexeme);
            }
          }
        }
      }

      if (portFields.isEmpty) return;

      // Check dispose method for close calls
      String? disposeBody;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeBody = member.body.toSource();
          break;
        }
      }

      for (final String field in portFields) {
        final bool isClosed = disposeBody != null &&
            (disposeBody.contains('$field.close()') ||
                disposeBody.contains('$field?.close()'));
        if (!isClosed) {
          for (final ClassMember member in node.members) {
            if (member is FieldDeclaration) {
              for (final VariableDeclaration variable
                  in member.fields.variables) {
                if (variable.name.lexeme == field) {
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

/// Warns when Socket is not closed in dispose().
///
/// Alias: close_socket, socket_leak
///
/// Socket connections must be closed to release network resources.
///
/// **BAD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   Socket? _socket;
///
///   Future<void> connect() async {
///     _socket = await Socket.connect('host', 80);
///   }
///   // Missing close!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   Socket? _socket;
///
///   Future<void> connect() async {
///     _socket = await Socket.connect('host', 80);
///   }
///
///   @override
///   void dispose() {
///     _socket?.close();
///     super.dispose();
///   }
/// }
/// ```
class RequireSocketCloseRule extends SaropaLintRule {
  const RequireSocketCloseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_socket_close',
    problemMessage:
        '[require_socket_close] Not closing a Socket keeps the TCP connection open indefinitely, occupying server connection slots, leaking file descriptors, and potentially exhausting OS resources. This can prevent new network connections and degrade app or system performance.',
    correctionMessage:
        'Always call _socket?.close() in your widget’s dispose() method before calling super.dispose(). This ensures the connection is closed and resources are released. Audit your codebase for all Socket instances and verify they are closed properly.',
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

      // Find Socket fields
      final List<String> socketFields = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toSource();
          if (typeName != null &&
              (typeName == 'Socket' ||
                  typeName == 'Socket?' ||
                  typeName.contains('SecureSocket'))) {
            for (final VariableDeclaration variable
                in member.fields.variables) {
              socketFields.add(variable.name.lexeme);
            }
          }
        }
      }

      if (socketFields.isEmpty) return;

      // Check dispose method for close calls
      String? disposeBody;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeBody = member.body.toSource();
          break;
        }
      }

      for (final String field in socketFields) {
        final bool isClosed = disposeBody != null &&
            (disposeBody.contains('$field.close()') ||
                disposeBody.contains('$field?.close()') ||
                disposeBody.contains('$field.destroy()') ||
                disposeBody.contains('$field?.destroy()'));
        if (!isClosed) {
          for (final ClassMember member in node.members) {
            if (member is FieldDeclaration) {
              for (final VariableDeclaration variable
                  in member.fields.variables) {
                if (variable.name.lexeme == field) {
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

/// Warns when a debouncer Timer is not cancelled in dispose().
///
/// Alias: cancel_debouncer, debouncer_leak
///
/// Debounce timers used for search or input delay must be cancelled
/// to prevent callbacks firing after widget disposal.
///
/// **BAD:**
/// ```dart
/// class _SearchState extends State<Search> {
///   Timer? _debounce;
///
///   void _onSearchChanged(String query) {
///     _debounce?.cancel();
///     _debounce = Timer(Duration(milliseconds: 500), () {
///       performSearch(query);
///     });
///   }
///   // Missing cancel in dispose!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _SearchState extends State<Search> {
///   Timer? _debounce;
///
///   void _onSearchChanged(String query) {
///     _debounce?.cancel();
///     _debounce = Timer(Duration(milliseconds: 500), () {
///       performSearch(query);
///     });
///   }
///
///   @override
///   void dispose() {
///     _debounce?.cancel();
///     super.dispose();
///   }
/// }
/// ```
class RequireDebouncerCancelRule extends SaropaLintRule {
  const RequireDebouncerCancelRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_debouncer_cancel',
    problemMessage:
        '[require_debouncer_cancel] Uncancelled debounce timer fires after '
        'dispose, calling setState on unmounted widget causing crashes.',
    correctionMessage: 'Add _debounce?.cancel() in the dispose() method.',
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

      // Find Timer fields
      final List<String> timerFields = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toSource();
          if (typeName != null &&
              (typeName == 'Timer' || typeName == 'Timer?')) {
            for (final VariableDeclaration variable
                in member.fields.variables) {
              timerFields.add(variable.name.lexeme);
            }
          }
        }
      }

      if (timerFields.isEmpty) return;

      // Check dispose method for cancel calls
      String? disposeBody;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeBody = member.body.toSource();
          break;
        }
      }

      for (final String field in timerFields) {
        final bool isCancelled = disposeBody != null &&
            (disposeBody.contains('$field.cancel()') ||
                disposeBody.contains('$field?.cancel()'));
        if (!isCancelled) {
          for (final ClassMember member in node.members) {
            if (member is FieldDeclaration) {
              for (final VariableDeclaration variable
                  in member.fields.variables) {
                if (variable.name.lexeme == field) {
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

/// Warns when Timer.periodic is not cancelled in dispose().
///
/// Alias: cancel_interval_timer, periodic_timer_leak
///
/// Periodic timers keep firing indefinitely. Not cancelling them
/// wastes resources and can call setState on disposed widgets.
///
/// **BAD:**
/// ```dart
/// class _ClockState extends State<Clock> {
///   Timer? _timer;
///
///   @override
///   void initState() {
///     super.initState();
///     _timer = Timer.periodic(Duration(seconds: 1), (_) {
///       setState(() {});
///     });
///   }
///   // Missing cancel - timer runs forever!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _ClockState extends State<Clock> {
///   Timer? _timer;
///
///   @override
///   void initState() {
///     super.initState();
///     _timer = Timer.periodic(Duration(seconds: 1), (_) {
///       setState(() {});
///     });
///   }
///
///   @override
///   void dispose() {
///     _timer?.cancel();
///     super.dispose();
///   }
/// }
/// ```
class RequireIntervalTimerCancelRule extends SaropaLintRule {
  const RequireIntervalTimerCancelRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_interval_timer_cancel',
    problemMessage:
        '[require_interval_timer_cancel] Timer.periodic without cancel(). '
        'Timer keeps firing after State disposal, draining battery and causing setState errors.',
    correctionMessage:
        'Add _timer?.cancel() in dispose() before super.dispose().',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Track Timer.periodic assignments in State classes
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for Timer.periodic
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (targetSource != 'Timer') return;
      if (node.methodName.name != 'periodic') return;

      // Find enclosing class
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

      // Check if the result is assigned to a field
      AstNode? parent = node.parent;
      String? fieldName;

      if (parent is AssignmentExpression) {
        final leftSide = parent.leftHandSide;
        if (leftSide is SimpleIdentifier) {
          fieldName = leftSide.name;
        } else if (leftSide is PrefixedIdentifier) {
          fieldName = leftSide.identifier.name;
        }
      } else if (parent is VariableDeclaration) {
        fieldName = parent.name.lexeme;
      }

      if (fieldName == null) {
        // Timer.periodic called but not stored - always a problem
        reporter.atNode(node.methodName, code);
        return;
      }

      // Check dispose method for cancel call
      String? disposeBody;
      for (final ClassMember member in enclosingClass.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeBody = member.body.toSource();
          break;
        }
      }

      final bool isCancelled = disposeBody != null &&
          (disposeBody.contains('$fieldName.cancel()') ||
              disposeBody.contains('$fieldName?.cancel()'));

      if (!isCancelled) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when RandomAccessFile is not closed.
///
/// Alias: close_file_handle, file_handle_leak
///
/// RandomAccessFile holds a file handle that must be released.
/// Not closing it can exhaust file descriptors.
///
/// **BAD:**
/// ```dart
/// class _FileReaderState extends State<FileReader> {
///   RandomAccessFile? _file;
///
///   Future<void> openFile() async {
///     _file = await File('path').open();
///   }
///   // Missing close!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _FileReaderState extends State<FileReader> {
///   RandomAccessFile? _file;
///
///   Future<void> openFile() async {
///     _file = await File('path').open();
///   }
///
///   @override
///   void dispose() {
///     _file?.closeSync();
///     super.dispose();
///   }
/// }
/// ```
class RequireFileHandleCloseRule extends SaropaLintRule {
  const RequireFileHandleCloseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_file_handle_close',
    problemMessage:
        '[require_file_handle_close] File handles (e.g., RandomAccessFile) must be closed to release system resources. Failing to close files can cause resource leaks, file access errors, and may prevent other apps or processes from accessing the file. This can lead to app crashes, data loss, and degraded device performance.',
    correctionMessage:
        'Always call close() or closeSync() on file handles in dispose() or finally blocks. Document file cleanup to prevent resource leaks and ensure reliable file access.',
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

      // Find RandomAccessFile fields
      final List<String> fileFields = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toSource();
          if (typeName != null &&
              (typeName == 'RandomAccessFile' ||
                  typeName == 'RandomAccessFile?')) {
            for (final VariableDeclaration variable
                in member.fields.variables) {
              fileFields.add(variable.name.lexeme);
            }
          }
        }
      }

      if (fileFields.isEmpty) return;

      // Check dispose method for close calls
      String? disposeBody;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeBody = member.body.toSource();
          break;
        }
      }

      for (final String field in fileFields) {
        final bool isClosed = disposeBody != null &&
            (disposeBody.contains('$field.close()') ||
                disposeBody.contains('$field?.close()') ||
                disposeBody.contains('$field.closeSync()') ||
                disposeBody.contains('$field?.closeSync()'));
        if (!isClosed) {
          for (final ClassMember member in node.members) {
            if (member is FieldDeclaration) {
              for (final VariableDeclaration variable
                  in member.fields.variables) {
                if (variable.name.lexeme == field) {
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

// =============================================================================
// Part 3: Resource Lifecycle Rules
// =============================================================================

/// Warns when a StatefulWidget has disposable resources but no dispose() method.
///
/// StatefulWidgets that create controllers, subscriptions, timers, or other
/// resources must implement dispose() to clean up those resources. Missing
/// dispose() leads to memory leaks, dangling callbacks, and resource exhaustion.
///
/// **BAD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   final TextEditingController _controller = TextEditingController();
///   StreamSubscription? _subscription;
///   Timer? _timer;
///
///   @override
///   void initState() {
///     super.initState();
///     _subscription = stream.listen((_) {});
///     _timer = Timer.periodic(Duration(seconds: 1), (_) {});
///   }
///   // Missing dispose() - all resources leak!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   final TextEditingController _controller = TextEditingController();
///   StreamSubscription? _subscription;
///   Timer? _timer;
///
///   @override
///   void initState() {
///     super.initState();
///     _subscription = stream.listen((_) {});
///     _timer = Timer.periodic(Duration(seconds: 1), (_) {});
///   }
///
///   @override
///   void dispose() {
///     _controller.dispose();
///     _subscription?.cancel();
///     _timer?.cancel();
///     super.dispose();
///   }
/// }
/// ```
class RequireDisposeImplementationRule extends SaropaLintRule {
  const RequireDisposeImplementationRule() : super(code: _code);

  /// Critical - resources leak without dispose.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_dispose_implementation',
    problemMessage:
        '[require_dispose_implementation] Controllers, subscriptions, or timers '
        'without cleanup cause memory leaks and setState errors.',
    correctionMessage:
        'Add dispose() method to clean up controllers, subscriptions, and timers.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Types that require disposal or cleanup.
  static const Set<String> _disposableTypes = <String>{
    // Controllers
    'TextEditingController',
    'AnimationController',
    'TabController',
    'PageController',
    'ScrollController',
    'VideoPlayerController',
    'FocusNode',
    'StreamController',

    // Subscriptions and timers
    'StreamSubscription',
    'Timer',

    // Other disposables
    'ChangeNotifier',
    'ValueNotifier',
    'WebSocketChannel',
    'Socket',
    'ReceivePort',
    'RandomAccessFile',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      if (!_extendsState(node)) return;

      // Find disposable resource fields
      final List<String> disposableFields = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toSource();
          if (typeName != null) {
            for (final String disposableType in _disposableTypes) {
              if (typeName.contains(disposableType)) {
                for (final VariableDeclaration variable
                    in member.fields.variables) {
                  disposableFields.add(variable.name.lexeme);
                }
                break;
              }
            }
          }
        }
      }

      if (disposableFields.isEmpty) return;

      // Check if dispose method exists
      bool hasDispose = false;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          hasDispose = true;
          break;
        }
      }

      if (!hasDispose) {
        // Report on the class name token
        reporter.atToken(node.name, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddDisposeMethodFix()];
}

class _AddDisposeMethodFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      // Find the last member to insert after
      int insertOffset = node.rightBracket.offset;
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration || member is ConstructorDeclaration) {
          insertOffset = member.end;
        }
      }

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add dispose() method',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          insertOffset,
          '\n\n  @override\n  void dispose() {\n    // TODO: Dispose resources here\n    super.dispose();\n  }',
        );
      });
    });
  }
}

/// Warns when a disposable field is reassigned without disposing the old value.
///
/// When a field holding a disposable resource (controller, subscription, etc.)
/// is reassigned, the old value must be disposed first. Otherwise, the old
/// resource leaks and continues holding memory or executing callbacks.
///
/// **BAD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   TextEditingController? _controller;
///
///   void _updateController() {
///     // Old controller leaks!
///     _controller = TextEditingController(text: 'new value');
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   TextEditingController? _controller;
///
///   void _updateController() {
///     _controller?.dispose();  // Dispose old value first
///     _controller = TextEditingController(text: 'new value');
///   }
/// }
/// ```
///
/// **ALSO GOOD (using cascade):**
/// ```dart
/// void _updateController() {
///   _controller
///     ?..dispose()
///     ..text = '';
///   _controller = TextEditingController(text: 'new value');
/// }
/// ```
class PreferDisposeBeforeNewInstanceRule extends SaropaLintRule {
  const PreferDisposeBeforeNewInstanceRule() : super(code: _code);

  /// Critical - old resources leak on reassignment.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'prefer_dispose_before_new_instance',
    problemMessage:
        '[prefer_dispose_before_new_instance] Reassigning without dispose leaks '
        'the old instance. Listeners and resources remain active forever.',
    correctionMessage:
        'Call dispose() on the old value before assigning a new instance.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Types that require disposal before reassignment.
  static const Set<String> _disposableTypes = <String>{
    'TextEditingController',
    'AnimationController',
    'TabController',
    'PageController',
    'ScrollController',
    'VideoPlayerController',
    'FocusNode',
    'StreamController',
    'ChangeNotifier',
    'ValueNotifier',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAssignmentExpression((AssignmentExpression node) {
      // Only check simple assignments (=), not compound (+=, etc.)
      if (node.operator.lexeme != '=') return;

      // Check if assigning to a field (not a local variable)
      final Expression leftSide = node.leftHandSide;
      String? fieldName;

      if (leftSide is SimpleIdentifier) {
        fieldName = leftSide.name;
      } else if (leftSide is PrefixedIdentifier) {
        // this.fieldName or similar
        fieldName = leftSide.identifier.name;
      } else {
        return;
      }

      // Check if the right side is creating a new instance of a disposable type
      final Expression rightSide = node.rightHandSide;
      if (rightSide is! InstanceCreationExpression) return;

      final String typeName = rightSide.constructorName.type.name.lexeme;
      if (!_disposableTypes.contains(typeName)) return;

      // Find enclosing class to verify this is a field assignment
      AstNode? current = node.parent;
      ClassDeclaration? enclosingClass;
      MethodDeclaration? enclosingMethod;

      while (current != null) {
        if (current is MethodDeclaration) {
          enclosingMethod = current;
        }
        if (current is ClassDeclaration) {
          enclosingClass = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingClass == null || enclosingMethod == null) return;

      // Skip if this is in initState (first initialization)
      if (enclosingMethod.name.lexeme == 'initState') return;

      // Skip if this is in a constructor
      if (enclosingMethod.name.lexeme == enclosingClass.name.lexeme) return;

      // Check if fieldName is actually a field of this class
      bool isField = false;
      for (final ClassMember member in enclosingClass.members) {
        if (member is FieldDeclaration) {
          for (final VariableDeclaration variable in member.fields.variables) {
            if (variable.name.lexeme == fieldName) {
              isField = true;
              break;
            }
          }
        }
        if (isField) break;
      }

      if (!isField) return;

      // Check if there's a dispose() call before this assignment in the same block
      final Block? enclosingBlock = _findEnclosingBlock(node);
      if (enclosingBlock == null) return;

      final bool hasDisposeBeforeAssignment =
          _hasDisposeCallBefore(enclosingBlock, node, fieldName);

      if (!hasDisposeBeforeAssignment) {
        reporter.atNode(node, code);
      }
    });
  }

  Block? _findEnclosingBlock(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is Block) return current;
      current = current.parent;
    }
    return null;
  }

  bool _hasDisposeCallBefore(
    Block block,
    AssignmentExpression targetAssignment,
    String fieldName,
  ) {
    // Look for fieldName.dispose() or fieldName?.dispose() before the assignment
    final int assignmentOffset = targetAssignment.offset;

    for (final Statement statement in block.statements) {
      // Only check statements before our assignment
      if (statement.offset >= assignmentOffset) break;

      final String statementSource = statement.toSource();

      // Check for dispose patterns
      if (statementSource.contains('$fieldName.dispose()') ||
          statementSource.contains('$fieldName?.dispose()') ||
          statementSource.contains('$fieldName..dispose()') ||
          statementSource.contains('$fieldName?..dispose()')) {
        return true;
      }
    }

    return false;
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddDisposeBeforeAssignmentFix()];
}

class _AddDisposeBeforeAssignmentFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addAssignmentExpression((AssignmentExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final Expression leftSide = node.leftHandSide;
      String? fieldName;

      if (leftSide is SimpleIdentifier) {
        fieldName = leftSide.name;
      } else if (leftSide is PrefixedIdentifier) {
        fieldName = leftSide.identifier.name;
      }

      if (fieldName == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add dispose() call before reassignment',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Find the start of the statement containing this assignment
        AstNode? current = node.parent;
        while (current != null && current is! Statement) {
          current = current.parent;
        }

        final int insertOffset = current?.offset ?? node.offset;

        builder.addSimpleInsertion(
          insertOffset,
          '$fieldName?.dispose();\n    ',
        );
      });
    });
  }
}

// =============================================================================
// NEW ROADMAP STAR RULES - Disposal Rules
// =============================================================================

/// Warns when class fields of disposable types are not disposed.
///
/// Classes with disposable fields (controllers, subscriptions, etc.) should
/// implement disposal to prevent memory leaks.
///
/// **BAD:**
/// ```dart
/// class MyService {
///   final _controller = StreamController<int>();
///   // No close() called!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyService {
///   final _controller = StreamController<int>();
///
///   void dispose() {
///     _controller.close();
///   }
/// }
/// ```
class DisposeClassFieldsRule extends SaropaLintRule {
  const DisposeClassFieldsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'dispose_class_fields',
    problemMessage:
        '[dispose_class_fields] Class has disposable fields but no dispose/close method. '
        'This may cause memory leaks.',
    correctionMessage:
        'Add a dispose() or close() method that cleans up all disposable fields.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _disposableTypes = <String>{
    'StreamController',
    'StreamSubscription',
    'TextEditingController',
    'ScrollController',
    'PageController',
    'TabController',
    'AnimationController',
    'FocusNode',
    'Timer',
    'ValueNotifier',
    'ChangeNotifier',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Skip Flutter widget classes (they have their own disposal patterns)
      // - StatefulWidget: disposal is handled by its State class
      // - StatelessWidget: has no lifecycle, cannot dispose anything
      // - State: has dedicated disposal rules (RequireDisposeImplementationRule, etc.)
      // Also skip common base classes that handle their own disposal
      final extendsClause = node.extendsClause;
      if (extendsClause != null) {
        final superName = extendsClause.superclass.name.lexeme;
        if (superName == 'State' ||
            superName == 'StatefulWidget' ||
            superName == 'StatelessWidget' ||
            superName == 'GetxController' ||
            superName == 'ChangeNotifier') {
          return;
        }
      }

      // Collect constructor parameter names to exclude passed-in fields
      final Set<String> constructorParams = <String>{};
      for (final member in node.members) {
        if (member is ConstructorDeclaration) {
          // Check formal parameters
          for (final param in member.parameters.parameters) {
            if (param is DefaultFormalParameter) {
              final normalParam = param.parameter;
              if (normalParam is FieldFormalParameter) {
                constructorParams.add(normalParam.name.lexeme);
              } else if (normalParam is SimpleFormalParameter) {
                constructorParams.add(normalParam.name?.lexeme ?? '');
              }
            } else if (param is FieldFormalParameter) {
              constructorParams.add(param.name.lexeme);
            } else if (param is SimpleFormalParameter) {
              constructorParams.add(param.name?.lexeme ?? '');
            }
          }
        }
      }

      // Find disposable fields that are OWNED by this class (not passed in)
      final List<String> disposableFields = <String>[];
      for (final member in node.members) {
        if (member is FieldDeclaration) {
          final typeName = member.fields.type?.toSource();
          if (typeName != null) {
            for (final disposable in _disposableTypes) {
              if (typeName.contains(disposable)) {
                for (final variable in member.fields.variables) {
                  final fieldName = variable.name.lexeme;
                  // Skip fields that are passed in via constructor
                  if (constructorParams.contains(fieldName)) {
                    continue;
                  }
                  // Only include fields that are initialized inline or have
                  // no initializer (meaning they'll be set up in initState
                  // or similar lifecycle method)
                  final initializer = variable.initializer;
                  if (initializer != null) {
                    // Field is initialized inline - check if it's a constructor
                    final initSource = initializer.toSource();
                    if (initSource.startsWith('$disposable(') ||
                        initSource.startsWith('$disposable.')) {
                      disposableFields.add(fieldName);
                    }
                  }
                  // Note: Fields with no initializer and not in constructor
                  // params are likely late fields initialized in methods,
                  // which should be checked by other rules (like
                  // RequireDisposeImplementationRule for State classes)
                }
                break;
              }
            }
          }
        }
      }

      if (disposableFields.isEmpty) return;

      // Check for dispose/close method
      bool hasDisposeMethod = false;
      for (final member in node.members) {
        if (member is MethodDeclaration) {
          final name = member.name.lexeme;
          if (name == 'dispose' || name == 'close') {
            hasDisposeMethod = true;
            break;
          }
        }
      }

      if (!hasDisposeMethod) {
        reporter.atToken(node.name, code);
      }
    });
  }
}
