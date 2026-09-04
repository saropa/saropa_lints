/// Standalone Saropa Lints LSP server.
///
/// Implements JSON-RPC 2.0 over stdin/stdout with Content-Length framing.
/// Phase 2: real diagnostics + quick fixes via ScanRunner + AnalysisContextCollection.
///
/// Run: `dart run saropa_lints:lsp_server`
/// Pass `--trace` to enable verbose logging from startup (otherwise trace
/// output is suppressed until the client sends `$/setTrace` with `verbose`).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart'
    show CorrectionProducerContext;
import 'package:analysis_server_plugin/edit/fix/dart_fix_context.dart'
    show DartFixContext;
// ignore: implementation_imports -- no public API for DartChangeWorkspace
import 'package:analysis_server_plugin/src/correction/dart_change_workspace.dart'
    show DartChangeWorkspace;
import 'package:analyzer/dart/analysis/results.dart'
    show ResolvedLibraryResult, ResolvedUnitResult;
// ignore: implementation_imports -- Diagnostic lives in _fe_analyzer_shared internals
import 'package:analyzer/diagnostic/diagnostic.dart' show Diagnostic;
import 'package:analyzer/error/error.dart'
    show DiagnosticCode, DiagnosticSeverity, DiagnosticType;
import 'package:analyzer/instrumentation/service.dart'
    show InstrumentationService;
import 'package:analyzer_plugin/protocol/protocol_common.dart'
    show SourceChange;
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart'
    show ChangeBuilder;
import 'package:path/path.dart' as p;
import 'package:saropa_lints/saropa_lints.dart' show getRulesFromRegistry;
import 'package:saropa_lints/scan.dart';
import 'package:saropa_lints/src/report/analysis_reporter.dart'
    show AnalysisReporter;

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Whether trace-level logging is active. Set by --trace CLI flag or
/// $/setTrace notification with value 'verbose'. When false, _logTrace
/// calls are suppressed to reduce Output channel noise.
bool _traceEnabled = false;

/// Project root extracted from the initialize request's rootUri, falling
/// back to the server's working directory. Used as the scan target path.
String? _projectRoot;

/// Tier loaded from the project's analysis_options.yaml (saropa_lints.tier).
/// Passed to ScanRunner so it knows which rules to enable.
String? _tier;

/// Shared analyzer context — built once after initialize, reused for all
/// subsequent scan requests. Null while warming up or if the build failed.
AnalysisContextCollection? _collection;

/// True while the collection is being built, so didOpen/didSave handlers
/// know to skip analysis rather than queueing indefinitely.
bool _collectionBuilding = false;

/// Queued messages waiting for sequential async processing. Messages are
/// extracted from the byte buffer synchronously and appended here; the
/// async _processQueue loop handles them one at a time.
final _messageQueue = <Map<String, dynamic>>[];

/// Whether the async message processor is currently running. Guards
/// against spawning duplicate processing loops.
bool _processing = false;

/// Debounce timer for didOpen — prevents the 200+-file flood that VS Code
/// sends on activation from triggering 200+ full scans. Only the LAST file
/// opened within the debounce window gets analyzed.
Timer? _didOpenDebounce;

/// The URI of the most recently opened file, waiting for the debounce
/// timer to fire. Each new didOpen overwrites this so only the final file
/// in a burst gets analyzed.
Map<String, dynamic>? _pendingDidOpenParams;

/// Files already analyzed via didOpen in this session — avoids re-analyzing
/// the same file on every didOpen flood (VS Code re-sends didOpen after
/// window reload). Cleared on didSave or didClose so edits still trigger
/// fresh analysis.
final _analyzedOnOpen = <String>{};

/// How long to wait after the last didOpen before triggering analysis.
/// 1.5s is long enough to absorb the 200+-file burst that VS Code sends
/// on activation, but short enough to feel responsive for a single
/// user-initiated file open.
const _didOpenDebounceMs = 1500;

/// Per-file diagnostic cache — keyed by file URI, stores the diagnostics
/// from the most recent analysis. Used by textDocument/codeAction to find
/// which diagnostics overlap the requested range and produce quick fixes.
final _fileDiagnostics = <String, List<ScanDiagnostic>>{};

/// Per-rule config loaded from the project's analysis_options.yaml and
/// analysis_options_custom.yaml. Applied as overrides on top of the tier.
/// Null until _buildCollection reads the config.
ScanConfig? _scanConfig;

/// Whether to run a full workspace scan after the analyzer warms up.
/// Read from initializationOptions.workspaceScan (default: true).
/// Configurable via saropaLints.lspServer.workspaceScan in VS Code settings.
bool _workspaceScanEnabled = true;

/// Directories to scan during the startup workspace scan, relative to the
/// project root. Read from initializationOptions.scanDirectories
/// (default: ['lib', 'bin', 'test']). Configurable via
/// saropaLints.lspServer.scanDirectories in VS Code settings.
List<String> _scanDirectories = const ['lib', 'bin', 'test'];

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

