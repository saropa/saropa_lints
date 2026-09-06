import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import {
  toVscodeDiagnostic,
  groupDiagnosticsByFile,
  scanOnSaveIsEnabled,
  isDocumentUserOpen,
  queuedBatchExceedsCap,
  formatScanFileListForLog,
  MAX_QUEUED_SCAN_FILES,
  ScanOnSaveController,
  tabInputUriPaths,
} from '../../scanOnSave/scanOnSaveController';
import type { ScanOnSaveDiagnostic } from '../../scanOnSave/scanOnSaveRunner';
import * as vscode from 'vscode';

function diag(overrides: Partial<ScanOnSaveDiagnostic> = {}): ScanOnSaveDiagnostic {
  return {
    filePath: '/proj/lib/a.dart',
    line: 10,
    column: 5,
    ruleName: 'avoid_something',
    severity: 'WARNING',
    problemMessage: 'do not do this',
    correctionMessage: null,
    ...overrides,
  };
}

describe('toVscodeDiagnostic', () => {
  it('converts 1-based scan line/column to 0-based VS Code Range', () => {
    const d = toVscodeDiagnostic(diag({ line: 10, column: 5 }));
    assert.strictEqual(d.range.start.line, 9);
    assert.strictEqual(d.range.start.character, 4);
  });

  it('uses endLine/endColumn for a full-span range when present', () => {
    // Diagnostic spanning columns 3–25 on line 10 (1-based from Dart).
    const d = toVscodeDiagnostic(diag({ line: 10, column: 3, endLine: 10, endColumn: 25 }));
    assert.strictEqual(d.range.start.line, 9);
    assert.strictEqual(d.range.start.character, 2);
    assert.strictEqual(d.range.end.line, 9);
    assert.strictEqual(d.range.end.character, 24);
  });

  it('falls back to column + 1 when endLine/endColumn are absent', () => {
    // Legacy scan output without end position fields.
    const d = toVscodeDiagnostic(diag({ line: 10, column: 5 }));
    assert.strictEqual(d.range.end.line, 9);
    assert.strictEqual(d.range.end.character, 5);
  });

  it('supports multi-line diagnostic spans', () => {
    const d = toVscodeDiagnostic(diag({ line: 5, column: 3, endLine: 8, endColumn: 10 }));
    assert.strictEqual(d.range.start.line, 4);
    assert.strictEqual(d.range.start.character, 2);
    assert.strictEqual(d.range.end.line, 7);
    assert.strictEqual(d.range.end.character, 9);
  });

  it('extends zero-width range to end-of-line so the diagnostic stays visible', () => {
    // endLine == line and endColumn == column → zero-width → extend to EOL.
    const d = toVscodeDiagnostic(diag({ line: 10, column: 5, endLine: 10, endColumn: 5 }));
    assert.strictEqual(d.range.start.line, 9);
    assert.strictEqual(d.range.start.character, 4);
    assert.strictEqual(d.range.end.line, 9);
    // VS Code clamps MAX_SAFE_INTEGER to the actual line length.
    assert.ok(d.range.end.character > 4, 'end character should extend past start');
  });

  it('clamps line/column at 0 for file-level findings (line=1, column=0)', () => {
    const d = toVscodeDiagnostic(diag({ line: 1, column: 0 }));
    assert.strictEqual(d.range.start.line, 0);
    assert.strictEqual(d.range.start.character, 0);
  });

  it('maps severities and stamps source/code', () => {
    const d = toVscodeDiagnostic(diag({ severity: 'ERROR' }));
    assert.strictEqual(d.severity, vscode.DiagnosticSeverity.Error);
    assert.strictEqual(d.source, 'saropa_lints');
    assert.strictEqual(d.code, 'avoid_something');
  });

  it('appends the correction message when present', () => {
    const d = toVscodeDiagnostic(diag({ problemMessage: 'bad', correctionMessage: 'do X instead' }));
    assert.ok(d.message.includes('bad'));
    assert.ok(d.message.includes('do X instead'));
  });

  it('falls back to the rule name when problemMessage is absent', () => {
    const d = toVscodeDiagnostic(diag({ problemMessage: null }));
    assert.strictEqual(d.message, 'avoid_something');
  });
});

describe('scanOnSaveIsEnabled', () => {
  it('runs when the master toggle is on', () => {
    assert.strictEqual(scanOnSaveIsEnabled(true), true);
  });

  it('stays off when the master toggle is off', () => {
    assert.strictEqual(scanOnSaveIsEnabled(false), false);
  });
});

