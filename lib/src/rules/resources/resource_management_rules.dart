// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Resource management lint rules for Flutter/Dart applications.
///
/// These rules help ensure proper handling of system resources like
/// files, sockets, databases, and native resources to prevent leaks.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../saropa_lint_rule.dart';
import '../../target_matcher_utils.dart';

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
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'resources'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_file_close_in_finally',
    '[require_file_close_in_finally] Unclosed file handle on exception '
        'leaks file descriptor, exhausting system limits. {v4}',
    correctionMessage:
        'Use try-finally or convenience methods like readAsString().',
    // SEV-01 (kept WARNING): a close performed in a sibling/helper method is
    // invisible to this single-body scan (extract-method pattern), so an ERROR
    // would break correct code — not ERROR-safe without cross-method analysis.
    severity: DiagnosticSeverity.WARNING,
  );

  static final RegExp _fileOpenMethodPattern = RegExp(
    r'\.(?:openRead|openWrite|openSync)\s*\(',
  );
  static final RegExp _genericOpenPattern = RegExp(r'\.open\s*\(');
  // `\b` before `File(` so the indicator does not match `XFile(`, `ProfileX(`,
  // `_MyFile(` etc. — unanchored `File\s*\(` previously fired on any identifier
  // ending in "File", a systematic false positive for the `image_picker`
  // `XFile` type and any domain type whose name ends in "File".
  static final List<RegExp> _fileIndicatorPatterns = <RegExp>[
    RegExp(r'\bFile\s*\('),
    RegExp(r'\bIOSink\b'),
    RegExp(r'\bRandomAccessFile\b'),
    RegExp(r'dart:io'),
  ];
  // A handle assigned to an instance field (`_sink = file.openWrite()`) has its
  // lifetime owned by the enclosing class and is conventionally closed in a
  // sibling `dispose()`/`close()`. A method-body-scoped scan cannot see that
  // sibling, so flagging here is a guaranteed false positive for the
  // store-then-dispose-elsewhere pattern. Detect the field-assignment shape.
  static final RegExp _fieldAssignedOpenPattern = RegExp(
    r'_\w+\s*=\s*\w+\.(?:openRead|openWrite|openSync|open)\s*\(',
  );
  static final RegExp _closeCallPattern = RegExp(r'\.close\s*\(');
  static final RegExp _readWriteConveniencePattern = RegExp(
    r'\b(?:readAsString|readAsBytes|writeAsString|writeAsBytes)\s*\(',
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      bool hasFileOpen =
          _fileOpenMethodPattern.hasMatch(bodySource) ||
          (_genericOpenPattern.hasMatch(bodySource) &&
              _fileIndicatorPatterns.any((re) => re.hasMatch(bodySource)));

      if (!hasFileOpen) return;

      // Ownership transferred to a field — closed in a sibling method this
      // body-scoped scan cannot inspect. Skip to avoid a build-breaking FP.
      if (_fieldAssignedOpenPattern.hasMatch(bodySource)) return;

      final bool hasClose = _closeCallPattern.hasMatch(bodySource);

      // Only flag the unambiguous leak shape: a handle is opened and the body
      // contains NO `.close(` anywhere AND no convenience reader. The former
      // `!hasFinally && hasClose` branch fired whenever a sink was closed
      // outside a `finally` (e.g. `.whenComplete(() => sink.close())`,
      // `await using(...)`, or a trailing close on the happy path) — all
      // legitimately-cleaned shapes the rule misread as leaks. Dropping that
      // branch trades a narrow extra catch for the elimination of a large FP
      // class, which is the correct trade for an error-severity build gate.
      if (!hasClose && !_readWriteConveniencePattern.hasMatch(bodySource)) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when database connection is not properly closed.
///
/// Since: v0.1.4 | Updated: v12.5.4 | Rule version: v7
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
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'resources'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_database_close',
    '[require_database_close] Unclosed database connection leaks resources '
        'and may exhaust connection pool, causing app failures. {v7}',
    correctionMessage:
        'Close database in finally block or use connection pool.',
    // SEV-01 (kept WARNING): still lints a Future<Database> factory whose
    // callers close the connection; cross-method/ownership tracking is needed
    // before this could break builds at ERROR.
    severity: DiagnosticSeverity.WARNING,
  );

  static final List<RegExp> _closeOrDisposePattern = <RegExp>[
    RegExp(r'\.close\s*\('),
    RegExp(r'\.closeSafe\s*\('),
    RegExp(r'\bdispose\s*\('),
    RegExp(r'\bdisposeSafe\s*\('),
  ];
  // Connection assigned to an instance field (`_db = await openDatabase(...)`)
  // is owned by the class and closed in a sibling dispose/close that a
  // body-scoped scan cannot inspect. This complements the name-based
  // open-helper heuristic below: it catches field-storing methods whose names
  // do NOT start with init/open/setup (e.g. `_loadData`, `connect`).
  static final RegExp _fieldAssignedDatabasePattern = RegExp(
    r'_\w+\s*=\s*(?:await\s+)?openDatabase\s*\(',
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Skip when analyzing this package's own rule files (avoids self-trigger on
    // openDatabase in string literals/regex). Path format can differ by SDK/OS.
    final String path = context.filePath.replaceAll(r'\', '/').toLowerCase();
    final bool isOwnRuleFile =
        path.contains('src/rules/') ||
        path.contains('resource_management_rules.dart') ||
        path.contains('file_handling_rules.dart') ||
        path.contains('sqflite_rules.dart');

    context.addMethodDeclaration((MethodDeclaration node) {
      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      if (isOwnRuleFile) return;

      if (!_hasDatabaseOpenInvocation(body)) {
        return;
      }

      // Skip when body only references the name (e.g. methodName != 'openDatabase').
      if (bodySource.indexOf("'openDatabase'") >= 0 &&
          bodySource.indexOf('methodName') >= 0) {
        return;
      }

      // Ownership transferred to a field — closed in a sibling dispose this
      // body-scoped scan cannot see. Skip to avoid a build-breaking FP.
      if (_fieldAssignedDatabasePattern.hasMatch(bodySource)) return;

      // Open-in-helper / close-in-caller pattern: `init*`/`open*`/`setup*`
      // helpers that return Future<bool>/Future<void> (or bool/void) signal
      // success/failure to a caller that owns the lifetime via try/finally.
      // Without cross-method flow analysis the rule cannot prove the caller
      // closes, so this name+return-type heuristic prevents systematic FPs on
      // background-isolate / WorkManager / migration setup helpers. Methods
      // that actually hand back a connection (`Future<Database>` etc.) keep
      // tripping the rule because their return type signals the caller now
      // owns a connection — which is the leak shape we still want to catch.
      if (_looksLikeOpenHelperManagedByCaller(node)) return;

      // Check for close (including *Safe extension variants)
      if (!_closeOrDisposePattern.any((re) => re.hasMatch(bodySource))) {
        reporter.atNode(node);
      }
    });
  }

  bool _hasDatabaseOpenInvocation(FunctionBody body) {
    final _DatabaseOpenInvocationVisitor visitor =
        _DatabaseOpenInvocationVisitor();
    body.accept(visitor);
    return visitor.found;
  }

  /// Whether [node] looks like an opener helper whose caller closes.
  ///
  /// Two signals must both hold:
  /// 1. Name starts with `init` / `_init` / `open` / `_open` / `setup` /
  ///    `_setup` — Saropa's convention for setup helpers across Drift / Isar
  ///    / WorkManager backgrounds.
  /// 2. Declared return type is `Future<bool>` / `Future<void>` / `bool` /
  ///    `void` — a success-flag return, not a hand-off of the connection.
  ///    Methods returning `Future<Database>` etc. still get linted because
  ///    those genuinely transfer ownership and most callers don't close.
  static bool _looksLikeOpenHelperManagedByCaller(MethodDeclaration node) {
    final String name = node.name.lexeme;
    final bool nameMatches =
        name.startsWith('init') ||
        name.startsWith('_init') ||
        name.startsWith('open') ||
        name.startsWith('_open') ||
        name.startsWith('setup') ||
        name.startsWith('_setup');
    if (!nameMatches) return false;

    final TypeAnnotation? returnType = node.returnType;
    if (returnType == null) return false;

    final String returnSource = returnType.toSource();
    return returnSource == 'Future<bool>' ||
        returnSource == 'Future<void>' ||
        returnSource == 'bool' ||
        returnSource == 'void';
  }
}