/// Starts the LSP server, reading JSON-RPC messages from stdin and writing
/// responses to stdout. Lifecycle events go to stderr so VS Code can show
/// them in the Output channel.
///
/// `--trace` enables verbose logging from startup without waiting for
/// the client to send `$/setTrace verbose`.
void main(List<String> args) {
  // Suppress debounced report writes — same reason as the scan daemon:
  // a long-lived server would litter the target project with log files.
  AnalysisReporter.disableForProcess();

  // Parse --trace flag for standalone debugging (no $/setTrace needed).
  _traceEnabled = args.contains('--trace');
  _log('server starting${_traceEnabled ? ' (trace enabled via --trace)' : ''}');

  // Accumulates raw bytes until a complete Content-Length–framed message
  // arrives, then dispatches it.
  final buffer = <int>[];

  stdin.listen(
    (chunk) {
      buffer.addAll(chunk);
      // Synchronously extract complete messages into the queue; the async
      // processor drains them one at a time so analysis can await.
      _drainMessages(buffer);
      _processQueue();
    },
    onDone: () => exit(0),
  );
}

// ---------------------------------------------------------------------------
// Message framing (Content-Length header protocol)
// ---------------------------------------------------------------------------

/// Extracts complete LSP messages from [buffer] into [_messageQueue],
/// removing consumed bytes. Leaves any incomplete trailing data in place
/// for the next stdin chunk.
void _drainMessages(List<int> buffer) {
  while (true) {
    // Look for the header/body separator (\r\n\r\n).
    final headerEnd = _indexOfHeaderEnd(buffer);
    if (headerEnd == -1) return; // incomplete header

    // Parse Content-Length from the header block.
    final headerStr = utf8.decode(buffer.sublist(0, headerEnd));
    final contentLength = _parseContentLength(headerStr);
    if (contentLength == null) {
      // Malformed header — skip past the separator and try again.
      buffer.removeRange(0, headerEnd + 4);
      continue;
    }

    // Wait until the full body has arrived.
    final bodyStart = headerEnd + 4;
    final messageEnd = bodyStart + contentLength;
    if (buffer.length < messageEnd) return; // body still incomplete

    // Decode the JSON body and enqueue for async processing.
    final bodyBytes = buffer.sublist(bodyStart, messageEnd);
    buffer.removeRange(0, messageEnd);

    final body = utf8.decode(bodyBytes);
    final message = jsonDecode(body) as Map<String, dynamic>;
    _messageQueue.add(message);
  }
}

/// Scans [buffer] for the `\r\n\r\n` sequence that separates the LSP
/// header block from the JSON body. Returns the index of the first `\r`,
/// or -1 if not found.
int _indexOfHeaderEnd(List<int> buffer) {
  // \r=13, \n=10
  for (var i = 0; i < buffer.length - 3; i++) {
    if (buffer[i] == 13 &&
        buffer[i + 1] == 10 &&
        buffer[i + 2] == 13 &&
        buffer[i + 3] == 10) {
      return i;
    }
  }
  return -1;
}

