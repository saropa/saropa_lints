// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Resource management lint rules for Flutter/Dart applications.
///
/// These rules help ensure proper handling of system resources like
/// files, sockets, databases, and native resources to prevent leaks.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when file handle is not closed in finally block.
///
/// File handles should be closed in finally blocks or use try-with-resources
/// pattern to ensure cleanup even when exceptions occur.
///
/// **BAD:**
/// ```dart
/// Future<String> readFile(String path) async {
///   final file = File(path).openRead();
///   final contents = await file.transform(utf8.decoder).join();
///   // file not closed if exception occurs
///   return contents;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<String> readFile(String path) async {
///   final file = File(path);
///   return file.readAsString(); // Handles closing internally
/// }
/// // Or with explicit close:
/// final sink = file.openWrite();
/// try {
///   await sink.write(data);
/// } finally {
///   await sink.close();
/// }
/// ```
class RequireFileCloseInFinallyRule extends SaropaLintRule {
  const RequireFileCloseInFinallyRule() : super(code: _code);

  /// Unclosed file handles leak system resources.
  /// Each occurrence is a resource leak.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_file_close_in_finally',
    problemMessage:
        '[require_file_close_in_finally] Unclosed file handle on exception '
        'leaks file descriptor, exhausting system limits.',
    correctionMessage:
        'Use try-finally or convenience methods like readAsString().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// File-specific open methods that are unlikely to have false positives.
  static const Set<String> _fileOpenMethods = <String>{
    'openRead',
    'openWrite',
    'openSync',
  };