class _DatabaseOpenInvocationVisitor extends RecursiveAstVisitor<void> {
  bool found = false;

  static const Set<String> _databaseConstructorTypes = <String>{
    'Database',
    'SqliteDatabase',
  };

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!found && node.methodName.name == 'openDatabase') {
      found = true;
      return;
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (found) return;
    final NamedType typeNode = node.constructorName.type;
    if (_databaseConstructorTypes.contains(typeNode.name.lexeme)) {
      found = true;
      return;
    }
    super.visitInstanceCreationExpression(node);
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
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'resources'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_http_client_close',
    '[require_http_client_close] Unclosed HttpClient leaks socket '
        'connections and memory, eventually exhausting system resources. {v5}',
    correctionMessage: 'Call client.close() in finally block.',
    // SEV-01 (kept WARNING): a client passed to a helper or wrapped by DI that
    // owns close() is invisible to the single-body scan — not ERROR-safe.
    severity: DiagnosticSeverity.WARNING,
  );

  // `\b` so `MyHttpClient()` / `FakeHttpClient()` test doubles do not match the
  // raw-socket `dart:io` `HttpClient` constructor this rule targets.
  static final RegExp _httpClientCtorPattern = RegExp(
    r'\bHttpClient\s*\(\s*\)',
  );
  static final List<RegExp> _httpClosePatterns = <RegExp>[
    RegExp(r'\.close\s*\('),
    RegExp(r'\.closeSafe\s*\('),
    RegExp(r'\.close\s*;'),
  ];
  // Client assigned to an instance field (`_client = HttpClient()`) is owned by
  // the class and conventionally closed in a sibling `dispose()`/`close()` that
  // a body-scoped scan cannot see — flagging here is a guaranteed FP.
  static final RegExp _fieldAssignedClientPattern = RegExp(
    r'_\w+\s*=\s*HttpClient\s*\(\s*\)',
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      if (!_httpClientCtorPattern.hasMatch(bodySource)) return;

      // Ownership transferred to a field — closed elsewhere. Skip.
      if (_fieldAssignedClientPattern.hasMatch(bodySource)) return;

      // Method hands the client back to the caller (`return HttpClient()` or a
      // factory whose declared return type is HttpClient). The caller now owns
      // the lifetime, so absence of a local close is not a leak.
      if (_returnsHttpClient(node, bodySource)) return;

      if (!_httpClosePatterns.any((re) => re.hasMatch(bodySource))) {
        reporter.atNode(node);
      }
    });
  }

  /// Whether [node] transfers HttpClient ownership to its caller.
  ///
  /// Two ownership-transfer shapes are recognized:
  /// 1. Declared return type is `HttpClient` / `Future<HttpClient>` — a factory.
  /// 2. The body directly returns the constructed client (`return HttpClient()`).
  /// Either way the caller owns the close, so a missing local close is correct.
  static bool _returnsHttpClient(MethodDeclaration node, String bodySource) {
    final TypeAnnotation? returnType = node.returnType;
    if (returnType != null) {
      final String returnSource = returnType.toSource();
      if (returnSource == 'HttpClient' ||
          returnSource == 'Future<HttpClient>') {
        return true;
      }
    }
    return RegExp(r'return\s+HttpClient\s*\(\s*\)').hasMatch(bodySource);
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
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'resources'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_native_resource_cleanup',
    '[require_native_resource_cleanup] Unfreed native memory leaks '
        'outside Dart GC, causing permanent memory loss until app restart. {v3}',
    correctionMessage: 'Call free() in finally block for native allocations.',
    // SEV-01 (kept WARNING): the arena/borrowed-pointer FPs are fixed, but a
    // malloc whose free() lives in a helper still mis-fires — not ERROR-safe
    // without cross-method analysis.
    severity: DiagnosticSeverity.WARNING,
  );

  // `Pointer.fromAddress` is intentionally NOT an allocation trigger: it
  // constructs a *borrowed* view over memory the caller already owns — freeing
  // it would be a double-free / use-after-free bug, the opposite of what this
  // rule should encourage. Including it produced wrong-direction false
  // positives demanding `free()` on pointers that must never be freed here.
  static final List<RegExp> _allocPatterns = <RegExp>[
    RegExp(r'calloc\s*<'),
    RegExp(r'malloc\s*<'),
    RegExp(r'\ballocate\s*\('),
  ];
  static final List<RegExp> _nativeCleanupPatterns = <RegExp>[
    RegExp(r'\.free\s*\('),
    RegExp(r'\bfree\s*\('),
    RegExp(r'\bfinally\b'),
    // `Arena` / `using` scope frees every allocation automatically on exit, so
    // its presence means cleanup is handled even without an explicit `free()`.
    RegExp(r'\bArena\b'),
    RegExp(r'\busing\s*\('),
  ];
  // Allocation assigned to an instance field is owned by the class and freed in
  // a sibling dispose — a body-scoped scan cannot see that, so skip.
  static final RegExp _fieldAssignedAllocPattern = RegExp(
    r'_\w+\s*=\s*\w*(?:calloc|malloc|allocate)\b',
  );
  static final RegExp _returnsPointerPattern = RegExp(
    r'return\s+\w*(?:calloc|malloc|allocate)\b',
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      final FunctionBody body = node.body;
      final String bodySource = body.toSource();

      final bool hasAlloc = _allocPatterns.any((re) => re.hasMatch(bodySource));

      if (!hasAlloc) return;

      // Ownership transferred to a field or returned to the caller — freed
      // elsewhere, not a local leak.
      if (_fieldAssignedAllocPattern.hasMatch(bodySource) ||
          _returnsPointerPattern.hasMatch(bodySource)) {
        return;
      }

      if (!_nativeCleanupPatterns.any((re) => re.hasMatch(bodySource))) {
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
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'resources'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_websocket_close',
    '[require_websocket_close] Unclosed WebSocket leaks connections and '
        'continues receiving data after widget disposal, causing errors. {v5}',
    correctionMessage: 'Add _socket.close() in dispose method.',
    // SEV-01 (kept WARNING): helper-delegated teardown is matched only by a
    // heuristic (any _x() in dispose) and untyped `late final` sockets are
    // under-detected — too imprecise for a build-breaking ERROR.
    severity: DiagnosticSeverity.WARNING,
  );

  // `WebSocket` / `WebSocketChannel` (with optional `?` nullability, generics,
  // or `late` already stripped by reading `.type`) as the field type.
  static final RegExp _webSocketTypePattern = RegExp(r'\bWebSocket\w*');
  // A receiver-less private call statement inside dispose, e.g. `_cleanup();`.
  static final RegExp _bareHelperCallPattern = RegExp(r'(?:^|\{|;)\s*_\w+\s*\(');

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

      for (final ClassMember member in node.bodyMembers) {
        if (member is FieldDeclaration) {
          // Match WebSocket as the field's declared TYPE, not anywhere in the
          // field source. Substring matching previously fired on unrelated
          // fields like `final String webSocketUrl = '...'` or
          // `final int webSocketRetryCount = 3`, which hold no socket to close.
          final String? typeName = member.fields.type?.toSource();
          if (typeName != null && _webSocketTypePattern.hasMatch(typeName)) {
            hasWebSocket = true;
          }
        }

        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          final String disposeSource = member.body.toSource();
          // Check for close (including *Safe extension variants). Also treat a
          // bare helper delegation (`_disposeSocket();` / `_cleanup();`) as
          // cleanup: a private method invocation with no receiver inside
          // dispose almost always forwards teardown, and a body-scoped scan
          // cannot follow into it — so assuming it closes avoids a
          // build-breaking FP on the common extract-method pattern.
          if (disposeSource.contains('.close(') ||
              disposeSource.contains('.closeSafe(') ||
              disposeSource.contains('.sink.close') ||
              _bareHelperCallPattern.hasMatch(disposeSource)) {
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
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'resources'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_platform_channel_cleanup',
    '[require_platform_channel_cleanup] Active platform channel handler '
        'receives callbacks after dispose, causing setState on unmounted widget. {v5}',
    correctionMessage: 'Set handler to null in dispose method.',
    // SEV-01 (kept WARNING): the re-flag logic bug is fixed, but cleanup
    // delegated to a helper is still matched only heuristically — not yet
    // deterministic enough for ERROR.
    severity: DiagnosticSeverity.WARNING,
  );

  // Whitespace-tolerant `setMethodCallHandler(null)` — the prior exact-string
  // check missed `setMethodCallHandler( null )` and `setMethodCallHandler(\n
  // null)`, false-positiving on correctly-cleaned code formatted with spaces.
  static final RegExp _handlerNullifyPattern = RegExp(
    r'setMethodCallHandler\s*\(\s*null\s*\)',
  );
  // A receiver-less private call statement inside dispose, e.g. `_teardown();`.
  // Cleanup is frequently extracted into a helper the body-scoped scan cannot
  // follow; assuming such a call forwards teardown avoids build-breaking FPs.
  static final RegExp _disposeHelperCallPattern = RegExp(
    r'(?:^|\{|;)\s*_\w+\s*\(',
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

      // Check for cleanup in dispose. Any recognized teardown shape early-
      // returns clean; falling through to the bottom means none was found.
      for (final ClassMember member in node.bodyMembers) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          final String disposeSource = member.body.toSource();
          // Recognized cleanup shapes (whitespace-tolerant), plus a bare
          // private helper call that forwards teardown. The former exact-string
          // `setMethodCallHandler(null)` missed `setMethodCallHandler( null )`
          // and `removeMethodCallHandler`, and the old trailing
          // `classSource.contains('setMethodCallHandler')` guard re-flagged
          // every class that DID clean up via a helper — both build-breaking
          // FPs that this consolidated check removes.
          if (_handlerNullifyPattern.hasMatch(disposeSource) ||
              disposeSource.contains('removeMethodCallHandler') ||
              disposeSource.contains('.cancel(') ||
              disposeSource.contains('.cancelSafe(') ||
              _disposeHelperCallPattern.hasMatch(disposeSource)) {
            return; // Good - cleanup found
          }
        }
      }

      // Every cleaned case already hit the early `return` inside the loop, so
      // reaching here means setup is present and no recognized teardown exists
      // (the class either lacks a dispose or has one that never tears the
      // handler down). Both are genuine leaks.
      reporter.atNode(node);
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
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'resources'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_isolate_kill',
    '[require_isolate_kill] Unkilled Isolate continues consuming CPU and '
        'memory, and may send messages to disposed handlers causing crashes. {v3}',
    correctionMessage: 'Call isolate.kill() in cleanup/dispose method.',
    // SEV-01 (kept WARNING): kill-via-helper and intentional app-lifetime
    // workers (Isolate.exit) still mis-fire — not ERROR-safe without flow
    // analysis.
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Detect `Isolate.spawn` / `Isolate.spawnUri` as a real invocation via the
      // AST rather than a substring of the class source. The substring form
      // self-triggered on string literals like `'Isolate.spawn'` (this lints
      // package, codegen, and docs-emitting tooling all contain such strings),
      // a guaranteed false positive for an error-severity gate.
      final _IsolateSpawnVisitor spawnVisitor = _IsolateSpawnVisitor();
      node.accept(spawnVisitor);
      if (!spawnVisitor.found) return;

      final String classSource = node.toSource();

      // Recognized teardown: an explicit `.kill(` on the isolate, OR
      // `Isolate.exit(` (the spawned isolate self-terminates and the parent is
      // not expected to call kill — a legitimate cleanup the old check missed).
      if (classSource.contains('.kill(') ||
          classSource.contains('Isolate.exit')) {
        return;
      }

      reporter.atNode(node);
    });
  }
}

