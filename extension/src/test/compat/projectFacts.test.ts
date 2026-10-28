import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { disablePluginsIntegration } from '../../setup';
import {
  isWorkspaceMember,
  parseDartVersion,
  parseFlutterVersion,
  parseLockedVersion,
  parsePluginVersion,
  pubspecDeclaresSaropaLints,
  readProjectFacts,
} from '../../compat/projectFacts';

const LOCK = [
  'packages:',
  '  analyzer:',
  '    dependency: transitive',
  '    description:',
  '      name: analyzer',
  '    source: hosted',
  '    version: "12.1.0"',
  '  meta:',
  '    dependency: transitive',
  '    source: hosted',
  '    version: "1.17.0"',
  '  saropa_lints:',
  '    dependency: "direct dev"',
  '    source: hosted',
  '    version: "16.10.0"',
  'sdks:',
  '  dart: ">=3.9.0 <4.0.0"',
].join('\n');

const OPTIONS = [
  'analyzer:',
  '  exclude: []',
  'plugins:',
  '  saropa_lints:',
  '    version: "16.10.0"',
  '    diagnostics:',
  '      foo: true',
].join('\n');

function tmp(): string {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'pfacts-'));
}
function write(root: string, rel: string, text: string): void {
  const f = path.join(root, rel);
  fs.mkdirSync(path.dirname(f), { recursive: true });
  fs.writeFileSync(f, text);
}
const crlf = (s: string): string => s.replace(/\n/g, '\r\n');
const noFlutter = async (): Promise<string | null> => null;

describe('projectFacts parsers', () => {
  it('parses Dart version', () => {
    assert.strictEqual(parseDartVersion('{"generatorVersion":"3.9.2"}'), '3.9.2');
    assert.strictEqual(parseDartVersion('not json'), undefined);
    assert.strictEqual(parseDartVersion('{}'), undefined);
  });

  it('parses Flutter version with CRLF and blank file', () => {
    assert.strictEqual(parseFlutterVersion('3.44.1\r\n'), '3.44.1');
    assert.strictEqual(parseFlutterVersion('\n'), undefined);
    assert.strictEqual(parseFlutterVersion('garbage'), undefined);
  });

  it('parses locked versions, LF and CRLF', () => {
    for (const lock of [LOCK, crlf(LOCK)]) {
      assert.strictEqual(parseLockedVersion(lock, 'analyzer'), '12.1.0');
      assert.strictEqual(parseLockedVersion(lock, 'meta'), '1.17.0');
      assert.strictEqual(parseLockedVersion(lock, 'missing'), undefined);
    }
  });

  it('detects workspace membership', () => {
    assert.strictEqual(isWorkspaceMember('name: a\nresolution: workspace\n'), true);
    assert.strictEqual(isWorkspaceMember(crlf('name: a\nresolution: workspace\n')), true);
    assert.strictEqual(isWorkspaceMember('name: a\n'), false);
  });

  it('detects saropa_lints in pubspec deps only', () => {
    assert.strictEqual(
      pubspecDeclaresSaropaLints('dev_dependencies:\n  saropa_lints: ^16.0.0\n'), true);
    assert.strictEqual(
      pubspecDeclaresSaropaLints(crlf('dependencies:\n  saropa_lints:\n    path: ../x\n')), true);
    assert.strictEqual(
      pubspecDeclaresSaropaLints('dependency_overrides:\n  saropa_lints: any\n'), false);
    assert.strictEqual(pubspecDeclaresSaropaLints('name: x\n'), false);
  });

  it('parses plugin version in nested, shorthand, CRLF forms', () => {
    assert.strictEqual(parsePluginVersion(OPTIONS), '16.10.0');
    assert.strictEqual(parsePluginVersion(crlf(OPTIONS)), '16.10.0');
    assert.strictEqual(parsePluginVersion('plugins:\n  saropa_lints: 16.9.0\n'), '16.9.0');
    assert.strictEqual(parsePluginVersion('plugins:\n  saropa_lints:\n    path: ../x\n'), undefined);
    assert.strictEqual(parsePluginVersion('analyzer:\n  exclude: []\n'), undefined);
  });

  it('ignores a commented-out plugins block', () => {
    const commented = OPTIONS.split('\n').map((l) => `# ${l}`).join('\n');
    assert.strictEqual(parsePluginVersion(commented), undefined);
  });
});