/// Extracts the integer value from a `Content-Length: <N>` header line.
/// Returns null if the header is missing or malformed.
int? _parseContentLength(String header) {
  for (final line in header.split('\r\n')) {
    if (line.toLowerCase().startsWith('content-length:')) {
      return int.tryParse(line.substring(15).trim());
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Async message queue
// ---------------------------------------------------------------------------

/// Processes queued messages one at a time. Awaits each handler so that
/// analysis (which calls getResolvedUnit) completes before the next
/// message is dispatched. Re-entrant-safe via the _processing flag.
Future<void> _processQueue() async {
  if (_processing) return; // already running — new messages will be picked up
  _processing = true;
  try {
    while (_messageQueue.isNotEmpty) {
      final message = _messageQueue.removeAt(0);
      try {
        await _handleMessage(message);
      } on Object catch (e, st) {
        // Per-message catch so one bad message doesn't drop the rest of
        // the queue or surface as an uncaught future error.
        _log('unhandled error processing message: $e');
        _logTrace('stack trace: $st');
      }
    }
  } finally {
    _processing = false;
  }
}

// ---------------------------------------------------------------------------
// JSON-RPC dispatch
// ---------------------------------------------------------------------------

/// Routes an incoming JSON-RPC message to the appropriate handler based
/// on its `method` field. Requests (with `id`) get a response; notifications
/// (without `id`) are fire-and-forget.
Future<void> _handleMessage(Map<String, dynamic> message) async {
  final method = message['method'] as String?;
  final id = message['id'];
  final params = message['params'] as Map<String, dynamic>? ?? {};

  switch (method) {
    case 'initialize':
      // Client is asking for our capabilities. Extract the project root
      // from rootUri so we know where to build the analyzer context.
      // Also reads initializationOptions for user-configurable scan settings.
      _log('initialize request received');
      _projectRoot = _extractProjectRoot(params);
      _log('project root: ${_projectRoot ?? '(unknown)'}');
      _parseInitializationOptions(params);
      _sendResponse(id, _handleInitialize());
      _log('initialize response sent');
    case 'initialized':
      // Client acknowledges init — handshake complete. Now safe to build
      // the analyzer context asynchronously (it takes ~1 min on large
      // projects). We don't await it here; didOpen/didSave will skip
      // analysis until it finishes.
      _log('initialized — handshake complete, building analyzer…');
      unawaited(_buildCollection());
    case 'textDocument/didOpen':
      // Debounce: VS Code sends didOpen for every Dart file in the workspace
      // on activation (~200+ for a real project). Without debouncing, each
      // triggers a full ScanRunner pass and the server is unresponsive for
      // minutes. We buffer the most recent file and analyze it after a quiet
      // period, so the user's actual active file gets analyzed promptly.
      _handleDidOpen(params);
    case 'textDocument/didChange':
      // Defer to didSave — full-content sync mode means we could analyze
      // here, but save is the natural trigger and avoids churn.
      _logTrace('didChange: ${_uri(params)}');
    case 'textDocument/didSave':
      // Re-analyze the saved file immediately — save is explicit user intent,
      // no debounce. Clear the open-cache so fresh results are computed.
      _log('didSave: ${_uri(params)}');
      _analyzedOnOpen.remove(_uri(params));
      await _analyzeFile(params);
    case 'textDocument/didClose':
      // Clear diagnostics so stale squiggles don't linger, remove from
      // the open-cache so the next didOpen re-analyzes, and drop the
      // diagnostic cache so stale fixes aren't offered.
      _log('didClose: ${_uri(params)}');
      _analyzedOnOpen.remove(_uri(params));
      _fileDiagnostics.remove(_uri(params));
      _clearDiagnostics(_uri(params));
    case r'$/cancelRequest':
      // Nothing to cancel — analysis runs to completion.
      _logTrace('cancelRequest: id=${params['id'] ?? '(none)'}');
    case r'$/setTrace':
      // LSP spec values: 'off', 'messages', 'verbose'. Only 'verbose'
      // enables high-frequency _logTrace output; 'messages'/'off' suppress.
      final traceValue = params['value'] as String? ?? 'off';
      _traceEnabled = traceValue == 'verbose';
      _log('setTrace: $traceValue (trace logging ${_traceEnabled ? 'on' : 'off'})');
    case 'workspace/didChangeConfiguration':
      // Re-read tier + per-rule overrides and refresh already-published
      // diagnostics — see _reloadConfigAndReanalyze for why the collection
      // itself doesn't need rebuilding.
      _log('didChangeConfiguration — reloading tier + re-analyzing open files');
      unawaited(_reloadConfigAndReanalyze());
    case '_internal/analyzeFromDidOpen':
      // Synthetic message enqueued by the didOpen debounce timer. Runs
      // inside _processQueue so analysis is sequential with didSave.
      final pendingUri = _uri(params);
      _log('didOpen (debounce fired): $pendingUri');
      _analyzedOnOpen.add(pendingUri);
      await _analyzeFile(params);
    case 'textDocument/codeAction':
      // Quick fixes: match cached diagnostics to the requested range,
      // then run the rule's fix generators to produce real source edits.
      _logTrace('codeAction: ${_uri(params)}');
      final codeActions = await _handleCodeAction(params);
      _sendResponse(id, codeActions);
    case 'shutdown':
      // Graceful shutdown — respond, then wait for `exit`.
      _log('shutdown requested');
      _sendResponse(id, null);
    case 'exit':
      // Hard exit.
      _log('exit — goodbye');
      exit(0);
    default:
      // Unknown method — log it, respond with MethodNotFound for requests.
      if (id != null) {
        _log('unknown request: $method (id=$id) — sending MethodNotFound');
        _sendError(id, -32601, 'Method not found: $method');
      } else {
        _logTrace('unknown notification ignored: $method');
      }
  }
}

// ---------------------------------------------------------------------------
// Handler implementations
// ---------------------------------------------------------------------------

/// Returns the server capabilities payload for the `initialize` response.
/// We advertise full text-document sync (client sends entire content on
/// each change) and code-action support.
Map<String, dynamic> _handleInitialize() {
  return {
    'capabilities': {
      // Open/close notifications + full content on change = 1.
      'textDocumentSync': {
        'openClose': true,
        'change': 1, // Full sync — client sends entire file each time.
        'save': {'includeText': false}, // We re-read from disk on save.
      },
      // We provide quick-fix code actions (Phase 2).
      'codeActionProvider': true,
    },
    'serverInfo': {
      'name': 'saropa_lints_lsp',
      'version': '1.0.0',
    },
  };
}

/// Extracts the project root path from the initialize params. Tries
/// rootUri first (LSP 3.x), falls back to rootPath (deprecated), then
/// the server's working directory.
String? _extractProjectRoot(Map<String, dynamic> params) {
  // rootUri is a file:// URI string — convert to a local path.
  final rootUri = params['rootUri'] as String?;
  if (rootUri != null) {
    return _fileUriToPath(rootUri);
  }
  // Deprecated rootPath fallback for older clients.
  final rootPath = params['rootPath'] as String?;
  if (rootPath != null) return rootPath;
  // Last resort: the process's working directory. The extension spawns
  // the server with cwd set to the project root, so this is correct.
  return Directory.current.path;
}

/// Converts a file:// URI to a local filesystem path. Handles the
/// platform-specific encoding (e.g. /d%3A/ → d:\ on Windows).
String _fileUriToPath(String uriStr) {
  final uri = Uri.parse(uriStr);
  // Uri.toFilePath handles platform path separators and percent-decoding.
  return uri.toFilePath();
}

/// Reads user-configurable scan settings from the initialize request's
/// initializationOptions. These settings are passed by the VS Code extension
/// from saropaLints.lspServer.* configuration. Falls back to defaults when
/// the client doesn't send options (e.g. standalone CLI usage).
void _parseInitializationOptions(Map<String, dynamic> params) {
  // Defensive: initializationOptions can be any JSON value — a malformed
  // client config (or user-edited settings.json) must not crash the
  // initialize handshake. Log and fall back to defaults on bad input.
  try {
    final raw = params['initializationOptions'];
    if (raw is! Map<String, dynamic>) {
      _log('no initializationOptions — using defaults '
          '(workspaceScan: true, dirs: [lib, bin, test])');
      return;
    }

    // Whether to scan all project files on startup.
    if (raw['workspaceScan'] case final bool scan) {
      _workspaceScanEnabled = scan;
    }

    // Which directories to include in the workspace scan. Validate each
    // element is a String — a bare string value or numeric entries from
    // malformed JSON would otherwise crash later in _analyzeWorkspace.
    if (raw['scanDirectories'] case final List<dynamic> dirs) {
      final valid = dirs.whereType<String>().toList();
      if (valid.isNotEmpty) {
        _scanDirectories = valid;
      }
      if (valid.length != dirs.length) {
        _log('warning: scanDirectories contained non-string entries, '
            'ignored ${dirs.length - valid.length} invalid value(s)');
      }
    }

    _log('initializationOptions: workspaceScan=$_workspaceScanEnabled, '
        'dirs=$_scanDirectories');
  } on Object catch (e) {
    // Parse failure must never break the handshake — fall back to defaults.
    _log('warning: failed to parse initializationOptions ($e), '
        'using defaults');
  }
}

// ---------------------------------------------------------------------------
// Analyzer context
// ---------------------------------------------------------------------------

/// Builds the AnalysisContextCollection for the project root. Called once
/// after the initialized notification. The first getResolvedUnit call
/// against the collection resolves the full import graph (~1 min on large
/// projects), but collection construction itself is fast (~1s).
Future<void> _buildCollection() async {
  final root = _projectRoot;
  if (root == null) {
    _log('cannot build analyzer context — no project root');
    return;
  }

  _collectionBuilding = true;
  // Read tier from analysis_options.yaml. Fall back to 'recommended' when the
  // project uses the plugins: saropa_lints: format (individual rule toggles)
  // instead of the saropa_lints: tier: shorthand — without a tier, ScanRunner
  // tries loadScanConfig() which only reads the old diagnostics: section and
  // returns null for most real projects, producing 0 diagnostics.
  _tier = _readTierFromConfig(root) ?? 'recommended';
  _log('tier: $_tier');

  // Load per-rule overrides from diagnostics: section and severity overrides
  // from analysis_options_custom.yaml. ScanRunner applies these on top of
  // the tier in _applyConfigOverrides, but we also store them for logging.
  _scanConfig = loadScanConfig(p.absolute(root));
  if (_scanConfig != null) {
    final enabled = _scanConfig!.enabledRules;
    final disabled = _scanConfig!.disabledRules;
    if (enabled.isNotEmpty) _log('config overrides enabled: ${enabled.length}');
    if (disabled.isNotEmpty) {
      _log('config overrides disabled: ${disabled.length}');
    }
  }
  _log('building AnalysisContextCollection for $root…');
  final sw = Stopwatch()..start();

  try {
    // buildProjectCollection normalizes the path and creates the collection
    // with PhysicalResourceProvider — same as the scan daemon.
    _collection = ScanRunner.buildProjectCollection(root);
    _log(
      'context built in '
      '${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s',
    );

    // Prewarm by resolving one file so the first real didOpen is fast.
    await _prewarm(root);
    _log(
      'analyzer ready in '
      '${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s',
    );

    // Full workspace scan — analyze all Dart files so the Problems panel
    // shows diagnostics project-wide, not just for open files. Runs after
    // the prewarm so the first user interaction isn't delayed.
    // Gated on the user-configurable workspaceScan setting — large projects
    // can disable this to avoid a slow startup.
    if (_workspaceScanEnabled) {
      unawaited(_analyzeWorkspace(root));
    } else {
      _log('workspace scan disabled by user setting');
    }
  } on Object catch (e) {
    _log('failed to build analyzer context: $e');
    _collection = null;
  } finally {
    _collectionBuilding = false;
  }
}

/// Analyzes all Dart files under the configured scan directories so the
/// Problems panel shows project-wide diagnostics on startup — not just for
/// open files. Runs sequentially in the background after the analyzer is
/// warmed up. Skips generated files, build/, and .dart_tool/ directories.
///
/// The entire scan is wrapped in try/catch so a filesystem error (permission
/// denied, symlink cycle, path deleted mid-scan) doesn't crash the isolate
/// via an unhandled async error from the unawaited() call site.
Future<void> _analyzeWorkspace(String root) async {
  final sw = Stopwatch()..start();

  try {
    // Directories to scan — configurable via saropaLints.lspServer.scanDirectories.
    // Defaults to ['lib', 'bin', 'test'] (same scope as the analyzer plugin).
    final scanDirs = _scanDirectories;
    final dartFiles = <String>[];

    for (final dir in scanDirs) {
      final dirPath = p.join(root, dir);
      final directory = Directory(dirPath);
      if (!directory.existsSync()) continue;

      // Walk the directory tree for .dart files, skipping generated/build dirs.
      await for (final entity in directory.list(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;

        final relative = p.relative(entity.path, from: root);
        // Skip code-gen output and build artifacts — these are never
        // user-authored and would just produce noise in the Problems panel.
        if (relative.contains('.g.dart') ||
            relative.contains('.freezed.dart') ||
            relative.contains('.gr.dart') ||
            relative.contains('.dart_tool') ||
            relative.contains('build${p.separator}')) {
          continue;
        }
        dartFiles.add(entity.path);
      }
    }

    if (dartFiles.isEmpty) {
      _log('workspace scan: no Dart files found');
      return;
    }

    _log('workspace scan: analyzing ${dartFiles.length} files…');
    var analyzed = 0;
    var diagnosticCount = 0;

    for (final filePath in dartFiles) {
      // Bail if the analyzer context was torn down (server shutting down).
      if (_collection == null) break;

      final fileUri = Uri.file(p.normalize(p.absolute(filePath))).toString();

      // Skip files that already have published diagnostics (e.g. from a
      // didSave that raced ahead of the workspace scan).
      if (_fileDiagnostics.containsKey(fileUri)) {
        analyzed++;
        continue;
      }

      await _analyzeFile({
        'textDocument': {'uri': fileUri},
      });

      analyzed++;
      diagnosticCount += _fileDiagnostics[fileUri]?.length ?? 0;

      // Yield to the event loop between files so didSave/codeAction requests
      // aren't starved by a long scan.
      await Future<void>.delayed(Duration.zero);
    }

    _log(
      'workspace scan complete: $analyzed files, $diagnosticCount diagnostic(s) '
      'in ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s',
    );
  } on Object catch (e, st) {
    // A filesystem error (permission denied, symlink cycle, path deleted
    // mid-walk) must not crash the isolate — the scan is fire-and-forget
    // via unawaited(), so an unhandled error would be an uncaught future.
    _log('workspace scan failed after '
        '${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s: $e');
    _logTrace('workspace scan stack trace: $st');
  }
}

/// Re-reads the tier from analysis_options.yaml and re-analyzes every file
/// with published diagnostics, so a config edit takes effect without a
/// server restart. Per-rule overrides in analysis_options_custom.yaml
/// already reload on every analysis pass (ScanRunner._applyConfigOverrides
/// calls loadScanConfig fresh each time) — what's stale is the cached
/// [_tier] and diagnostics already sitting in the Problems panel for files
/// that won't be saved/reopened soon. The AnalysisContextCollection itself
/// doesn't depend on rule config, so it's left untouched — rebuilding it is
/// the expensive step (~1s+ plus a re-prewarm) and buys nothing here.
Future<void> _reloadConfigAndReanalyze() async {
  final root = _projectRoot;
  if (root == null || _collection == null) {
    _logTrace('didChangeConfiguration: analyzer not ready, skipping reload');
    return;
  }

  final newTier = _readTierFromConfig(root) ?? 'recommended';
  if (newTier != _tier) {
    _log('tier changed: $_tier -> $newTier');
    _tier = newTier;
  }
  _scanConfig = loadScanConfig(p.absolute(root));

  // Re-analyze every file that currently has live diagnostics so the
  // Problems panel reflects the new rule set immediately instead of waiting
  // for the next save.
  final publishedUris = _fileDiagnostics.keys.toList();
  for (final uri in publishedUris) {
    await _analyzeFile({
      'textDocument': {'uri': uri},
    });
  }
  _log('didChangeConfiguration: re-analyzed ${publishedUris.length} file(s)');
}

/// Resolves one representative file to prewarm the analyzer's element
/// models. Same strategy as the scan daemon: main.dart if it exists,
/// else the first .dart file under lib/.
Future<void> _prewarm(String projectRoot) async {
  final root = p.normalize(p.absolute(projectRoot));
  final mainFile = File(p.join(root, 'lib', 'main.dart'));
  String? target;
  if (mainFile.existsSync()) {
    target = mainFile.path;
  } else {
    final libDir = Directory(p.join(root, 'lib'));
    if (libDir.existsSync()) {
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          target = p.normalize(entity.path);
          break;
        }
      }
    }
  }

  if (target == null) {
    _log('no lib/*.dart file found to prewarm with');
    return;
  }

  _logTrace('prewarming analyzer on $target…');
  try {
    final context = _collection!.contextFor(target);
    await context.currentSession.getResolvedUnit(target);
  } on Object catch (e) {
    // Non-fatal — the first real scan will just be slower.
    _log('prewarm failed (continuing cold): $e');
  }
}

// ---------------------------------------------------------------------------
// Diagnostics
// ---------------------------------------------------------------------------

/// Debounced handler for textDocument/didOpen. Absorbs the initial burst
/// of 200+ didOpen notifications VS Code sends on activation by only
/// analyzing the LAST file opened after a quiet period.
void _handleDidOpen(Map<String, dynamic> params) {
  final uri = _uri(params);

  // Already analyzed this file via didOpen — skip until the user saves or
  // closes and re-opens. Without this, window reloads re-flood.
  if (_analyzedOnOpen.contains(uri)) {
    _logTrace('didOpen (already analyzed, skipping): $uri');
    return;
  }

  _logTrace('didOpen (queued for debounce): $uri');

  // Cancel any pending debounce — only the last file in a burst matters.
  _didOpenDebounce?.cancel();
  _pendingDidOpenParams = params;

  _didOpenDebounce = Timer(
    Duration(milliseconds: _didOpenDebounceMs),
    () {
      final pending = _pendingDidOpenParams;
      _pendingDidOpenParams = null;
      if (pending == null) return;

      // Enqueue a synthetic message so analysis runs inside _processQueue's
      // sequential loop, preventing concurrent analysis with didSave.
      _messageQueue.add({
        'method': '_internal/analyzeFromDidOpen',
        'params': pending,
      });
      _processQueue();
    },
  );
}

/// Runs saropa_lints rules against the file identified in [params] and
/// publishes the results as LSP diagnostics. Skips gracefully if the
/// analyzer context isn't ready yet.
Future<void> _analyzeFile(Map<String, dynamic> params) async {
  final fileUri = _uri(params);
  final filePath = _fileUriToPath(fileUri);

  if (_collection == null) {
    // Analyzer still warming up — log and skip. The user will see
    // diagnostics after the next save once the context is ready.
    final reason = _collectionBuilding ? 'warming up' : 'unavailable';
    _logTrace('skipping analysis ($reason): $filePath');
    return;
  }

  final root = _projectRoot;
  if (root == null) return;

  _logTrace('analyzing: $filePath');
  final sw = Stopwatch()..start();

  try {
    // Normalize the path so the analyzer recognizes it (Windows drive
    // letter casing, forward slashes, etc.).
    final absPath = p.normalize(p.absolute(filePath));

    // Notify the collection that this file changed so it re-resolves.
    try {
      final ctx = _collection!.contextFor(absPath);
      ctx.changeFile(absPath);
      await ctx.applyPendingFileChanges();
    } on StateError {
      // File is outside the analysis roots or excluded by the project's
      // analysis_options.yaml — skip silently.
      _logTrace('file outside analysis roots, skipping: $absPath');
      return;
    }

    // Run all saropa_lints rules against this single file. The tier is read
    // from the project's analysis_options.yaml so ScanRunner knows which
    // rules to enable — without it, it falls back to the diagnostics: section
    // which many projects don't have.
    // applyExclusionsToFileList: false — the user explicitly opened this file
    // in the editor, so we must analyze it even if it lives under a path the
    // CLI scanner would exclude (e.g. example/, bin/, generated/).
    final runner = ScanRunner(
      targetPath: root,
      dartFiles: [absPath],
      tier: _tier,
      applyExclusionsToFileList: false,
      messageSink: (msg) => _log('scan: $msg'),
    );
    final diagnostics = await runner.runResolvedWithCollection(_collection!);

    // Cache diagnostics per-file so codeAction can look them up later
    // to produce quick fixes for the correct diagnostic range.
    final fileDiags = diagnostics ?? [];
    _fileDiagnostics[fileUri] = fileDiags;

    // Convert ScanDiagnostics to LSP Diagnostic objects and publish.
    final lspDiagnostics = fileDiags.map(_scanDiagnosticToLsp).toList();

    _publishDiagnostics(fileUri, lspDiagnostics);
    _log(
      'published ${lspDiagnostics.length} diagnostic(s) for '
      '${p.basename(filePath)} in '
      '${(sw.elapsedMilliseconds / 1000).toStringAsFixed(2)}s',
    );
  } on Object catch (e, st) {
    _log('analysis failed for $filePath: $e');
    _logTrace('stack trace: $st');
  }
}

/// Converts a [ScanDiagnostic] to an LSP-compatible Diagnostic map.
/// LSP line/column are 0-based; ScanDiagnostic uses 1-based.
Map<String, dynamic> _scanDiagnosticToLsp(ScanDiagnostic d) {
  return {
    'range': {
      'start': {'line': d.line - 1, 'character': d.column - 1},
      'end': {'line': d.endLine - 1, 'character': d.endColumn - 1},
    },
    'severity': _lspSeverity(d.severity),
    'code': d.ruleName,
    'source': 'saropa_lints',
    'message': d.problemMessage ?? d.ruleName,
    // Correction message shown as a related hint when available.
    if (d.correctionMessage != null)
      'relatedInformation': [
        {
          'location': {
            'uri': Uri.file(d.filePath).toString(),
            'range': {
              'start': {'line': d.line - 1, 'character': d.column - 1},
              'end': {'line': d.endLine - 1, 'character': d.endColumn - 1},
            },
          },
          'message': d.correctionMessage,
        },
      ],
  };
}

/// Maps ScanDiagnostic severity strings to LSP DiagnosticSeverity ints.
/// LSP: 1=Error, 2=Warning, 3=Information, 4=Hint.
int _lspSeverity(String severity) {
  return switch (severity.toUpperCase()) {
    'ERROR' => 1,
    'WARNING' => 2,
    'INFO' => 3,
    _ => 4, // HINT or unknown → Hint
  };
}

/// Sends a textDocument/publishDiagnostics notification to the client.
void _publishDiagnostics(
  String uri,
  List<Map<String, dynamic>> diagnostics,
) {
  _sendNotification('textDocument/publishDiagnostics', {
    'uri': uri,
    'diagnostics': diagnostics,
  });
}

/// Clears diagnostics for a file by publishing an empty array.
void _clearDiagnostics(String uri) {
  _publishDiagnostics(uri, []);
  _logTrace('cleared diagnostics for $uri');
}

// ---------------------------------------------------------------------------
// Quick fixes (textDocument/codeAction)
// ---------------------------------------------------------------------------

/// Produces LSP CodeAction objects for diagnostics that overlap the requested
/// range. For each cached ScanDiagnostic whose rule has fix generators, we
/// resolve the file, build a CorrectionProducerContext, and run the fix to
/// get source edits.
Future<List<Map<String, dynamic>>> _handleCodeAction(
  Map<String, dynamic> params,
) async {
  final fileUri = _uri(params);
  final filePath = _fileUriToPath(fileUri);

  // The range the editor is asking about (cursor position or selection).
  final range = params['range'] as Map<String, dynamic>?;
  if (range == null) return [];

  final startLine = _rangeField(range, 'start', 'line');
  final endLine = _rangeField(range, 'end', 'line');

  // Look up cached diagnostics for this file.
  final cached = _fileDiagnostics[fileUri];
  if (cached == null || cached.isEmpty) return [];

  if (_collection == null) return [];

  // Filter to diagnostics that overlap the requested range (0-based lines).
  final overlapping = cached.where((d) {
    // ScanDiagnostic uses 1-based lines; LSP range is 0-based.
    final dStartLine = d.line - 1;
    final dEndLine = d.endLine - 1;
    return dEndLine >= startLine && dStartLine <= endLine;
  }).toList();

  if (overlapping.isEmpty) return [];

  // Resolve the file once — all fixes share the same resolved unit.
  final absPath = p.normalize(p.absolute(filePath));
  ResolvedUnitResult resolvedUnit;
  ResolvedLibraryResult resolvedLibrary;
  try {
    final ctx = _collection!.contextFor(absPath);
    final unitResult = await ctx.currentSession.getResolvedUnit(absPath);
    if (unitResult is! ResolvedUnitResult) return [];
    resolvedUnit = unitResult;

    final libResult = await ctx.currentSession.getResolvedLibrary(absPath);
    if (libResult is! ResolvedLibraryResult) return [];
    resolvedLibrary = libResult;
  } on Object catch (e) {
    _log('codeAction resolve failed: $e');
    return [];
  }

  final actions = <Map<String, dynamic>>[];

  for (final diag in overlapping) {
    // Look up the rule and its fix generators.
    final rules = getRulesFromRegistry({diag.ruleName});
    if (rules.isEmpty) continue;
    final rule = rules.first;
    if (rule.fixGenerators.isEmpty) continue;

    // Build a Diagnostic object for the CorrectionProducerContext.
    final diagnostic = _buildDiagnostic(diag, resolvedUnit);

    // Build the workspace and fix context needed by the correction producer.
    final workspace = DartChangeWorkspace(
      [resolvedUnit.session],
    );
    final fixContext = DartFixContext(
      instrumentationService: InstrumentationService.NULL_SERVICE,
      workspace: workspace,
      libraryResult: resolvedLibrary,
      unitResult: resolvedUnit,
      error: diagnostic,
    );

    // Run each fix generator for this rule.
    for (final generator in rule.fixGenerators) {
      try {
        final context = CorrectionProducerContext.createResolved(
          libraryResult: resolvedLibrary,
          unitResult: resolvedUnit,
          dartFixContext: fixContext,
          diagnostic: diagnostic,
          selectionOffset: diag.offset,
          selectionLength: diag.length,
        );

        final producer = generator(context: context);
        final builder = ChangeBuilder(session: resolvedUnit.session);
        await producer.compute(builder);

        final sourceChange = builder.sourceChange;
        if (sourceChange.edits.isEmpty) continue;

        // Convert analyzer SourceChange to LSP CodeAction with WorkspaceEdit.
        // Use the fix kind message if the source change has no message.
        final fixKind = producer.fixKind;
        final title = sourceChange.message.isNotEmpty
            ? sourceChange.message
            : fixKind?.message ?? diag.ruleName;
        final lspEdits = _sourceChangeToWorkspaceEdit(sourceChange);
        actions.add({
          'title': title,
          'kind': 'quickfix',
          'diagnostics': [_scanDiagnosticToLsp(diag)],
          'edit': lspEdits,
        });
      } on Object catch (e) {
        // Non-fatal — skip this fix, offer others if available.
        _logTrace('fix failed for ${diag.ruleName}: $e');
      }
    }
  }

  _log('codeAction: ${actions.length} fix(es) for ${p.basename(filePath)}');
  return actions;
}

/// Builds an analyzer [Diagnostic] from a [ScanDiagnostic] for use in
/// the correction producer context. The diagnostic carries the offset,
/// length, and code so the fix producer can locate the covering AST node.
Diagnostic _buildDiagnostic(
  ScanDiagnostic diag,
  ResolvedUnitResult unitResult,
) {
  return Diagnostic.forValues(
    source: unitResult.libraryFragment.source,
    offset: diag.offset,
    length: diag.length,
    diagnosticCode: _ScanDiagnosticCode(diag.ruleName, diag.severity),
    message: diag.problemMessage ?? diag.ruleName,
    correctionMessage: diag.correctionMessage,
  );
}

/// Converts an analyzer SourceChange to an LSP WorkspaceEdit map. Each
/// SourceFileEdit becomes a documentChanges entry with TextEdits. Typed
/// directly against `analyzer_plugin`'s protocol_common SourceChange —
/// those are plain hand-written classes (no protobuf/codegen), so the
/// import carries no extra dependency weight over the `dynamic` casts this
/// replaced.
Map<String, dynamic> _sourceChangeToWorkspaceEdit(SourceChange sourceChange) {
  final documentChanges = <Map<String, dynamic>>[];

  for (final fileEdit in sourceChange.edits) {
    final filePath = fileEdit.file;
    final fileUri = Uri.file(filePath).toString();

    // Read the file content once to convert offsets to line:column.
    String? content;
    try {
      content = File(filePath).readAsStringSync();
    } on Object {
      // Skip this file edit if unreadable — non-fatal.
      continue;
    }

    final textEdits = <Map<String, dynamic>>[];
    for (final edit in fileEdit.edits) {
      final startOffset = edit.offset;
      final endOffset = startOffset + edit.length;
      textEdits.add({
        'range': {
          'start': _offsetToPosition(content, startOffset),
          'end': _offsetToPosition(content, endOffset),
        },
        'newText': edit.replacement,
      });
    }

    documentChanges.add({
      'textDocument': {'uri': fileUri, 'version': null},
      'edits': textEdits,
    });
  }

  return {'documentChanges': documentChanges};
}

/// Converts a byte offset to an LSP Position {line, character} by counting
/// newlines in [content] up to [offset].
Map<String, int> _offsetToPosition(String content, int offset) {
  var line = 0;
  var lastNewline = -1;
  final clampedOffset = offset.clamp(0, content.length);
  for (var i = 0; i < clampedOffset; i++) {
    if (content.codeUnitAt(i) == 10) {
      // \n
      line++;
      lastNewline = i;
    }
  }
  return {'line': line, 'character': clampedOffset - lastNewline - 1};
}

/// Minimal DiagnosticCode wrapping a scan rule name so we can construct
/// a Diagnostic for the CorrectionProducerContext. Only severity and type
/// matter for fix dispatch — the rest is pass-through.
class _ScanDiagnosticCode extends DiagnosticCode {
  _ScanDiagnosticCode(String ruleName, String severityStr)
      : _severity = _parseSeverity(severityStr),
        super(
          name: ruleName,
          problemMessage: ruleName,
          uniqueName: 'saropa_lints.$ruleName',
        );

  /// Converts a ScanDiagnostic severity string to the analyzer enum.
  static DiagnosticSeverity _parseSeverity(String s) {
    return switch (s.toUpperCase()) {
      'ERROR' => DiagnosticSeverity.ERROR,
      'WARNING' => DiagnosticSeverity.WARNING,
      'INFO' => DiagnosticSeverity.INFO,
      _ => DiagnosticSeverity.WARNING,
    };
  }

  /// Maps the scan diagnostic's severity string to the analyzer's enum.
  /// Defaults to WARNING for unknown values — doesn't affect which fix
  /// is generated, but keeps the Diagnostic metadata consistent.
  final DiagnosticSeverity _severity;

  @override
  DiagnosticSeverity get severity => _severity;

  @override
  DiagnosticType get type => DiagnosticType.LINT;
}

// ---------------------------------------------------------------------------
// JSON-RPC output helpers
// ---------------------------------------------------------------------------

/// Sends a JSON-RPC response (for a request that had an `id`).
void _sendResponse(dynamic id, dynamic result) {
  _send({'jsonrpc': '2.0', 'id': id, 'result': result});
}

/// Sends a JSON-RPC error response.
void _sendError(dynamic id, int code, String message) {
  _send({
    'jsonrpc': '2.0',
    'id': id,
    'error': {'code': code, 'message': message},
  });
}

/// Sends a JSON-RPC notification (no id — fire-and-forget from server
/// to client). Used for publishDiagnostics.
void _sendNotification(String method, Map<String, dynamic> params) {
  _send({'jsonrpc': '2.0', 'method': method, 'params': params});
}

/// Encodes a JSON-RPC message with Content-Length framing and writes it
/// to stdout. This is the single point of egress for all LSP output.
void _send(Map<String, dynamic> message) {
  final body = jsonEncode(message);
  final bodyBytes = utf8.encode(body);
  // LSP framing: header, blank line, body.
  stdout.write('Content-Length: ${bodyBytes.length}\r\n\r\n');
  stdout.add(bodyBytes);
}

/// Writes a timestamped log line to stderr. VS Code captures stderr and
/// shows it in the language server's Output channel.
void _log(String message) {
  stderr.writeln('saropa_lsp: $message');
}

/// Verbose log for high-frequency messages (didChange, codeAction, cancel).
/// Suppressed unless --trace is passed or the client sends $/setTrace verbose.
void _logTrace(String message) {
  if (!_traceEnabled) return;
  stderr.writeln('saropa_lsp [trace]: $message');
}

// ---------------------------------------------------------------------------
// Config helpers
// ---------------------------------------------------------------------------

/// Reads the `tier:` value from `saropa_lints:` in analysis_options.yaml.
/// Returns null if the file or key is missing.
String? _readTierFromConfig(String projectRoot) {
  final configFile = File(p.join(projectRoot, 'analysis_options.yaml'));
  if (!configFile.existsSync()) return null;

  // Normalize \r\n → \n so the regex works on Windows, where
  // readAsStringSync preserves CRLF from the file on disk.
  final content = configFile.readAsStringSync().replaceAll('\r\n', '\n');
  // Match `tier:` under `saropa_lints:` — the value is the tier name.
  // Regex: look for `saropa_lints:` then any lines, then `tier: <value>`.
  final match = RegExp(
    r'saropa_lints:\s*\n(?:\s+.*\n)*?\s+tier:\s*(\w+)',
  ).firstMatch(content);
  return match?.group(1);
}

// ---------------------------------------------------------------------------
// Param helpers
// ---------------------------------------------------------------------------

/// Extracts the textDocument URI from an LSP params map, falling back to
/// '(unknown)' when the structure is unexpected.
String _uri(Map<String, dynamic> params) {
  final td = params['textDocument'] as Map<String, dynamic>?;
  return td?['uri'] as String? ?? '(unknown)';
}

/// Extracts a nested integer field from an LSP range object.
/// e.g. _rangeField(range, 'start', 'line') reads range.start.line.
int _rangeField(Map<String, dynamic> range, String pos, String field) {
  final position = range[pos] as Map<String, dynamic>?;
  return position?[field] as int? ?? 0;
}
