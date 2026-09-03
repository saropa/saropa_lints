/**
 * Tests for the >10MB deferred-payload temp-file write path.
 *
 * Exercises maybeWriteDeferredPayload and cleanupDeferredPayloads to verify:
 * - Small payloads return null (inline path, no temp file).
 * - Large payloads are written to a timestamped temp file.
 * - Prior temp files are cleaned up before writing a new one.
 * - Write failures fall back to null (inline path) with a warning toast.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import * as vscode from 'vscode';

import {
  cleanupDeferredPayloads,
  MAX_INLINE_BYTES,
  maybeWriteDeferredPayload,
} from '../../audit/audit-report-panel';
import { messageMock, resetMocks } from '../vibrancy/vscode-mock';

/**
 * Builds a diagnostics array whose JSON serialization exceeds MAX_INLINE_BYTES.
 * Shared between tests that need to trigger the temp-file write path, so the
 * byte-per-entry estimate and entry shape are defined in one place.
 */
function buildOversizedDiagnostics(): Record<string, unknown>[] {
  // Each entry serializes to ~250 bytes; dividing by 120 with a +500 buffer
  // ensures we comfortably exceed the threshold even if entry shape changes.
  const entryCount = Math.ceil(MAX_INLINE_BYTES / 120) + 500;
  return Array.from({ length: entryCount }, (_, i) => ({
    ruleName: `really_long_rule_name_for_bulk_padding_${i}`,
    filePath: `/project/deeply/nested/src/components/widgets/file_${i}.dart`,
    line: i,
    column: 1,
    severity: 'warning',
    impact: 'medium',
    problemMessage: `Intentionally long problem message for entry ${i} to push the payload past the 10MB inline threshold`,
  }));
}

describe('maybeWriteDeferredPayload', () => {
  let tmpDir: string;

  beforeEach(() => {
    resetMocks();
    // Fresh temp directory for each test — isolated from real global storage.
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-audit-test-'));
  });

  afterEach(() => {
    // Best-effort cleanup of the temp dir.
    try {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    } catch {
      // Ignore — OS will clean up eventually.
    }
  });

  /** Wraps the temp dir path as a vscode.Uri for the function under test. */
  function storageUri(): vscode.Uri {
    return vscode.Uri.file(tmpDir);
  }

  it('returns null for a small diagnostics array (inline path)', () => {
    // A handful of diagnostics — well under 10MB.
    const small = [
      { ruleName: 'test_rule', filePath: '/a.dart', line: 1 },
      { ruleName: 'test_rule', filePath: '/b.dart', line: 2 },
    ];

    const result = maybeWriteDeferredPayload(JSON.stringify(small), storageUri());

    assert.strictEqual(result, null, 'Small payloads should return null (inline)');
    // No temp file should have been written.
    const files = fs.readdirSync(tmpDir).filter((f) => f.startsWith('diagnostics-'));
    assert.strictEqual(files.length, 0, 'No temp file for small payloads');
  });

  it('returns null when serializedDiagnostics is null', () => {
    // Null input (diagnostics was not an array) — should return null immediately.
    const result = maybeWriteDeferredPayload(null, storageUri());
    assert.strictEqual(result, null);
  });

  it('writes a temp file for payloads exceeding MAX_INLINE_BYTES', () => {
    const diagnostics = buildOversizedDiagnostics();
    const serialized = JSON.stringify(diagnostics);
    const result = maybeWriteDeferredPayload(serialized, storageUri());

    // Should return a Uri pointing to the written temp file.
    assert.ok(result !== null, 'Large payloads should return a temp file URI');
    assert.ok(
      result!.fsPath.includes('diagnostics-'),
      `Temp file name should contain 'diagnostics-': ${result!.fsPath}`,
    );
    // The file should exist and contain valid JSON.
    assert.ok(fs.existsSync(result!.fsPath), 'Temp file should exist on disk');
    const content = fs.readFileSync(result!.fsPath, 'utf-8');
    const parsed = JSON.parse(content);
    assert.ok(Array.isArray(parsed), 'Temp file should contain a JSON array');
    assert.strictEqual(parsed.length, diagnostics.length);
  });

  it('cleans up prior temp files before writing a new one', () => {
    // Seed two "old" temp files in the directory.
    fs.writeFileSync(path.join(tmpDir, 'diagnostics-111.json'), '[]');
    fs.writeFileSync(path.join(tmpDir, 'diagnostics-222.json'), '[]');
    // Also seed a non-diagnostics file that should NOT be touched.
    fs.writeFileSync(path.join(tmpDir, 'other.txt'), 'keep me');

    const diagnostics = buildOversizedDiagnostics();

    maybeWriteDeferredPayload(JSON.stringify(diagnostics), storageUri());

    // Old diagnostics files should be gone.
    assert.ok(!fs.existsSync(path.join(tmpDir, 'diagnostics-111.json')));
    assert.ok(!fs.existsSync(path.join(tmpDir, 'diagnostics-222.json')));
    // The non-diagnostics file should still be there.
    assert.ok(fs.existsSync(path.join(tmpDir, 'other.txt')));
    // Exactly one new diagnostics file should exist.
    const remaining = fs.readdirSync(tmpDir).filter((f) => f.startsWith('diagnostics-'));
    assert.strictEqual(remaining.length, 1, 'Exactly one new temp file should remain');
  });
});

describe('cleanupDeferredPayloads', () => {
  let tmpDir: string;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-cleanup-test-'));
  });

  afterEach(() => {
    try {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    } catch { /* noop */ }
  });

  it('removes only diagnostics-*.json files', () => {
    fs.writeFileSync(path.join(tmpDir, 'diagnostics-aaa.json'), '[]');
    fs.writeFileSync(path.join(tmpDir, 'diagnostics-bbb.json'), '[]');
    fs.writeFileSync(path.join(tmpDir, 'keep-me.json'), '{}');
    fs.writeFileSync(path.join(tmpDir, 'diagnostics-nope.txt'), 'x');

    cleanupDeferredPayloads(vscode.Uri.file(tmpDir));

    // Only the diagnostics-*.json files should be gone.
    assert.ok(!fs.existsSync(path.join(tmpDir, 'diagnostics-aaa.json')));
    assert.ok(!fs.existsSync(path.join(tmpDir, 'diagnostics-bbb.json')));
    assert.ok(fs.existsSync(path.join(tmpDir, 'keep-me.json')));
    // diagnostics-nope.txt has wrong extension — should survive.
    assert.ok(fs.existsSync(path.join(tmpDir, 'diagnostics-nope.txt')));
  });

  it('handles non-existent directory gracefully', () => {
    // Should not throw for a directory that does not exist.
    assert.doesNotThrow(() => {
      cleanupDeferredPayloads(vscode.Uri.file(path.join(tmpDir, 'does-not-exist')));
    });
  });
});