  /// Patterns that indicate file-related code is present.
  static const Set<String> _fileIndicators = <String>{
    'File(',
    'IOSink',
    'RandomAccessFile',
    'dart:io',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Check for file-specific open methods (low false positive risk)
      bool hasFileOpen = false;
      for (final String method in _fileOpenMethods) {
        if (bodySource.contains('.$method(')) {
          hasFileOpen = true;
          break;
        }
      }

      // For generic '.open(' we need additional evidence of file handling
      // to avoid false positives from other classes with open() methods
      if (!hasFileOpen && bodySource.contains('.open(')) {
        for (final String indicator in _fileIndicators) {
          if (bodySource.contains(indicator)) {
            hasFileOpen = true;
            break;
          }
        }
      }

      if (!hasFileOpen) return;

      // Check for proper cleanup
      final bool hasFinally = bodySource.contains('finally');
      final bool hasClose = bodySource.contains('.close(');

      if (!hasFinally && hasClose) {
        // Close without finally - may leak on exception
        reporter.atNode(node, code);
      } else if (!hasClose &&
          !bodySource.contains('readAsString') &&
          !bodySource.contains('readAsBytes') &&
          !bodySource.contains('writeAsString') &&
          !bodySource.contains('writeAsBytes')) {
        // No close at all
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when database connection is not properly closed.
///
/// Database connections are expensive resources that must be closed
/// to prevent connection pool exhaustion.
///
/// **BAD:**
/// ```dart
/// Future<User> getUser(int id) async {
///   final db = await openDatabase('app.db');
///   final result = await db.query('users', where: 'id = ?', whereArgs: [id]);
///   return User.fromMap(result.first);
///   // db never closed
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<User> getUser(int id) async {
///   final db = await openDatabase('app.db');
///   try {
///     final result = await db.query('users', where: 'id = ?', whereArgs: [id]);
///     return User.fromMap(result.first);
///   } finally {
///     await db.close();
///   }
/// }
/// ```
class RequireDatabaseCloseRule extends SaropaLintRule {
  const RequireDatabaseCloseRule() : super(code: _code);

  /// Unclosed database connections exhaust connection pools.
  /// Each occurrence is a resource leak.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_database_close',
    problemMessage:
        '[require_database_close] Unclosed database connection leaks resources '
        'and may exhaust connection pool, causing app failures.',
    correctionMessage:
        'Close database in finally block or use connection pool.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Patterns that indicate actual database instantiation.
  /// Uses word boundary patterns to avoid false positives like 'initIsarDatabase('.
  static final RegExp _dbOpenPattern = RegExp(
    r'(?:^|[^a-zA-Z])(?:openDatabase|Database\(|SqliteDatabase)',
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Check for database open calls with word boundary to avoid
      // false positives from method names like 'initIsarDatabase'
      if (!_dbOpenPattern.hasMatch(bodySource)) {
        return;
      }

      // Check for close (including *Safe extension variants)
      if (!bodySource.contains('.close(') &&
          !bodySource.contains('.closeSafe(') &&
          !bodySource.contains('dispose') &&
          !bodySource.contains('disposeSafe')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when HttpClient is not closed.
///
/// HttpClient maintains connection pools and should be closed
/// when no longer needed to free resources.
///
/// **BAD:**
/// ```dart
/// Future<String> fetch(String url) async {
///   final client = HttpClient();
///   final request = await client.getUrl(Uri.parse(url));
///   final response = await request.close();
///   // client never closed
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<String> fetch(String url) async {
///   final client = HttpClient();
///   try {
///     final request = await client.getUrl(Uri.parse(url));
///     final response = await request.close();
///     return await response.transform(utf8.decoder).join();
///   } finally {
///     client.close();
///   }
/// }
/// ```
class RequireHttpClientCloseRule extends SaropaLintRule {
  const RequireHttpClientCloseRule() : super(code: _code);

  /// Unclosed HttpClient holds connection pools and leaks sockets.
  /// Each occurrence is a resource leak.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_http_client_close',
    problemMessage:
        '[require_http_client_close] Unclosed HttpClient leaks socket '
        'connections and memory, eventually exhausting system resources.',
    correctionMessage: 'Call client.close() in finally block.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Check for HttpClient creation
      if (!bodySource.contains('HttpClient()')) return;

      // Check for close (including *Safe extension variants)
      if (!bodySource.contains('.close(') &&
          !bodySource.contains('.closeSafe(') &&
          !bodySource.contains('.close;')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when native resources are allocated without cleanup.
///
/// Native resources (FFI, platform channels) must be explicitly freed
/// to prevent memory leaks outside Dart's garbage collector.
///
/// **BAD:**
/// ```dart
/// void processImage() {
///   final pointer = calloc<Uint8>(1024);
///   // pointer never freed
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void processImage() {
///   final pointer = calloc<Uint8>(1024);
///   try {
///     // Use pointer
///   } finally {
///     calloc.free(pointer);
///   }
/// }
/// ```
class RequireNativeResourceCleanupRule extends SaropaLintRule {
  const RequireNativeResourceCleanupRule() : super(code: _code);

  /// Unfreed native memory leaks outside Dart's garbage collector.
  /// Each occurrence is a memory leak.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_native_resource_cleanup',
    problemMessage:
        '[require_native_resource_cleanup] Unfreed native memory leaks '
        'outside Dart GC, causing permanent memory loss until app restart.',
    correctionMessage: 'Call free() in finally block for native allocations.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _allocMethods = <String>{
    'calloc<',
    'malloc<',
    'allocate(',
    'Pointer.fromAddress',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Check for native allocation
      bool hasAlloc = false;
      for (final String method in _allocMethods) {
        if (bodySource.contains(method)) {
          hasAlloc = true;
          break;
        }
      }

      if (!hasAlloc) return;

      // Check for cleanup
      if (!bodySource.contains('.free(') &&
          !bodySource.contains('free(') &&
          !bodySource.contains('finally')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when WebSocket is not closed on dispose.
///
/// Alias: require_web_socket_close
///
/// WebSocket connections should be closed when the widget or service
/// is disposed to prevent resource leaks.
///
/// **BAD:**
/// ```dart
/// class _ChatState extends State<Chat> {
///   late WebSocket _socket;
///
///   void initState() {
///     super.initState();
///     _socket = WebSocket.connect('wss://example.com');
///   }
///   // Missing dispose
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _ChatState extends State<Chat> {
///   late WebSocket _socket;
///
///   void initState() {
///     super.initState();
///     _socket = WebSocket.connect('wss://example.com');
///   }
///
///   void dispose() {
///     _socket.close();
///     super.dispose();
///   }
/// }
/// ```
class RequireWebSocketCloseRule extends SaropaLintRule {
  const RequireWebSocketCloseRule() : super(code: _code);

  /// Unclosed WebSocket connections leak sockets and may cause errors.
  /// Each occurrence is a resource leak.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_websocket_close',
    problemMessage:
        '[require_websocket_close] Unclosed WebSocket leaks connections and '
        'continues receiving data after widget disposal, causing errors.',
    correctionMessage: 'Add _socket.close() in dispose method.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if this is a State class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.toSource();
      if (!superName.startsWith('State<')) return;

      // Check for WebSocket fields
      bool hasWebSocket = false;
      bool hasDisposeClose = false;

      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String fieldSource = member.toSource();
          if (fieldSource.contains('WebSocket') ||
              fieldSource.contains('WebSocketChannel')) {
            hasWebSocket = true;
          }
        }

        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          final String disposeSource = member.body.toSource();
          // Check for close (including *Safe extension variants)
          if (disposeSource.contains('.close(') ||
              disposeSource.contains('.closeSafe(') ||
              disposeSource.contains('.sink.close')) {
            hasDisposeClose = true;
          }
        }
      }

      if (hasWebSocket && !hasDisposeClose) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Platform Channel is used without cleanup.
///
/// MethodChannel and EventChannel handlers should be removed
/// when no longer needed to prevent memory leaks.
///
/// **BAD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   final channel = MethodChannel('my_channel');
///
///   void initState() {
///     super.initState();
///     channel.setMethodCallHandler(_handleCall);
///   }
///   // Handler never removed
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   final channel = MethodChannel('my_channel');
///
///   void initState() {
///     super.initState();
///     channel.setMethodCallHandler(_handleCall);
///   }
///
///   void dispose() {
///     channel.setMethodCallHandler(null);
///     super.dispose();
///   }
/// }
/// ```
class RequirePlatformChannelCleanupRule extends SaropaLintRule {
  const RequirePlatformChannelCleanupRule() : super(code: _code);

  /// Platform channel handlers prevent garbage collection of State.
  /// Each occurrence is a memory leak.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_platform_channel_cleanup',
    problemMessage:
        '[require_platform_channel_cleanup] Active platform channel handler '
        'receives callbacks after dispose, causing setState on unmounted widget.',
    correctionMessage: 'Set handler to null in dispose method.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Check if this is a State class
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.toSource();
      if (!superName.startsWith('State<')) return;

      final String classSource = node.toSource();

      // Check for channel handler setup
      if (!classSource.contains('setMethodCallHandler') &&
          !classSource.contains('receiveBroadcastStream')) {
        return;
      }

      // Check for cleanup in dispose
      bool hasDispose = false;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          hasDispose = true;
          final String disposeSource = member.body.toSource();
          // Check if handler is nullified or subscription cancelled
          // (including *Safe extension variants)
          if (disposeSource.contains('setMethodCallHandler(null)') ||
              disposeSource.contains('.cancel(') ||
              disposeSource.contains('.cancelSafe(')) {
            return; // Good - cleanup found
          }
        }
      }

      if (!hasDispose || classSource.contains('setMethodCallHandler')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Isolate is spawned without being killed.
///
/// Spawned isolates should be killed when no longer needed
/// to free system resources.
///
/// **BAD:**
/// ```dart
/// class Processor {
///   late Isolate _isolate;
///
///   Future<void> start() async {
///     _isolate = await Isolate.spawn(processData, data);
///   }
///   // Isolate never killed
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class Processor {
///   Isolate? _isolate;
///
///   Future<void> start() async {
///     _isolate = await Isolate.spawn(processData, data);
///   }
///
///   void dispose() {
///     _isolate?.kill();
///     _isolate = null;
///   }
/// }
/// ```
class RequireIsolateKillRule extends SaropaLintRule {
  const RequireIsolateKillRule() : super(code: _code);

  /// Orphaned isolates consume memory and CPU resources.
  /// Each occurrence is a resource leak.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_isolate_kill',
    problemMessage:
        '[require_isolate_kill] Unkilled Isolate continues consuming CPU and '
        'memory, and may send messages to disposed handlers causing crashes.',
    correctionMessage: 'Call isolate.kill() in cleanup/dispose method.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final String classSource = node.toSource();

      // Check for Isolate.spawn
      if (!classSource.contains('Isolate.spawn') &&
          !classSource.contains('Isolate.spawnUri')) {
        return;
      }

      // Check for kill
      if (!classSource.contains('.kill(')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when CameraController is not disposed.
///
/// CameraController holds native camera resources that must be released.
/// Failing to dispose keeps the camera locked and causes memory leaks.
///
/// **BAD:**
/// ```dart
/// class _CameraPageState extends State<CameraPage> {
///   late CameraController _controller;
///
///   @override
///   void initState() {
///     super.initState();
///     _controller = CameraController(cameras[0], ResolutionPreset.high);
///     _controller.initialize();
///   }
///   // Missing dispose - camera stays locked!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _CameraPageState extends State<CameraPage> {
///   late CameraController _controller;
///
///   @override
///   void initState() {
///     super.initState();
///     _controller = CameraController(cameras[0], ResolutionPreset.high);
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
class RequireCameraDisposeRule extends SaropaLintRule {
  const RequireCameraDisposeRule() : super(code: _code);

  /// Undisposed CameraController locks the camera and leaks native memory.
  /// Each occurrence is a critical resource leak.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_camera_dispose',
    problemMessage:
        '[require_camera_dispose] Undisposed camera holds hardware exclusively, '
        'blocking other apps from accessing camera until app restart.',
    correctionMessage:
        'Add _controller.dispose() in the dispose() method before super.dispose().',
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

      // Find CameraController fields
      final List<String> controllerNames = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toSource();
          if (typeName != null && typeName.contains('CameraController')) {
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

  @override
  List<Fix> getFixes() => <Fix>[_AddCameraDisposeFix()];
}

class _AddCameraDisposeFix extends DartFix {
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

      final String fieldName = node.name.lexeme;

      // Find the containing class
      AstNode? current = node.parent;
      while (current != null && current is! ClassDeclaration) {
        current = current.parent;
      }
      if (current is! ClassDeclaration) return;

      final ClassDeclaration classNode = current;

      // Find existing dispose method
      MethodDeclaration? disposeMethod;
      for (final ClassMember member in classNode.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeMethod = member;
          break;
        }
      }

      if (disposeMethod != null) {
        // Insert dispose() call before super.dispose()
        final String bodySource = disposeMethod.body.toSource();
        final int superDisposeIndex = bodySource.indexOf('super.dispose()');

        if (superDisposeIndex != -1) {
          final int bodyOffset = disposeMethod.body.offset;
          final int insertOffset = bodyOffset + superDisposeIndex;

          final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
            message: 'Add $fieldName.dispose()',
            priority: 1,
          );

          changeBuilder.addDartFileEdit((builder) {
            builder.addSimpleInsertion(
              insertOffset,
              '$fieldName.dispose();\n    ',
            );
          });
        }
      } else {
        // Create new dispose method
        int insertOffset = classNode.rightBracket.offset;

        for (final ClassMember member in classNode.members) {
          if (member is FieldDeclaration || member is ConstructorDeclaration) {
            insertOffset = member.end;
          }
        }

        final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
          message: 'Add dispose() method with $fieldName.dispose()',
          priority: 1,
        );

        changeBuilder.addDartFileEdit((builder) {
          builder.addSimpleInsertion(
            insertOffset,
            '\n\n  @override\n  void dispose() {\n    $fieldName.dispose();\n    super.dispose();\n  }',
          );
        });
      }
    });
  }
}

/// Warns when images from camera are uploaded without compression.
///
/// Phone cameras produce large images (5-20MB). Uploading uncompressed
/// images wastes bandwidth and storage. Compress before upload.
///
/// **BAD:**
/// ```dart
/// final image = await picker.pickImage(source: ImageSource.camera);
/// await uploadFile(File(image!.path)); // Full resolution upload!
/// ```
///
/// **GOOD:**
/// ```dart
/// final image = await picker.pickImage(
///   source: ImageSource.camera,
///   maxWidth: 1920,
///   maxHeight: 1080,
///   imageQuality: 85,
/// );
/// await uploadFile(File(image!.path));
/// ```
class RequireImageCompressionRule extends SaropaLintRule {
  const RequireImageCompressionRule() : super(code: _code);

  /// Uncompressed camera images waste bandwidth and storage.
  /// Performance issue, not a bug.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_image_compression',
    problemMessage:
        '[require_image_compression] Camera image captured without compression. Large files waste bandwidth. Phone cameras produce large images (5-20MB). Uploading uncompressed images wastes bandwidth and storage. Compress before upload.',
    correctionMessage:
        'Add maxWidth, maxHeight, or imageQuality parameters to limit file size. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName != 'pickImage' && methodName != 'getImage') return;

      // Check for camera source
      bool isFromCamera = false;
      bool hasCompression = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          final String value = arg.expression.toSource();

          if (name == 'source' && value.contains('camera')) {
            isFromCamera = true;
          }
          if (name == 'maxWidth' ||
              name == 'maxHeight' ||
              name == 'imageQuality') {
            hasCompression = true;
          }
        }
      }

      if (isFromCamera && !hasCompression) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddImageCompressionFix()];
}

class _AddImageCompressionFix extends DartFix {
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

      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add compression parameters',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          args.arguments.last.end,
          ',\n      maxWidth: 1920,\n      maxHeight: 1080,\n      imageQuality: 85',
        );
      });
    });
  }
}

/// Warns when precise location is requested when coarse would suffice.
///
/// Precise GPS location uses more battery and feels more invasive
/// to users. For city-level features (weather, local stores), use
/// coarse location instead.
///
/// **BAD:**
/// ```dart
/// // For a weather app - city-level is sufficient
/// final position = await Geolocator.getCurrentPosition(
///   desiredAccuracy: LocationAccuracy.high, // Unnecessary precision
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// // Weather only needs city
/// final position = await Geolocator.getCurrentPosition(
///   desiredAccuracy: LocationAccuracy.low,
/// );
/// // Or for navigation that needs precision:
/// final position = await Geolocator.getCurrentPosition(
///   desiredAccuracy: LocationAccuracy.high, // Justified for turn-by-turn
/// );
/// ```
class PreferCoarseLocationRule extends SaropaLintRule {
  const PreferCoarseLocationRule() : super(code: _code);

