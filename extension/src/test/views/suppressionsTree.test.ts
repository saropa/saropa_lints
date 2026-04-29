import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as sinon from 'sinon';
import { SuppressionsTreeProvider } from '../../views/suppressionsTree';
import * as projectRoot from '../../projectRoot';
import * as violationsReader from '../../violationsReader';
import * as configWriter from '../../configWriter';

/** Suppressions tree: disabled rules and inline ignores from violations + config. */

describe('SuppressionsTreeProvider', () => {
  beforeEach(() => {
    sinon.stub(projectRoot, 'getProjectRoot').returns('/fake/root');
    sinon.stub(configWriter, 'readDisabledRules').returns(new Set<string>());
    sinon.stub(violationsReader, 'readViolations').returns({
      violations: [],
      summary: {
        totalViolations: 0,
        suppressions: {
          total: 14,
          byKind: { ignore: 8, ignoreForFile: 4, baseline: 2 },
          byRule: { avoid_print: 5, require_https: 3 },
          byFile: { 'lib/app.dart': 7, 'lib/api.dart': 4 },
        },
      },
      config: {},
    });
  });

  afterEach(() => {
    sinon.restore();
  });

  it('shows root aggregates', async () => {
    const provider = new SuppressionsTreeProvider();
    const root = await provider.getChildren();
    assert.deepStrictEqual(root.map((item) => item.label), [
      'Total suppressions',
      'By kind',
      'By rule',
      'By file',
    ]);
    assert.strictEqual(root[0]?.description, '14');
  });

  it('shows by-rule and by-file entries with commands', async () => {
    const provider = new SuppressionsTreeProvider();

    const byRule = await provider.getChildren({ label: 'By rule', nodeId: 'byRule' } as never);
    assert.strictEqual(byRule[0]?.label, 'avoid_print');
    assert.strictEqual(byRule[0]?.description, '5');
    assert.strictEqual(byRule[0]?.command?.command, 'saropaLints.focusIssuesForRules');
    assert.deepStrictEqual(byRule[0]?.command?.arguments, [['avoid_print']]);

    const byFile = await provider.getChildren({ label: 'By file', nodeId: 'byFile' } as never);
    assert.strictEqual(byFile[0]?.label, 'lib/app.dart');
    assert.strictEqual(byFile[0]?.description, '7');
    assert.strictEqual(byFile[0]?.command?.command, 'saropaLints.openFileAndFocusIssues');
    assert.deepStrictEqual(byFile[0]?.command?.arguments, ['lib/app.dart']);
  });
});