describe('groupDiagnosticsByFile', () => {
  it('groups multiple diagnostics per file and keeps distinct files separate', () => {
    const grouped = groupDiagnosticsByFile([
      diag({ filePath: '/a.dart' }),
      diag({ filePath: '/a.dart', line: 20 }),
      diag({ filePath: '/b.dart' }),
    ]);
    assert.strictEqual(grouped.get('/a.dart')?.length, 2);
    assert.strictEqual(grouped.get('/b.dart')?.length, 1);
  });

  it('returns an empty map for no diagnostics', () => {
    assert.strictEqual(groupDiagnosticsByFile([]).size, 0);
  });
});

describe('isDocumentUserOpen (Gate O)', () => {
  // Regression pins for
  // plans/history/2026.09/2026.09.05/infra_drift_poll_opens_every_dart_file_triggers_full_project_scan.md:
  // onDidOpenTextDocument fires for programmatic opens from any extension, and
  // treating those as "the user opened a file" turned a 30-second poll into 33
  // full-project resolved scans that exhausted system memory.
  it('rejects a document opened programmatically (no editor, no tab)', () => {
    assert.strictEqual(isDocumentUserOpen('/proj/lib/hidden.dart', [], []), false);
  });

  it('accepts a document open in a background tab the user is not looking at', () => {
    // The load-bearing case: a real user tab that is not the active editor
    // must still be scanned, exactly as before the fix.
    assert.strictEqual(
      isDocumentUserOpen('/proj/lib/bg.dart', [], ['/proj/lib/other.dart', '/proj/lib/bg.dart']),
      true,
    );
  });

  it('accepts a document shown in a visible editor', () => {
    assert.strictEqual(isDocumentUserOpen('/proj/lib/a.dart', ['/proj/lib/a.dart'], []), true);
  });

  it('rejects a different file with a similar path', () => {
    assert.strictEqual(
      isDocumentUserOpen('/proj/lib/a.dart', ['/proj/lib/ab.dart'], ['/proj/lib/a_test.dart']),
      false,
    );
  });
});

describe('queuedBatchExceedsCap', () => {
  it('sits at 200 — high enough that a real tab count never trips it', () => {
    // Pinned literally: the value is a deliberate judgment (see the doc
    // comment), so a silent change to it should fail this test, not slip by.
    assert.strictEqual(MAX_QUEUED_SCAN_FILES, 200);
  });

  it('allows a batch at the cap', () => {
    assert.strictEqual(queuedBatchExceedsCap(200), false);
  });

  it('rejects a batch one file over the cap', () => {
    assert.strictEqual(queuedBatchExceedsCap(201), true);
  });

  it('leaves an ordinary 50-tab session alone', () => {
    assert.strictEqual(queuedBatchExceedsCap(50), false);
  });

  it('rejects the whole-project batch size from the incident', () => {
    assert.strictEqual(queuedBatchExceedsCap(4598), true);
  });
});

describe('formatScanFileListForLog', () => {
  it('prints every path when the batch is small', () => {
    assert.strictEqual(formatScanFileListForLog(['/a.dart', '/b.dart']), '/a.dart, /b.dart');
  });

  it('samples the first five and summarizes the rest', () => {
    const files = Array.from({ length: 4598 }, (_, i) => `/proj/lib/f${i}.dart`);
    const line = formatScanFileListForLog(files);
    assert.ok(line.startsWith('/proj/lib/f0.dart, /proj/lib/f1.dart'));
    assert.ok(line.endsWith('and 4593 more'));
    // The whole point: the line must stay small. The old join produced 354 KB.
    assert.ok(line.length < 500, `log line too long: ${line.length}`);
  });
});

/**
 * Builds a controller wired to stub collaborators. Only the queue paths are
 * exercised here — no scan is ever allowed to launch, which is precisely what
 * the oversized-batch test asserts.
 */
function makeController(log: string[]): ScanOnSaveController {
  const collection = {
    set: () => { /* no-op */ },
    clear: () => { /* no-op */ },
    dispose: () => { /* no-op */ },
  } as unknown as vscode.DiagnosticCollection;
  const channel = {
    appendLine: (line: string) => log.push(line),
    show: () => { /* no-op */ },
    dispose: () => { /* no-op */ },
  } as unknown as vscode.OutputChannel;
  return new ScanOnSaveController(collection, () => '/proj', channel);
}