  /// High-precision GPS uses more battery than necessary.
  /// Optimization suggestion, not a bug.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_coarse_location_when_sufficient',
    problemMessage:
        '[prefer_coarse_location_when_sufficient] High accuracy location uses more battery. Prefer coarse location. Precise GPS location uses more battery and feels more invasive to users. For city-level features (weather, local stores), use coarse location instead.',
    correctionMessage:
        'Use LocationAccuracy.low or .medium if you only need city-level location. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName != 'getCurrentPosition' && methodName != 'getPosition') {
        return;
      }

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;

          if (name == 'desiredAccuracy' || name == 'accuracy') {
            final String value = arg.expression.toSource();

            // Flag high-precision modes that might be unnecessary
            if (value.contains('.high') ||
                value.contains('.best') ||
                value.contains('.bestForNavigation')) {
              reporter.atNode(arg, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when ImagePicker is used without specifying source.
///
/// ImagePicker without specifying source shows confusing blank picker
/// on some devices. Always specify ImageSource.camera or ImageSource.gallery.
///
/// **BAD:**
/// ```dart
/// final image = await ImagePicker().pickImage(); // Missing source!
/// ```
///
/// **GOOD:**
/// ```dart
/// final image = await ImagePicker().pickImage(source: ImageSource.camera);
/// // Or for gallery:
/// final image = await ImagePicker().pickImage(source: ImageSource.gallery);
/// ```
class AvoidImagePickerWithoutSourceRule extends SaropaLintRule {
  const AvoidImagePickerWithoutSourceRule() : super(code: _code);

  /// Missing source shows blank picker on some devices.
  /// UX bug that affects user experience.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_image_picker_without_source',
    problemMessage:
        '[avoid_image_picker_without_source] ImagePicker called without specifying an ImageSource shows a blank or empty picker dialog on some Android devices and older iOS versions. Users see a non-functional dialog and cannot select or capture images, resulting in a broken feature that provides no error feedback or alternative selection path.',
    correctionMessage:
        'Explicitly specify source: ImageSource.camera or ImageSource.gallery, or present a chooser dialog that lets the user pick their preferred image source.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName != 'pickImage' &&
          methodName != 'pickVideo' &&
          methodName != 'pickMultiImage') {
        return;
      }

      // Check if source is specified
      bool hasSource = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'source') {
          hasSource = true;
          break;
        }
      }

      if (!hasSource) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddImageSourceFix()];
}

