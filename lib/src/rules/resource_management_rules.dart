// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Resource management lint rules for Flutter/Dart applications.
///
/// These rules help ensure proper handling of system resources like
/// files, sockets, databases, and native resources to prevent leaks.
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../saropa_lint_rule.dart';

/// Warns when file handle is not closed in finally block.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  RequireFileCloseInFinallyRule() : super(code: _code);

  /// Unclosed file handles leak system resources.
  /// Each occurrence is a resource leak.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_file_close_in_finally',
    '[require_file_close_in_finally] Unclosed file handle on exception '
        'leaks file descriptor, exhausting system limits. {v4}',
    correctionMessage:
        'Use try-finally or convenience methods like readAsString().',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
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
        reporter.atNode(node);
      } else if (!hasClose &&
          !bodySource.contains('readAsString') &&
          !bodySource.contains('readAsBytes') &&
          !bodySource.contains('writeAsString') &&
          !bodySource.contains('writeAsBytes')) {
        // No close at all
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when database connection is not properly closed.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
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
  RequireDatabaseCloseRule() : super(code: _code);

  /// Unclosed database connections exhaust connection pools.
  /// Each occurrence is a resource leak.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_database_close',
    '[require_database_close] Unclosed database connection leaks resources '
        'and may exhaust connection pool, causing app failures. {v6}',
    correctionMessage:
        'Close database in finally block or use connection pool.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Patterns that indicate actual database instantiation.
  /// Uses word boundary patterns to avoid false positives like 'initIsarDatabase('.
  static final RegExp _dbOpenPattern = RegExp(
    r'(?:^|[^a-zA-Z])(?:openDatabase|Database\(|SqliteDatabase)',
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
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
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when HttpClient is not closed.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
  RequireHttpClientCloseRule() : super(code: _code);

  /// Unclosed HttpClient holds connection pools and leaks sockets.
  /// Each occurrence is a resource leak.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_http_client_close',
    '[require_http_client_close] Unclosed HttpClient leaks socket '
        'connections and memory, eventually exhausting system resources. {v5}',
    correctionMessage: 'Call client.close() in finally block.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Check for HttpClient creation
      if (!bodySource.contains('HttpClient()')) return;

      // Check for close (including *Safe extension variants)
      if (!bodySource.contains('.close(') &&
          !bodySource.contains('.closeSafe(') &&
          !bodySource.contains('.close;')) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when native resources are allocated without cleanup.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v3
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
  RequireNativeResourceCleanupRule() : super(code: _code);

  /// Unfreed native memory leaks outside Dart's garbage collector.
  /// Each occurrence is a memory leak.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_native_resource_cleanup',
    '[require_native_resource_cleanup] Unfreed native memory leaks '
        'outside Dart GC, causing permanent memory loss until app restart. {v3}',
    correctionMessage: 'Call free() in finally block for native allocations.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _allocMethods = <String>{
    'calloc<',
    'malloc<',
    'allocate(',
    'Pointer.fromAddress',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
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
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when WebSocket is not closed on dispose.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
  RequireWebSocketCloseRule() : super(code: _code);

  /// Unclosed WebSocket connections leak sockets and may cause errors.
  /// Each occurrence is a resource leak.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_websocket_close',
    '[require_websocket_close] Unclosed WebSocket leaks connections and '
        'continues receiving data after widget disposal, causing errors. {v5}',
    correctionMessage: 'Add _socket.close() in dispose method.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
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
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when Platform Channel is used without cleanup.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
  RequirePlatformChannelCleanupRule() : super(code: _code);

  /// Platform channel handlers prevent garbage collection of State.
  /// Each occurrence is a memory leak.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_platform_channel_cleanup',
    '[require_platform_channel_cleanup] Active platform channel handler '
        'receives callbacks after dispose, causing setState on unmounted widget. {v5}',
    correctionMessage: 'Set handler to null in dispose method.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
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
          // Check if handler is nullified or subscription canceled
          // (including *Safe extension variants)
          if (disposeSource.contains('setMethodCallHandler(null)') ||
              disposeSource.contains('.cancel(') ||
              disposeSource.contains('.cancelSafe(')) {
            return; // Good - cleanup found
          }
        }
      }

      if (!hasDispose || classSource.contains('setMethodCallHandler')) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when Isolate is spawned without being killed.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v3
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
  RequireIsolateKillRule() : super(code: _code);

  /// Orphaned isolates consume memory and CPU resources.
  /// Each occurrence is a resource leak.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_isolate_kill',
    '[require_isolate_kill] Unkilled Isolate continues consuming CPU and '
        'memory, and may send messages to disposed handlers causing crashes. {v3}',
    correctionMessage: 'Call isolate.kill() in cleanup/dispose method.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      final String classSource = node.toSource();

      // Check for Isolate.spawn
      if (!classSource.contains('Isolate.spawn') &&
          !classSource.contains('Isolate.spawnUri')) {
        return;
      }

      // Check for kill
      if (!classSource.contains('.kill(')) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when CameraController is not disposed.
