import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as sinon from 'sinon';
import { SummaryTreeProvider } from '../../views/summaryTree';
import * as projectRoot from '../../projectRoot';
import * as violationsReader from '../../violationsReader';
import * as configWriter from '../../configWriter';

class MockMemento {
  private readonly store = new Map<string, unknown>();

  get<T>(key: string, defaultValue?: T): T | undefined {
    return this.store.has(key) ? (this.store.get(key) as T) : defaultValue;
  }

  async update(key: string, value: unknown): Promise<void> {
    this.store.set(key, value);
  }
}

describe('SummaryTreeProvider suppressions section', () => {
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

  it('shows suppressions root row with compact breakdown', async () => {
    const provider = new SummaryTreeProvider(new MockMemento() as never);
    const root = await provider.getChildren();
    const sup = root.find((item) => item.nodeId === 'suppressions');
    assert.ok(sup);
    assert.strictEqual(sup?.label, 'Suppressions');
    assert.strictEqual(sup?.description, '8 ignore, 4 file-level, 2 baseline');
  });

  it('expands suppressions into by-kind/by-rule/by-file groups', async () => {
    const provider = new SummaryTreeProvider(new MockMemento() as never);
    const groups = await provider.getChildren(
      {
        label: 'Suppressions',
        nodeId: 'suppressions',
      } as never,
    );
    assert.deepStrictEqual(
      groups.map((item) => item.label),
      ['By kind', 'By rule', 'By file'],
    );
  });

  it('builds by-rule and by-file entries with navigation commands', async () => {
    const provider = new SummaryTreeProvider(new MockMemento() as never);

    const byRule = await provider.getChildren(
      {
        label: 'By rule',
        nodeId: 'suppressionsByRule',
      } as never,
    );
    assert.strictEqual(byRule[0]?.label, 'avoid_print');
    assert.strictEqual(byRule[0]?.description, '5');
    assert.strictEqual(byRule[0]?.command?.command, 'saropaLints.focusIssuesForRules');
    assert.deepStrictEqual(byRule[0]?.command?.arguments, [['avoid_print']]);

    const byFile = await provider.getChildren(
      {
        label: 'By file',
        nodeId: 'suppressionsByFile',
      } as never,
    );
    assert.strictEqual(byFile[0]?.label, 'lib/app.dart');
    assert.strictEqual(byFile[0]?.description, '7');
    assert.strictEqual(byFile[0]?.command?.command, 'saropaLints.openFileAndFocusIssues');
    assert.deepStrictEqual(byFile[0]?.command?.arguments, ['lib/app.dart']);
  });
});
