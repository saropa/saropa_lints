import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { pathsFor } from '../../compat/compatController';

describe('pathsFor', () => {
  it('uses the workspace root lock for a pub workspace member', () => {
    const ws = fs.mkdtempSync(path.join(os.tmpdir(), 'compat-ws-'));
    const member = path.join(ws, 'packages', 'a');
    fs.mkdirSync(member, { recursive: true });
    fs.writeFileSync(path.join(ws, 'pubspec.yaml'), 'name: ws\nworkspace:\n  - packages/a\n');
    fs.writeFileSync(path.join(member, 'pubspec.yaml'), 'name: a\nresolution: workspace\n');
    const p = pathsFor(member);
    assert.strictEqual(p.lock, path.join(ws, 'pubspec.lock'));
    assert.strictEqual(p.pubspec, path.join(member, 'pubspec.yaml'));
  });

  it('uses the project lock for a standalone project', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'compat-solo-'));
    fs.writeFileSync(path.join(dir, 'pubspec.yaml'), 'name: solo\n');
    assert.strictEqual(pathsFor(dir).lock, path.join(dir, 'pubspec.lock'));
  });
});
