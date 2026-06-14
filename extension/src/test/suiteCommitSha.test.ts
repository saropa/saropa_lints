/**
 * Tests for the commit-SHA resolver (plan requirement R6).
 *
 * Pins the three checkout shapes the exporter must read without spawning git: a
 * normal branch checkout (HEAD → ref → loose SHA), a SHA stored only in
 * packed-refs, and a detached HEAD. Also confirms the resolver never throws on a
 * non-git directory or a malformed HEAD — the SHA is optional in the envelope.
 */

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';

import { resolveCommitSha } from '../suite/commitSha';

const SHA = 'a1b2c3d4e5f60718293a4b5c6d7e8f9012345678';

/** Build a temp repo root with a `.git` dir populated by `files` (relative paths). */
function makeRepo(files: Record<string, string>): string {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-sha-'));
  for (const [rel, body] of Object.entries(files)) {
    const full = path.join(root, '.git', rel);
    fs.mkdirSync(path.dirname(full), { recursive: true });
    fs.writeFileSync(full, body);
  }
  return root;
}

describe('suite/commitSha resolveCommitSha', () => {
  it('resolves HEAD → branch ref → loose SHA', () => {
    const root = makeRepo({
      HEAD: 'ref: refs/heads/main\n',
      'refs/heads/main': `${SHA}\n`,
    });
    assert.strictEqual(resolveCommitSha(root), SHA);
  });

  it('resolves a ref stored only in packed-refs', () => {
    const root = makeRepo({
      HEAD: 'ref: refs/heads/main\n',
      'packed-refs': `# pack-refs with: peeled fully-peeled sorted\n${SHA} refs/heads/main\n`,
    });
    assert.strictEqual(resolveCommitSha(root), SHA);
  });

  it('resolves a detached HEAD (SHA written directly)', () => {
    const root = makeRepo({ HEAD: `${SHA}\n` });
    assert.strictEqual(resolveCommitSha(root), SHA);
  });

  it('returns undefined for a non-git directory', () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), 'saropa-nogit-'));
    assert.strictEqual(resolveCommitSha(root), undefined);
  });

  it('returns undefined for an unborn branch (ref with no SHA yet)', () => {
    const root = makeRepo({ HEAD: 'ref: refs/heads/main\n' });
    assert.strictEqual(resolveCommitSha(root), undefined);
  });

  it('returns undefined for a malformed HEAD', () => {
    const root = makeRepo({ HEAD: 'not a ref or a sha\n' });
    assert.strictEqual(resolveCommitSha(root), undefined);
  });
});
