/** * Module overview (comment coverage pass). * comment-coverage: module overview (batch). * * Extension Jest tests: validates commands, webviews, parsers, and state against VS Code APIs (often with local mocks). */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as sinon from 'sinon';
import { SummaryTreeProvider } from '../../views/summaryTree';
import * as projectRoot from '../../projectRoot';
import * as violationsReader from '../../violationsReader';
import * as configWriter from '../../configWriter';

/** Summary tree nodes for security hotspot review state (mocked memento + reader). */

class MockMemento {
  private readonly store = new Map<string, unknown>();

  get<T>(key: string, defaultValue?: T): T | undefined {
    return this.store.has(key) ? (this.store.get(key) as T) : defaultValue;
  }

  async update(key: string, value: unknown): Promise<void> {
    this.store.set(key, value);
  }
}

describe('SummaryTreeProvider hotspot review counts', () => {
  beforeEach(() => {
    sinon.stub(projectRoot, 'getProjectRoot').returns('/fake/root');
    sinon.stub(configWriter, 'readDisabledRules').returns(new Set<string>());
    sinon.stub(violationsReader, 'readViolations').returns({
      violations: [
        {
          file: 'lib/a.dart',
          line: 10,
          rule: 'hotspot_rule_a',
          message: 'Review this',
          metadata: { ruleType: 'securityHotspot' },
        },
        {
          file: 'lib/a.dart',
          line: 11,
          rule: 'hotspot_rule_b',
          message: 'Also review this',
          metadata: { tags: ['review-required'] },
        },
      ],
      summary: { totalViolations: 2 },
      config: {
        ruleMetadataByRule: {
          hotspot_rule_a: { ruleType: 'securityHotspot' },
          hotspot_rule_b: { tags: ['review-required'] },
        },
      },
    });
  });

  afterEach(() => {
    sinon.restore();
  });

  it('shows hotspot review section with per-state children', async () => {
    const provider = new SummaryTreeProvider(new MockMemento() as never);
    const root = await provider.getChildren();
    const hotspotSection = root.find((item) => item.label === 'Security hotspot review');
    assert.ok(hotspotSection);
    assert.strictEqual(hotspotSection?.description, '0% reviewed — 2 open, 0 safe, 0 fixed');

    const children = await provider.getChildren(hotspotSection);
    const labels = children.map((item) => String(item.label));
    assert.deepStrictEqual(labels, ['Reviewed', 'Open', 'Reviewed Safe', 'Reviewed Fixed']);
    const counts = children.map((item) => item.description);
    assert.deepStrictEqual(counts, ['0', '2', '0', '0']);
  });
});