class _AddImageSourceFix extends DartFix {
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

      final String methodName = node.methodName.name;
      if (methodName != 'pickImage' &&
          methodName != 'pickVideo' &&
          methodName != 'pickMultiImage') {
        return;
      }

      final ArgumentList args = node.argumentList;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add source: ImageSource.gallery',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        if (args.arguments.isEmpty) {
          builder.addSimpleInsertion(
            args.leftParenthesis.end,
            'source: ImageSource.gallery',
          );
        } else {
          builder.addSimpleInsertion(
            args.leftParenthesis.end,
            'source: ImageSource.gallery, ',
          );
        }
      });
    });
  }
}

// =============================================================================
// prefer_geolocator_accuracy_appropriate
// =============================================================================

/// Use appropriate location accuracy level - high accuracy drains battery.
///
/// LocationAccuracy.high uses GPS and significantly drains battery.
/// For features that don't need precise location, use lower accuracy.
///
/// **BAD:**
/// ```dart
/// await Geolocator.getCurrentPosition(
///   desiredAccuracy: LocationAccuracy.high,  // Overkill for city-level!
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// await Geolocator.getCurrentPosition(
///   desiredAccuracy: LocationAccuracy.low,  // City-level is fine
/// );
/// ```
class PreferGeolocatorAccuracyAppropriateRule extends SaropaLintRule {
  const PreferGeolocatorAccuracyAppropriateRule() : super(code: _code);

