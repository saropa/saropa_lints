/// Minimal fake LSP server for testing VS Code integration.
///
/// Implements JSON-RPC 2.0 over stdin/stdout with Content-Length framing.
/// Emits hardcoded test diagnostics (one per severity) to prove the
/// standalone LSP plumbing works end-to-end — no real analysis.
///
/// Run: `dart run saropa_lints:lsp_server`
library;

import 'dart:convert';
import 'dart:io';

// ---------------------------------------------------------------------------
// Diagnostic templates — one per LSP severity level.
// ---------------------------------------------------------------------------

/// Each entry defines a fake diagnostic at a specific severity.
/// Severity codes follow the LSP spec: 1=Error, 2=Warning, 3=Info, 4=Hint.
const _diagnosticTemplates = [
  (
    line: 0,
    severity: 1,
    code: 'saropa-lsp-test-error',
    label: 'error',
    message:
        '[saropa_lsp_test] Error-level diagnostic '
        '— proves red squiggles from standalone LSP',
  ),
  (
    line: 1,
    severity: 2,
    code: 'saropa-lsp-test-warning',
    label: 'warning',
    message:
        '[saropa_lsp_test] Warning-level diagnostic '
        '— proves yellow squiggles from standalone LSP',
  ),
  (
    line: 2,
    severity: 3,
    code: 'saropa-lsp-test-info',
    label: 'info',
    message:
        '[saropa_lsp_test] Info-level diagnostic '
        '— proves blue squiggles from standalone LSP',
  ),
  (
    line: 3,
    severity: 4,
    code: 'saropa-lsp-test-hint',
    label: 'hint',
    message:
        '[saropa_lsp_test] Hint-level diagnostic '
        '— proves hint squiggles from standalone LSP',
  ),
];

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

/// Starts the LSP server, reading JSON-RPC messages from stdin and writing
/// responses to stdout. Lifecycle events go to stderr so VS Code can show
/// them in the Output channel.
void main() {
  _log('server starting');

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
      _sendResponse(id, _handleInitialize());
    case 'initialized':
      // Client acknowledges init — nothing to do.
      _log('initialized');
    case 'textDocument/didOpen':
      // A file was opened — emit fake diagnostics.
      _handleDidOpen(params);
    case 'textDocument/didSave':
      // File saved — re-emit the same diagnostics.
      _handleDidSave(params);
    case 'textDocument/didClose':
      // File closed — clear diagnostics for that URI.
      _handleDidClose(params);
    case 'textDocument/codeAction':
      // Client is requesting quick-fix actions for a range.
      _sendResponse(id, _handleCodeAction(params));
    case 'shutdown':
      // Graceful shutdown — respond, then wait for `exit`.
      _log('shutdown');
      _sendResponse(id, null);
    case 'exit':
      // Hard exit.
      exit(0);
    default:
      // Unknown method — if it's a request (has id), send MethodNotFound.
      if (id != null) {
        _sendError(id, -32601, 'Method not found: $method');
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
      'name': 'saropa_lints_test_lsp',
      'version': '0.0.0-fake',
    },
  };
}

/// Tracks the line count of each open file so we only emit diagnostics for
/// lines that actually exist.
final _openFileLineCount = <String, int>{};

/// Handles `textDocument/didOpen` by recording the file's line count and
/// publishing fake diagnostics for it.
void _handleDidOpen(Map<String, dynamic> params) {
  final textDocument = params['textDocument'] as Map<String, dynamic>;
  final uri = textDocument['uri'] as String;
  final text = textDocument['text'] as String? ?? '';

  // Count lines so we don't emit diagnostics past end-of-file.
  final lineCount = text.isEmpty ? 0 : text.split('\n').length;
  _openFileLineCount[uri] = lineCount;

  _publishDiagnostics(uri, lineCount);
}

/// Handles `textDocument/didSave` — re-publishes the same fake diagnostics.
/// We don't re-read content here (save notifications may not include text),
/// so we use the line count from the last didOpen.
void _handleDidSave(Map<String, dynamic> params) {
  final textDocument = params['textDocument'] as Map<String, dynamic>;
  final uri = textDocument['uri'] as String;

  // Fall back to 4 if we never saw didOpen (unlikely but defensive).
  final lineCount = _openFileLineCount[uri] ?? 4;
  _publishDiagnostics(uri, lineCount);
}

/// Handles `textDocument/didClose` — clears diagnostics for the file and
/// forgets its line count.
void _handleDidClose(Map<String, dynamic> params) {
  final textDocument = params['textDocument'] as Map<String, dynamic>;
  final uri = textDocument['uri'] as String;

  _openFileLineCount.remove(uri);

  // Empty diagnostics array clears the squiggles in the editor.
  _sendNotification('textDocument/publishDiagnostics', {
    'uri': uri,
    'diagnostics': <Map<String, dynamic>>[],
  });
  _log('published 0 diagnostics for $uri');
}

/// Builds and publishes fake diagnostics for [uri], capped to [lineCount].
void _publishDiagnostics(String uri, int lineCount) {
  final diagnostics = <Map<String, dynamic>>[];

  for (final t in _diagnosticTemplates) {
    // Skip diagnostics for lines that don't exist in the file.
    if (t.line >= lineCount) continue;

    diagnostics.add({
      'range': {
        'start': {'line': t.line, 'character': 0},
        // char 999 = "to end of line" (client clamps to actual line length).
        'end': {'line': t.line, 'character': 999},
      },
      'severity': t.severity,
      'code': t.code,
      'source': 'saropa_lints',
      'message': t.message,
    });
  }

  _sendNotification('textDocument/publishDiagnostics', {
    'uri': uri,
    'diagnostics': diagnostics,
  });
  _log('published ${diagnostics.length} diagnostics for $uri');
}

/// Handles `textDocument/codeAction` — returns a quick-fix CodeAction for
/// each test diagnostic whose code starts with `saropa-lsp-test-`.
///
/// The fix inserts a dismiss comment at the start of the diagnostic's line,
/// proving that TextEdit round-trip works end-to-end.
List<Map<String, dynamic>> _handleCodeAction(Map<String, dynamic> params) {
  final context = params['context'] as Map<String, dynamic>? ?? {};
  final diagnostics =
      (context['diagnostics'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
  final textDocument = params['textDocument'] as Map<String, dynamic>;
  final uri = textDocument['uri'] as String;

  final actions = <Map<String, dynamic>>[];

  for (final diag in diagnostics) {
    final code = diag['code'] as String? ?? '';
    if (!code.startsWith('saropa-lsp-test-')) continue;

    // Derive the human-readable severity label from the diagnostic code.
    final label = code.replaceFirst('saropa-lsp-test-', '');
    final line = (diag['range'] as Map<String, dynamic>?)?['start']
            as Map<String, dynamic>? ??
        {};
    final lineNumber = line['line'] as int? ?? 0;

    actions.add({
      'title': 'Dismiss this test $label diagnostic',
      'kind': 'quickfix',
      'diagnostics': [diag],
      'edit': {
        'changes': {
          uri: [
            {
              // Insert the dismiss comment at column 0 of the diagnostic line.
              'range': {
                'start': {'line': lineNumber, 'character': 0},
                'end': {'line': lineNumber, 'character': 0},
              },
              'newText': '// saropa_lsp_test: $label dismissed\n',
            },
          ],
        },
      },
    });
  }

  return actions;
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

/// Sends a JSON-RPC notification (no `id`, no response expected).
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
  stderr.writeln('saropa_lsp_test: $message');
}