/** Seeds the pending queue with [count] paths of the given provenance. */
function seedQueue(
  inner: { _pendingFiles: Map<string, string> },
  count: number,
  origin: 'save' | 'open',
  prefix = '/proj/lib/f',
): string[] {
  const paths: string[] = [];
  for (let i = 0; i < count; i++) {
    const p = `${prefix}${i}.dart`;
    inner._pendingFiles.set(p, origin);
    paths.push(p);
  }
  return paths;
}

/**
 * Runs [body] with the mock window reporting [paths] as visible editors, so
 * Gate O sees them as genuinely open. Restores the previous value afterwards
 * — the mock is shared across every suite in this mocha process.
 */
function withVisibleEditors(paths: readonly string[], body: () => void): void {
  const w = vscode.window as unknown as { visibleTextEditors?: unknown };
  const previous = w.visibleTextEditors;
  w.visibleTextEditors = paths.map((p) => ({ document: { uri: { fsPath: p } } }));
  try {
    body();
  } finally {
    w.visibleTextEditors = previous;
  }
}

interface ControllerInternals {
  _pendingFiles: Map<string, string>;
  _scanInFlight: boolean;
  _runQueuedScan: (root: string) => void;
  _scan: (root: string, files: string[]) => Promise<void>;
}

describe('ScanOnSaveController queue backstop', () => {
  it('scans a 201-file Save All — the cap must never drop a user save', () => {
    // Regression pin: an earlier revision applied the cap to the whole pending
    // set, so a refactor across many files plus Save All produced no diagnostics
    // at all and only an output-channel line to explain it.
    const log: string[] = [];
    const controller = makeController(log);
    const inner = controller as unknown as ControllerInternals;
    let scanned: string[] = [];
    inner._scan = async (_root, files) => { scanned = files; };
    seedQueue(inner, 201, 'save');
    inner._runQueuedScan('/proj');
    assert.strictEqual(scanned.length, 201);
    assert.ok(!log.some((l) => l.includes('ABORTED')), 'a save batch must never be aborted');
    controller.dispose();
  });

  it('drops a 201-file programmatic-open batch without scanning', () => {
    // No editors and no tabs exist in the mock window, so every open-derived
    // path is programmatic — exactly the Drift Advisor poll scenario.
    const log: string[] = [];
    const controller = makeController(log);
    const inner = controller as unknown as ControllerInternals;
    let scanCalls = 0;
    inner._scan = async () => { scanCalls++; };
    seedQueue(inner, 201, 'open');
    inner._runQueuedScan('/proj');
    assert.strictEqual(scanCalls, 0, 'no scan may be launched for a programmatic open storm');
    assert.strictEqual(inner._scanInFlight, false);
    assert.strictEqual(inner._pendingFiles.size, 0, 'the poisoned queue must be emptied');
    // Gate O now reports at scan time, in ONE sampled line for the batch.
    const skipped = log.filter((l) => l.includes('opened programmatically'));
    assert.strictEqual(skipped.length, 1, `expected one sampled skip line, got ${skipped.length}`);
    assert.ok(skipped[0].includes('201 file(s)'));
    controller.dispose();
  });

  it('mixes provenance: saves scan even when opens in the same batch are dropped', () => {
    const controller = makeController([]);
    const inner = controller as unknown as ControllerInternals;
    let scanned: string[] = [];
    inner._scan = async (_root, files) => { scanned = files; };
    seedQueue(inner, 201, 'open', '/proj/lib/opened');
    inner._pendingFiles.set('/proj/lib/saved.dart', 'save');
    inner._runQueuedScan('/proj');
    assert.deepStrictEqual(scanned, ['/proj/lib/saved.dart']);
    controller.dispose();
  });

  it('scans a small batch of genuinely open files (Gate O runs at scan time)', () => {
    const controller = makeController([]);
    const inner = controller as unknown as ControllerInternals;
    let scanned: string[] = [];
    inner._scan = async (_root, files) => { scanned = files; };
    const paths = seedQueue(inner, 3, 'open', '/proj/lib/open');
    withVisibleEditors(paths, () => inner._runQueuedScan('/proj'));
    assert.deepStrictEqual(scanned, paths, 'open files the user can see must still scan');
    controller.dispose();
  });

  it('surfaces a dropped batch in the status bar, not only the log', () => {
    const controller = makeController([]);
    const inner = controller as unknown as ControllerInternals & {
      _statusBarItem: { text: string; tooltip: string };
    };
    inner._scan = async () => { /* never reached */ };
    // Force the batch past Gate O so the cap itself is what drops it.
    const paths = seedQueue(inner, 201, 'open');
    withVisibleEditors(paths, () => inner._runQueuedScan('/proj'));
    assert.ok(
      inner._statusBarItem.text.includes('201'),
      `status bar should name the dropped count, got: ${inner._statusBarItem.text}`,
    );
    assert.ok(inner._statusBarItem.tooltip.length > 0, 'a dropped batch needs an explanation');
    controller.dispose();
  });

  it('still reports the drop when the same batch also runs a scan', () => {
    // Regression pin: `_dropOversizedOpenBatch` writes "scan skipped" to the status bar, and
    // `_beginScan` overwrote it microseconds later whenever the same queued batch also held a
    // saved file. The drop was then invisible, which defeats the point of surfacing it. The
    // count now rides through to the terminal post-scan line instead.
    const controller = makeController([]);
    const inner = controller as unknown as ControllerInternals & {
      _statusBarItem: { text: string; tooltip: string };
      _reportScanSuccess: (files: string[], diags: unknown[], startMs: number) => void;
    };
    inner._scan = async (_root, files) => {
      // Stands in for _beginScan, whose "scanning ..." text is what buried the drop notice.
      // _beginScan itself is not called here because it needs a real CancellationTokenSource,
      // which the vscode mock does not provide.
      inner._statusBarItem.text = 'Saropa: scanning';
      inner._statusBarItem.tooltip = 'Saropa: scanning';
      inner._reportScanSuccess(files, [], Date.now());
    };
    const opened = seedQueue(inner, 201, 'open', '/proj/lib/opened');
    inner._pendingFiles.set('/proj/lib/saved.dart', 'save');
    withVisibleEditors(opened, () => inner._runQueuedScan('/proj'));
    assert.ok(
      inner._statusBarItem.text.includes('201'),
      `post-scan status must still name the dropped count, got: ${inner._statusBarItem.text}`,
    );
    assert.ok(
      inner._statusBarItem.tooltip.includes('201'),
      `post-scan tooltip must explain the drop, got: ${inner._statusBarItem.tooltip}`,
    );
    controller.dispose();
  });

  it('announces a drop only once, not again on the next unrelated scan', () => {
    // The carry-forward count must be consumed, or every later scan would keep re-reporting a
    // drop the user was already told about.
    const controller = makeController([]);
    const inner = controller as unknown as ControllerInternals & {
      _statusBarItem: { text: string; tooltip: string };
      _reportScanSuccess: (files: string[], diags: unknown[], startMs: number) => void;
    };
    inner._scan = async (_root, files) => {
      inner._statusBarItem.text = 'Saropa: scanning';
      inner._statusBarItem.tooltip = 'Saropa: scanning';
      inner._reportScanSuccess(files, [], Date.now());
    };
    const opened = seedQueue(inner, 201, 'open', '/proj/lib/opened');
    inner._pendingFiles.set('/proj/lib/saved.dart', 'save');
    withVisibleEditors(opened, () => inner._runQueuedScan('/proj'));
    inner._pendingFiles.set('/proj/lib/saved2.dart', 'save');
    inner._runQueuedScan('/proj');
    assert.ok(
      !inner._statusBarItem.text.includes('201'),
      `a consumed drop must not be re-announced, got: ${inner._statusBarItem.text}`,
    );
    controller.dispose();
  });

  it('does not queue-gate opens — the gate runs at scan time', () => {
    // A document open event must reach the queue even though the mock window
    // reports no tabs; queue-time gating would race tab registration.
    const controller = makeController([]);
    const inner = controller as unknown as ControllerInternals & {
      _queueIfDart: (doc: unknown) => void;
    };
    inner._queueIfDart({
      languageId: 'dart',
      uri: { fsPath: '/proj/lib/opened.dart' },
    });
    assert.strictEqual(inner._pendingFiles.get('/proj/lib/opened.dart'), 'open');
    controller.dispose();
  });

  it('does not downgrade a saved file to open provenance', () => {
    const controller = makeController([]);
    const inner = controller as unknown as ControllerInternals & {
      _queueIfDart: (doc: unknown) => void;
    };
    inner._pendingFiles.set('/proj/lib/a.dart', 'save');
    inner._queueIfDart({ languageId: 'dart', uri: { fsPath: '/proj/lib/a.dart' } });
    assert.strictEqual(inner._pendingFiles.get('/proj/lib/a.dart'), 'save');
    controller.dispose();
  });
});