  /// Battery drain from excessive GPS usage.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_geolocator_accuracy_appropriate',
    problemMessage:
        '[prefer_geolocator_accuracy_appropriate] LocationAccuracy.high uses GPS and drains battery significantly. LocationAccuracy.high uses GPS and significantly drains battery. For features that don\'t need precise location, use lower accuracy.',
    correctionMessage:
        'Prefer LocationAccuracy.low or .medium if precise location not needed. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'getCurrentPosition' &&
          methodName != 'getPositionStream') {
        return;
      }

      // Check if target is Geolocator
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Geolocator') return;

      // Check for high accuracy
      final ArgumentList args = node.argumentList;
      for (final Expression arg in args.arguments) {
        if (arg is NamedExpression &&
            arg.name.label.name == 'desiredAccuracy') {
          final String valueSource = arg.expression.toSource();
          if (valueSource.contains('.high') ||
              valueSource.contains('.best') ||
              valueSource.contains('.bestForNavigation')) {
            reporter.atNode(arg, code);
            return;
          }
        }
      }
    });
  }
}

// =============================================================================
// prefer_geolocator_last_known
// =============================================================================

/// Use lastKnownPosition for non-critical needs to save battery.
///
/// getLastKnownPosition returns cached location without GPS poll.
/// Use it when fresh location isn't critical.
///
/// **Consider using:**
/// ```dart
/// final position = await Geolocator.getLastKnownPosition();
/// if (position != null) {
///   // Use cached position
/// }
/// ```
class PreferGeolocatorLastKnownRule extends SaropaLintRule {
  const PreferGeolocatorLastKnownRule() : super(code: _code);