/// Finds a genuine `Isolate.spawn` / `Isolate.spawnUri` method invocation.
///
/// Used instead of substring matching so string literals and comments that
/// merely mention the API do not trip the require_isolate_kill rule.
class _IsolateSpawnVisitor extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!found) {
      final Expression? target = node.target;
      final String name = node.methodName.name;
      if (target is SimpleIdentifier &&
          target.name == 'Isolate' &&
          (name == 'spawn' || name == 'spawnUri')) {
        found = true;
        return;
      }
    }
    super.visitMethodInvocation(node);
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
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'resources'};

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

  static final RegExp _cameraControllerType = RegExp(r'\bCameraController\b');

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
      MethodDeclaration? disposeMethod;
      for (final ClassMember member in node.bodyMembers) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toSource();
          if (typeName != null && _cameraControllerType.hasMatch(typeName)) {
            for (final VariableDeclaration variable
                in member.fields.variables) {
              controllerNames.add(variable.name.lexeme);
            }
          }
        }
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeMethod = member;
        }
      }

      if (controllerNames.isEmpty || disposeMethod == null) return;

      // Check if controllers are disposed
      for (final String name in controllerNames) {
        final bool isDisposed = isFieldCleanedUp(
          name,
          'dispose',
          disposeMethod.body,
        );

        if (!isDisposed) {
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
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'resources'};

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
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'resources'};

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
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'resources'};

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
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'resources'};

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
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'resources'};

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
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'resources'};

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

// =============================================================================
// prefer_using_for_temp_resources
// =============================================================================

/// Suggests using pattern (or try-finally) for temporary resources.
class PreferUsingForTempResourcesRule extends SaropaLintRule {
  PreferUsingForTempResourcesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'resources'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_using_for_temp_resources',
    '[prefer_using_for_temp_resources] Temporary file or resource. Use try-finally or ensure dispose.',
    correctionMessage: 'Wrap in try-finally and close/delete in finally.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'createTemp' &&
          node.methodName.name != 'createTempSync') {
        return;
      }
      reporter.atNode(node);
    });
  }
}