describe('ScanOnSaveController scan supersession', () => {
  /** Wires an in-flight scan over [inFlight] with a recording cancel source. */
  function armInFlight(controller: ScanOnSaveController, inFlight: string[]): { canceled: boolean } {
    const state = { canceled: false };
    const inner = controller as unknown as {
      _scanInFlight: boolean;
      _inFlightFiles: readonly string[];
      _scanCancelSource: { cancel: () => void; dispose: () => void } | undefined;
    };
    inner._scanInFlight = true;
    inner._inFlightFiles = inFlight;
    // Stub stands in for a CancellationTokenSource: the mock vscode module
    // does not provide one, and only cancel/dispose are exercised here.
    inner._scanCancelSource = {
      cancel: () => { state.canceled = true; },
      dispose: () => { /* no-op */ },
    };
    return state;
  }

  it('cancels the running scan when the new batch covers all of its files', () => {
    const controller = makeController([]);
    const state = armInFlight(controller, ['/proj/lib/a.dart']);
    const inner = controller as unknown as {
      _pendingFiles: Map<string, string>;
      _runQueuedScan: (root: string) => void;
    };
    inner._pendingFiles.set('/proj/lib/a.dart', 'save');
    inner._pendingFiles.set('/proj/lib/b.dart', 'save');
    inner._runQueuedScan('/proj');
    assert.strictEqual(state.canceled, true, 'stale scan should have been canceled');
    controller.dispose();
  });

  it('leaves a partially overlapping scan running so its extra files still report', () => {
    const controller = makeController([]);
    const state = armInFlight(controller, ['/proj/lib/a.dart', '/proj/lib/c.dart']);
    const inner = controller as unknown as {
      _pendingFiles: Map<string, string>;
      _runQueuedScan: (root: string) => void;
    };
    inner._pendingFiles.set('/proj/lib/a.dart', 'save');
    inner._runQueuedScan('/proj');
    assert.strictEqual(state.canceled, false, 'partially overlapping scan must keep running');
    controller.dispose();
  });
});