///
/// Since: v1.6.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireCameraDisposeRule() : super(code: _code);

  /// Undisposed CameraController locks the camera and leaks native memory.
  /// Each occurrence is a critical resource leak.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_camera_dispose',
    '[require_camera_dispose] Undisposed camera holds hardware exclusively, '
        'blocking other apps from accessing camera until app restart. {v2}',
    correctionMessage:
        'Add _controller.dispose() in the dispose() method before super.dispose().',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
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
        final bool isDisposed =
            disposeBody != null &&
            (disposeBody.contains('$name.dispose(') ||
                disposeBody.contains('$name?.dispose('));

        if (!isDisposed) {
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

/// Warns when images from camera are uploaded without compression.
///
/// Since: v1.6.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireImageCompressionRule() : super(code: _code);

  /// Uncompressed camera images waste bandwidth and storage.
  /// Performance issue, not a bug.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_image_compression',
    '[require_image_compression] Camera image captured without compression. Large files waste bandwidth. Phone cameras produce large images (5-20MB). Uploading uncompressed images wastes bandwidth and storage. Compress before upload. {v2}',
    correctionMessage:
        'Add maxWidth, maxHeight, or imageQuality parameters to limit file size. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when precise location is requested when coarse would suffice.
///
/// Since: v1.6.0 | Updated: v4.13.0 | Rule version: v2
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
  PreferCoarseLocationRule() : super(code: _code);

  /// High-precision GPS uses more battery than necessary.
  /// Optimization suggestion, not a bug.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_coarse_location_when_sufficient',
    '[prefer_coarse_location_when_sufficient] High accuracy location uses more battery. Prefer coarse location. Precise GPS location uses more battery and feels more invasive to users. For city-level features (weather, local stores), use coarse location instead. {v2}',
    correctionMessage:
        'Use LocationAccuracy.low or .medium if you only need city-level location. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
              reporter.atNode(arg);
            }
          }
        }
      }
    });
  }
}

/// Warns when ImagePicker is used without specifying source.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
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
  AvoidImagePickerWithoutSourceRule() : super(code: _code);

  /// Missing source shows blank picker on some devices.
  /// UX bug that affects user experience.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_image_picker_without_source',
    '[avoid_image_picker_without_source] ImagePicker called without specifying an ImageSource shows a blank or empty picker dialog on some Android devices and older iOS versions. Users see a non-functional dialog and cannot select or capture images, resulting in a broken feature that provides no error feedback or alternative selection path. {v2}',
    correctionMessage:
        'Explicitly specify source: ImageSource.camera or ImageSource.gallery, or present a chooser dialog that lets the user pick their preferred image source.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// prefer_geolocator_accuracy_appropriate
// =============================================================================

/// Use appropriate location accuracy level - high accuracy drains battery.
///
/// Since: v2.6.0 | Updated: v4.13.0 | Rule version: v2
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
  PreferGeolocatorAccuracyAppropriateRule() : super(code: _code);

  /// Battery drain from excessive GPS usage.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_geolocator_accuracy_appropriate',
    '[prefer_geolocator_accuracy_appropriate] LocationAccuracy.high uses GPS and drains battery significantly. LocationAccuracy.high uses GPS and significantly drains battery. For features that don\'t need precise location, use lower accuracy. {v2}',
    correctionMessage:
        'Prefer LocationAccuracy.low or .medium if precise location not needed. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
            reporter.atNode(arg);
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
/// Since: v2.6.0 | Updated: v4.13.0 | Rule version: v2
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
  PreferGeolocatorLastKnownRule() : super(code: _code);

  /// Battery optimization opportunity.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_geolocator_last_known',
    '[prefer_geolocator_last_known] getCurrentPosition polls GPS. Prefer getLastKnownPosition for cached location. getLastKnownPosition returns cached location without GPS poll. Use it when fresh location isn\'t critical. {v2}',
    correctionMessage:
        'Use Geolocator.getLastKnownPosition() when fresh location not critical. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// prefer_image_picker_multi_selection
// =============================================================================

/// Use pickMultiImage instead of loop calling pickImage.
///
/// Since: v2.6.0 | Updated: v4.13.0 | Rule version: v2
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
  PreferImagePickerMultiSelectionRule() : super(code: _code);

  /// Poor UX from repeated picker dialogs.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_image_picker_multi_selection',
    '[prefer_image_picker_multi_selection] pickImage in loop. Use pickMultiImage for batch selection. Use pickMultiImage instead of loop calling pickImage. This can cause resource exhaustion, performance degradation, or application instability. {v2}',
    correctionMessage:
        'Replace with ImagePicker().pickMultiImage(). Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'pickImage') return;

      // Check if inside a loop
      final ForStatement? forLoop = node.thisOrAncestorOfType<ForStatement>();
      final WhileStatement? whileLoop = node
          .thisOrAncestorOfType<WhileStatement>();
      final DoStatement? doLoop = node.thisOrAncestorOfType<DoStatement>();
      final ForElement? forElement = node.thisOrAncestorOfType<ForElement>();

      if (forLoop != null ||
          whileLoop != null ||
          doLoop != null ||
          forElement != null) {
        reporter.atNode(node);
      }
    });
  }
}