describe('readProjectFacts', () => {
  it('returns empty facts for a bare directory', async () => {
    const f = await readProjectFacts(tmp(), noFlutter);
    assert.deepStrictEqual(f, { locked: {}, inPubspec: false, pluginBlockDisabled: false });
  });

  it('reads a full project (CRLF)', async () => {
    const root = tmp();
    write(root, 'pubspec.yaml', crlf('name: app\ndev_dependencies:\n  saropa_lints: ^16.10.0\n'));
    write(root, 'pubspec.lock', crlf(LOCK));
    write(root, '.dart_tool/package_config.json', '{"generatorVersion":"3.9.2"}');
    write(root, '.dart_tool/version', '3.35.0\r\n');
    write(root, 'analysis_options.yaml', crlf(OPTIONS));
    const f = await readProjectFacts(root, noFlutter);
    assert.strictEqual(f.dartVersion, '3.9.2');
    assert.strictEqual(f.flutterVersion, '3.35.0');
    assert.strictEqual(f.flutterMetaPin, undefined);
    assert.deepStrictEqual(f.locked, {
      saropaLints: { version: '16.10.0', source: 'hosted' },
      analyzer: '12.1.0',
      meta: '1.17.0',
    });
    assert.strictEqual(f.inPubspec, true);
    assert.strictEqual(f.pluginVersion, '16.10.0');
    assert.strictEqual(f.pluginBlockDisabled, false);
    assert.strictEqual(f.workspaceRoot, undefined);
  });

  it('derives the Flutter meta pin from an injected SDK root', async () => {
    const root = tmp();
    const sdk = tmp();
    write(sdk, 'packages/flutter/pubspec.yaml', 'name: flutter\ndependencies:\n  meta: 1.16.0\n');
    write(root, '.dart_tool/version', '3.35.0\n');
    const f = await readProjectFacts(root, async () => sdk);
    assert.strictEqual(f.flutterMetaPin, '1.16.0');
  });

  it('flags a disabled plugins block', async () => {
    const root = tmp();
    write(root, 'analysis_options.yaml', OPTIONS + '\n');
    disablePluginsIntegration(root);
    const f = await readProjectFacts(root, noFlutter);
    assert.strictEqual(f.pluginBlockDisabled, true);
    assert.strictEqual(f.pluginVersion, undefined);
  });

  it('reads lock and dart data from the workspace root for a member', async () => {
    const ws = tmp();
    const member = path.join(ws, 'packages', 'a');
    write(ws, 'pubspec.yaml', 'name: ws\nworkspace:\n  - packages/a\n');
    write(ws, 'pubspec.lock', LOCK);
    write(ws, '.dart_tool/package_config.json', '{"generatorVersion":"3.10.0"}');
    write(member, 'pubspec.yaml',
      'name: a\nresolution: workspace\ndev_dependencies:\n  saropa_lints: ^16.0.0\n');
    const f = await readProjectFacts(member, noFlutter);
    assert.strictEqual(f.workspaceRoot, ws);
    assert.strictEqual(f.dartVersion, '3.10.0');
    assert.strictEqual(f.locked.analyzer, '12.1.0');
    assert.strictEqual(f.inPubspec, true);
  });

  it('tolerates malformed files', async () => {
    const root = tmp();
    write(root, '.dart_tool/package_config.json', '{oops');
    write(root, 'pubspec.lock', '\u0000\u0001');
    const f = await readProjectFacts(root, noFlutter);
    assert.strictEqual(f.dartVersion, undefined);
    assert.deepStrictEqual(f.locked, {});
  });
});
