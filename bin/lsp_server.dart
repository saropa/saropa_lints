/// Standalone Saropa Lints LSP server.
///
/// Implements JSON-RPC 2.0 over stdin/stdout with Content-Length framing.
/// Phase 0: inert skeleton (no diagnostics). Phase 1 will wire real rules
/// via AnalysisContextCollection.
///
/// Run: `dart run saropa_lints:lsp_server`
/// Pass `--trace` to enable verbose logging from startup (otherwise trace
/// output is suppressed until the client sends `$/setTrace` with `verbose`).
library;

import 'dart:convert';
import 'dart:io';

// ---------------------------------------------------------------------------
// Phase 0 test diagnostics REMOVED — proof-of-concept complete (3 of 4
// severity levels confirmed working 2026-09-03). Phase 1 will wire real
// rules here via AnalysisContextCollection.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Whether trace-level logging is active. Set by --trace CLI flag or
/// $/setTrace notification with value 'verbose'. When false, _logTrace
/// calls are suppressed to reduce Output channel noise.
bool _traceEnabled = false;

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
  // Parse --trace flag for standalone debugging (no $/setTrace needed).
  _traceEnabled = args.contains('--trace');
  _log('server starting${_traceEnabled ? ' (trace enabled via --trace)' : ''}');

  // Accumulates raw bytes until a complete Content-Length–framed message
  // arrives, then dispatches it.
  final buffer = <int>[];

  stdin.listen(
    (chunk) {
      buffer.addAll(chunk);
      // A single chunk may contain multiple messages (or a partial one).
      // Keep draining complete messages until the buffer is exhausted.
      _drainMessages(buffer);
    },
    onDone: () => exit(0),
  );
}

// ---------------------------------------------------------------------------
// Message framing (Content-Length header protocol)
// ---------------------------------------------------------------------------

/// Extracts and dispatches complete LSP messages from [buffer], removing
/// consumed bytes. Leaves any incomplete trailing data in place for the
/// next stdin chunk.
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

    // Decode the JSON body and dispatch.
    final bodyBytes = buffer.sublist(bodyStart, messageEnd);
    buffer.removeRange(0, messageEnd);

    final body = utf8.decode(bodyBytes);
    final message = jsonDecode(body) as Map<String, dynamic>;
    _handleMessage(message);
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
// JSON-RPC dispatch
// ---------------------------------------------------------------------------

/// Routes an incoming JSON-RPC message to the appropriate handler based
/// on its `method` field. Requests (with `id`) get a response; notifications
/// (without `id`) are fire-and-forget.
void _handleMessage(Map<String, dynamic> message) {
  final method = message['method'] as String?;
  final id = message['id'];
  final params = message['params'] as Map<String, dynamic>? ?? {};

  switch (method) {
    case 'initialize':
      // Client is asking for our capabilities.
      _log('initialize request received');
      _sendResponse(id, _handleInitialize());
      _log('initialize response sent');
    case 'initialized':
      // Client acknowledges init — handshake complete.
      _log('initialized — handshake complete, server ready');
    case 'textDocument/didOpen':
      // Phase 1 will trigger analysis here.
      _log('didOpen: ${_uri(params)}');
    case 'textDocument/didChange':
      // Phase 1 will trigger incremental re-analysis here.
      _logTrace('didChange: ${_uri(params)}');
    case 'textDocument/didSave':
      // Phase 1 will trigger full re-analysis here.
      _log('didSave: ${_uri(params)}');
    case 'textDocument/didClose':
      // Phase 1 will clear diagnostics here.
      _log('didClose: ${_uri(params)}');
    case r'$/cancelRequest':
      // Nothing to cancel in the inert server.
      _logTrace('cancelRequest: id=${params['id'] ?? '(none)'}');
    case r'$/setTrace':
      // LSP spec values: 'off', 'messages', 'verbose'. Only 'verbose'
      // enables high-frequency _logTrace output; 'messages' and 'off' suppress it.
      final traceValue = params['value'] as String? ?? 'off';
      _traceEnabled = traceValue == 'verbose';
      _log('setTrace: $traceValue (trace logging ${_traceEnabled ? 'on' : 'off'})');
    case 'workspace/didChangeConfiguration':
      // Phase 1 will re-read analysis_options.yaml here.
      _log('didChangeConfiguration');
    case 'textDocument/codeAction':
      // Phase 1 will return quick fixes here.
      _logTrace('codeAction: ${_uri(params)}');
      _sendResponse(id, <Map<String, dynamic>>[]);
    case 'shutdown':
      // Graceful shutdown — respond, then wait for `exit`.
      _log('shutdown requested');
      _sendResponse(id, null);
    case 'exit':
      // Hard exit.
      _log('exit — goodbye');
      exit(0);
    default:
      // Unknown method — log it, and respond with MethodNotFound for requests.
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
      // Full sync = 1: the client sends the whole file content each time.
      'textDocumentSync': 1,
      // We provide quick-fix code actions.
      'codeActionProvider': true,
    },
    'serverInfo': {
      'name': 'saropa_lints_lsp',
      'version': '0.1.0',
    },
  };
}

// Phase 1 will add real diagnostic handlers here — didOpen triggers analysis,
// didSave re-analyzes, didClose clears, codeAction returns quick fixes.

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
// Param helpers
// ---------------------------------------------------------------------------

/// Extracts the textDocument URI from an LSP params map, falling back to
/// '(unknown)' when the structure is unexpected.
String _uri(Map<String, dynamic> params) {
  final td = params['textDocument'] as Map<String, dynamic>?;
  return td?['uri'] as String? ?? '(unknown)';
}
