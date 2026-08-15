/**
 * Tests for the scan-daemon client's pure pieces: NDJSON line buffering,
 * daemon-response → ScanOnSaveResult mapping, and the manager's respawn
 * backoff curve. The process-spawning paths are exercised by the manual
 * Extension Development Host smoke test, not here — spawning a real dart
 * daemon in unit tests would need a full analyzer warmup per run.
 */
import '../vibrancy/register-vscode-mock'; // devCliRoot imports 'vscode'; must be mocked before the module graph loads.

import * as assert from 'node:assert';
import {
  splitNdjsonBuffer,
  daemonResponseToResult,
  daemonResponseToFileList,
} from '../../scanOnSave/scanDaemonClient';
import { respawnBackoffMs, RESPAWN_BACKOFF_MAX_MS } from '../../scanOnSave/scanDaemonManager';

describe('splitNdjsonBuffer', () => {
  it('returns complete lines and keeps the trailing partial as rest', () => {
    const { lines, rest } = splitNdjsonBuffer('{"id":"1"}\n{"id":"2"}\n{"id":"3');
    assert.deepStrictEqual(lines, ['{"id":"1"}', '{"id":"2"}']);
    assert.strictEqual(rest, '{"id":"3');
  });

  it('returns no lines when the buffer holds only a partial line', () => {
    const { lines, rest } = splitNdjsonBuffer('{"event":"rea');
    assert.deepStrictEqual(lines, []);
    assert.strictEqual(rest, '{"event":"rea');
  });

  it('drops blank lines (daemon may emit \\r\\n on Windows)', () => {
    const { lines, rest } = splitNdjsonBuffer('{"id":"1"}\r\n\n{"id":"2"}\r\n');
    assert.deepStrictEqual(lines, ['{"id":"1"}', '{"id":"2"}']);
    assert.strictEqual(rest, '');
  });
});

describe('daemonResponseToResult', () => {
  it('maps an ok response with diagnostics onto a payload result', () => {
    const result = daemonResponseToResult({
      id: '1',
      ok: true,
      version: 1,
      diagnostics: [{ filePath: '/a.dart', line: 1, column: 1, ruleName: 'r', severity: 'INFO' }],
    });
    assert.strictEqual(result.exitCode, 0);
    assert.strictEqual(result.payload?.diagnostics.length, 1);
    assert.strictEqual(result.errorMessage, undefined);
  });

  it('maps an ok response with zero diagnostics onto a clean payload (not an error)', () => {
    const result = daemonResponseToResult({ id: '1', ok: true, diagnostics: [] });
    assert.strictEqual(result.payload?.diagnostics.length, 0);
  });

  it('maps an error response onto payload:null with the daemon message', () => {
    const result = daemonResponseToResult({ id: '1', ok: false, error: 'No configuration found' });
    assert.strictEqual(result.payload, null);
    assert.strictEqual(result.errorMessage, 'No configuration found');
  });

  it('treats ok:true WITHOUT a diagnostics array as an error, not a clean scan', () => {
    const result = daemonResponseToResult({ id: '1', ok: true });
    assert.strictEqual(result.payload, null);
    assert.ok(result.errorMessage);
  });
});

describe('daemonResponseToFileList', () => {
  it('maps an ok response with a files array onto the string list', () => {
    const files = daemonResponseToFileList({ id: '1', ok: true, files: ['/a.dart', '/b.dart'] });
    assert.deepStrictEqual(files, ['/a.dart', '/b.dart']);
  });

  it('drops non-string entries rather than failing the whole list', () => {
    const files = daemonResponseToFileList({ id: '1', ok: true, files: ['/a.dart', 42, null] });
    assert.deepStrictEqual(files, ['/a.dart']);
  });

  it('returns null on an error response', () => {
    assert.strictEqual(daemonResponseToFileList({ id: '1', ok: false, error: 'boom' }), null);
  });

  it('returns null when ok:true but files is missing or not an array', () => {
    assert.strictEqual(daemonResponseToFileList({ id: '1', ok: true }), null);
  });
});

describe('respawnBackoffMs', () => {
  it('is zero with no failures', () => {
    assert.strictEqual(respawnBackoffMs(0), 0);
  });

  it('doubles per consecutive failure: 1s, 2s, 4s', () => {
    assert.strictEqual(respawnBackoffMs(1), 1_000);
    assert.strictEqual(respawnBackoffMs(2), 2_000);
    assert.strictEqual(respawnBackoffMs(3), 4_000);
  });

  it('caps at the maximum so a persistently broken daemon retries every 30s', () => {
    assert.strictEqual(respawnBackoffMs(20), RESPAWN_BACKOFF_MAX_MS);
  });
});