/**
 * Gate O decides whether a file gets diagnostics, and it decides using the
 * URIs pulled off open tabs. The pre-fix extraction read only a top-level
 * `uri`, which every comparison tab shape lacks — so a Dart file open as the
 * modified side of a diff read as "not open" and silently lost its
 * diagnostics. These cases pin each union member's real property names.
 */
describe('tabInputUriPaths', () => {
  /** Minimal Uri stand-in — only `fsPath` is read. */
  const uri = (fsPath: string): { fsPath: string } => ({ fsPath });

  it('reads the plain uri of a text, notebook, or custom tab', () => {
    assert.deepStrictEqual(tabInputUriPaths({ uri: uri('/proj/a.dart') }), ['/proj/a.dart']);
  });

  it('reads BOTH sides of a diff tab (original + modified)', () => {
    // The regression case: only `modified` is the file the user is editing,
    // and it is never exposed as `uri`.
    const input = { original: uri('/proj/old.dart'), modified: uri('/proj/new.dart') };
    assert.deepStrictEqual(tabInputUriPaths(input), ['/proj/old.dart', '/proj/new.dart']);
  });

  it('reads every side of a merge tab (base, input1, input2, result)', () => {
    const input = {
      base: uri('/proj/base.dart'),
      input1: uri('/proj/ours.dart'),
      input2: uri('/proj/theirs.dart'),
      result: uri('/proj/merged.dart'),
    };
    assert.deepStrictEqual(tabInputUriPaths(input), [
      '/proj/base.dart',
      '/proj/ours.dart',
      '/proj/theirs.dart',
      '/proj/merged.dart',
    ]);
  });

  it('a diff tab makes its modified file count as open for Gate O', () => {
    const tabs = tabInputUriPaths({
      original: uri('/proj/old.dart'),
      modified: uri('/proj/new.dart'),
    });
    assert.strictEqual(isDocumentUserOpen('/proj/new.dart', [], tabs), true);
  });

  it('contributes nothing for a webview or terminal tab that carries no uri', () => {
    assert.deepStrictEqual(tabInputUriPaths({ viewType: 'markdown.preview' }), []);
  });

  it('degrades quietly for null, primitives, and future unknown shapes', () => {
    // Runs inside a save handler, where a throw would be swallowed and the
    // whole batch lost — an unrecognized member must simply contribute nothing.
    assert.deepStrictEqual(tabInputUriPaths(undefined), []);
    assert.deepStrictEqual(tabInputUriPaths(null), []);
    assert.deepStrictEqual(tabInputUriPaths('not-an-object'), []);
    assert.deepStrictEqual(tabInputUriPaths({ uri: 'a-string-not-a-uri' }), []);
    assert.deepStrictEqual(tabInputUriPaths({ uri: { fsPath: '' } }), []);
  });
});
