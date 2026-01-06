// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Resource management lint rules for Flutter/Dart applications.
///
/// These rules help ensure proper handling of system resources like
/// files, sockets, databases, and native resources to prevent leaks.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

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
class RequireFileCloseInFinallyRule extends DartLintRule {
  const RequireFileCloseInFinallyRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_file_close_in_finally',
    problemMessage: 'File handle should be closed in finally block.',
    correctionMessage:
        'Use try-finally or convenience methods like readAsString().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _fileOpenMethods = <String>{
    'openRead',
    'openWrite',
    'openSync',
    'open',
  };

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Check for file open calls
      bool hasFileOpen = false;
      for (final String method in _fileOpenMethods) {
        if (bodySource.contains('.$method(')) {
          hasFileOpen = true;
          break;
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
class RequireDatabaseCloseRule extends DartLintRule {
  const RequireDatabaseCloseRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_database_close',
    problemMessage: 'Database connection should be closed.',
    correctionMessage:
        'Close database in finally block or use connection pool.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      // Check for database open calls
      if (!bodySource.contains('openDatabase') &&
          !bodySource.contains('Database(') &&
          !bodySource.contains('SqliteDatabase')) {
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
class RequireHttpClientCloseRule extends DartLintRule {
  const RequireHttpClientCloseRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_http_client_close',
    problemMessage: 'HttpClient should be closed when done.',
    correctionMessage: 'Call client.close() in finally block.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class RequireNativeResourceCleanupRule extends DartLintRule {
  const RequireNativeResourceCleanupRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_native_resource_cleanup',
    problemMessage: 'Native resource should be freed.',
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
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class RequireWebSocketCloseRule extends DartLintRule {
  const RequireWebSocketCloseRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_websocket_close',
    problemMessage: 'WebSocket should be closed in dispose.',
    correctionMessage: 'Add _socket.close() in dispose method.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class RequirePlatformChannelCleanupRule extends DartLintRule {
  const RequirePlatformChannelCleanupRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_platform_channel_cleanup',
    problemMessage: 'Platform channel handler should be removed in dispose.',
    correctionMessage: 'Set handler to null in dispose method.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class RequireIsolateKillRule extends DartLintRule {
  const RequireIsolateKillRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'require_isolate_kill',
    problemMessage: 'Spawned Isolate should be killed when done.',
    correctionMessage: 'Call isolate.kill() in cleanup/dispose method.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
