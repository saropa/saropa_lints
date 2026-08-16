import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import {
  toVscodeDiagnostic,
  groupDiagnosticsByFile,
  scanOnSaveIsEnabled,
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
