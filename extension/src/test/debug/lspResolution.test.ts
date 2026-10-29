/**
 * isSaropaLintsResolved gates the LSP spawn: without saropa_lints in
 * .dart_tool/package_config.json, `dart run saropa_lints:lsp_server` exits 255.
 */
import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { isSaropaLintsResolved } from '../../debug/lspResolution';

describe('isSaropaLintsResolved', () => {
  let root: string;

  beforeEach(() => {
    root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-lsp-'));
  });

  afterEach(() => {
    fs.rmSync(root, { recursive: true, force: true });
  });

  function writeConfig(content: string): void {
    fs.mkdirSync(path.join(root, '.dart_tool'), { recursive: true });
    fs.writeFileSync(path.join(root, '.dart_tool', 'package_config.json'), content);
  }

  it('is false when package_config.json is missing', () => {
    assert.strictEqual(isSaropaLintsResolved(root), false);
  });

  it('is false when the file is malformed', () => {
    writeConfig('{not json');
    assert.strictEqual(isSaropaLintsResolved(root), false);
  });

  it('is false when saropa_lints is not listed', () => {
    writeConfig(JSON.stringify({ packages: [{ name: 'other' }] }));
    assert.strictEqual(isSaropaLintsResolved(root), false);
  });

  it('is true when saropa_lints is listed', () => {
    writeConfig(JSON.stringify({ packages: [{ name: 'other' }, { name: 'saropa_lints' }] }));
    assert.strictEqual(isSaropaLintsResolved(root), true);
  });
});
