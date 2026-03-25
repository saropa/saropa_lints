import * as assert from 'node:assert';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import {
  normalizePath,
  cachedFileExists,
  clearFileExistsCache,
} from '../pathUtils';

describe('normalizePath', () => {
  it('converts backslashes to forward slashes', () => {
    assert.strictEqual(normalizePath('a\\b\\c'), 'a/b/c');
  });

  it('leaves forward slashes unchanged', () => {
    assert.strictEqual(normalizePath('a/b/c'), 'a/b/c');
  });

  it('handles empty string', () => {
    assert.strictEqual(normalizePath(''), '');
  });
});

describe('cachedFileExists', () => {
  let tmpDir: string;
  let existingFile: string;
  const nonExistentFile = path.join(os.tmpdir(), 'saropa_test_DOES_NOT_EXIST_12345.txt');

  before(() => {
    // Create a real temp file for existence checks.
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-pathutils-'));
    existingFile = path.join(tmpDir, 'exists.txt');
    fs.writeFileSync(existingFile, 'test');
  });

  after(() => {
    // Clean up temp file and directory.
    fs.unlinkSync(existingFile);
    fs.rmdirSync(tmpDir);
  });

  beforeEach(() => {
    clearFileExistsCache();
  });

  it('returns true for a file that exists', () => {
    assert.strictEqual(cachedFileExists(existingFile), true);
  });

  it('returns false for a file that does not exist', () => {
    assert.strictEqual(cachedFileExists(nonExistentFile), false);
  });

  it('returns cached result on second call (no disk I/O)', () => {
    // First call populates cache.
    cachedFileExists(existingFile);
    // Delete the file — cached result should still say "exists".
    fs.unlinkSync(existingFile);
    try {
      // Second call should return cached true even though file is gone.
      assert.strictEqual(cachedFileExists(existingFile), true);
    } finally {
      // Restore the file for cleanup in after().
      fs.writeFileSync(existingFile, 'test');
    }
  });

  it('normalizes backslash and forward-slash paths to the same cache key', () => {
    // Use a path that exists regardless of slash direction.
    const fwd = existingFile.replace(/\\/g, '/');
    const bck = existingFile.replace(/\//g, '\\');
    cachedFileExists(fwd);
    cachedFileExists(bck);
    // Both should resolve to true (same file) and share a cache entry.
    assert.strictEqual(cachedFileExists(fwd), true);
    assert.strictEqual(cachedFileExists(bck), true);
  });

  it('clearFileExistsCache resets cached results', () => {
    cachedFileExists(existingFile);
    // Delete file, clear cache, check again — should now see false.
    fs.unlinkSync(existingFile);
    try {
      clearFileExistsCache();
      assert.strictEqual(cachedFileExists(existingFile), false);
    } finally {
      fs.writeFileSync(existingFile, 'test');
    }
  });
});
