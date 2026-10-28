import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { atomicWrite } from '../../compat/atomicWrite';
import { createLatestRequest } from '../../compat/latestRequest';

describe('atomicWrite', () => {
  it('replaces the file and leaves no temp file', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'aw-'));
    try {
      const f = path.join(dir, 'a.yaml');
      fs.writeFileSync(f, 'old');
      atomicWrite(f, 'new');
      assert.strictEqual(fs.readFileSync(f, 'utf8'), 'new');
      assert.deepStrictEqual(fs.readdirSync(dir), ['a.yaml']);
    } finally {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  });

  it('keeps the original and cleans up when the rename fails', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'aw-'));
    try {
      const target = path.join(dir, 'isdir');
      fs.mkdirSync(target);
      assert.throws(() => atomicWrite(target, 'x'));
      assert.deepStrictEqual(fs.readdirSync(dir), ['isdir']);
    } finally {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  });
});

describe('createLatestRequest', () => {
  it('only the newest request is current', () => {
    const r = createLatestRequest();
    const a = r.begin();
    const b = r.begin();
    assert.strictEqual(r.isCurrent(a), false);
    assert.strictEqual(r.isCurrent(b), true);
  });
});