  /// Battery optimization opportunity.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_geolocator_last_known',
    problemMessage:
        '[prefer_geolocator_last_known] getCurrentPosition polls GPS. Prefer getLastKnownPosition for cached location. getLastKnownPosition returns cached location without GPS poll. Use it when fresh location isn\'t critical.',
    correctionMessage:
        'Use Geolocator.getLastKnownPosition() when fresh location not critical. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'getCurrentPosition') return;

      // Check if target is Geolocator
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Geolocator') return;

      // Check if it's in a context that suggests non-critical use
      // (e.g., initialization, splash screens, or low-accuracy requests)
      final ArgumentList args = node.argumentList;
      bool hasLowAccuracy = false;

      for (final Expression arg in args.arguments) {
        if (arg is NamedExpression &&
            arg.name.label.name == 'desiredAccuracy') {
          final String valueSource = arg.expression.toSource();
          if (valueSource.contains('.low') ||
              valueSource.contains('.lowest') ||
              valueSource.contains('.reduced')) {
            hasLowAccuracy = true;
            break;
          }
        }
      }

      // Only suggest for low-accuracy requests where cached might suffice
      if (hasLowAccuracy) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// prefer_image_picker_multi_selection
// =============================================================================

/// Use pickMultiImage instead of loop calling pickImage.
///
/// Calling pickImage in a loop is inefficient. Use pickMultiImage for
/// batch image selection.
///
/// **BAD:**
/// ```dart
/// for (int i = 0; i < count; i++) {
///   final image = await ImagePicker().pickImage(source: ImageSource.gallery);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// final images = await ImagePicker().pickMultiImage();
/// ```
class PreferImagePickerMultiSelectionRule extends SaropaLintRule {
  const PreferImagePickerMultiSelectionRule() : super(code: _code);

  /// Poor UX from repeated picker dialogs.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_image_picker_multi_selection',
    problemMessage:
        '[prefer_image_picker_multi_selection] pickImage in loop. Use pickMultiImage for batch selection. Use pickMultiImage instead of loop calling pickImage. This can cause resource exhaustion, performance degradation, or application instability.',
    correctionMessage:
        'Replace with ImagePicker().pickMultiImage(). Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'pickImage') return;

      // Check if inside a loop
      final ForStatement? forLoop = node.thisOrAncestorOfType<ForStatement>();
      final WhileStatement? whileLoop =
          node.thisOrAncestorOfType<WhileStatement>();
      final DoStatement? doLoop = node.thisOrAncestorOfType<DoStatement>();
      final ForElement? forElement = node.thisOrAncestorOfType<ForElement>();

      if (forLoop != null ||
          whileLoop != null ||
          doLoop != null ||
          forElement != null) {
        reporter.atNode(node, code);
      }
    });
  }
}
