import * as assert from 'node:assert';
import { createRelatedRuleTelemetry } from '../../relatedRuleTelemetry';

class MockMemento {
  private readonly store = new Map<string, unknown>();

  get<T>(key: string, defaultValue?: T): T | undefined {
    return this.store.has(key) ? (this.store.get(key) as T) : defaultValue;
  }

  async update(key: string, value: unknown): Promise<void> {
    this.store.set(key, value);
  }
}

describe('relatedRuleTelemetry', () => {
  it('increments per-event counters', async () => {
    const state = new MockMemento();
    const telemetry = createRelatedRuleTelemetry(state as never);

    telemetry.track('ruleExplain.open', { ruleName: 'avoid_hardcoded_credentials' });
    telemetry.track('ruleExplain.open', { ruleName: 'avoid_hardcoded_credentials' });
    telemetry.track('ruleExplain.relatedClick', {
      sourceRule: 'avoid_hardcoded_credentials',
      targetRule: 'require_secure_storage',
    });

    await Promise.resolve();

    const stored = state.get<{ counters?: Record<string, number> }>(
      'saropaLints.relatedRuleTelemetry.v1',
    );
    assert.ok(stored, 'telemetry store should exist');
    assert.strictEqual(stored?.counters?.['ruleExplain.open'], 2);
    assert.strictEqual(stored?.counters?.['ruleExplain.relatedClick'], 1);
  });

  it('supports snapshot and reset', async () => {
    const state = new MockMemento();
    const telemetry = createRelatedRuleTelemetry(state as never);

    telemetry.track('suggestions.relatedRuleOpen', {
      sourceRule: 'require_dispose_implementation',
      ruleName: 'require_stream_controller_dispose',
    });

    const before = telemetry.snapshot();
    assert.strictEqual(before.counters['suggestions.relatedRuleOpen'], 1);

    telemetry.reset();
    await Promise.resolve();

    const after = telemetry.snapshot();
    assert.strictEqual(after.counters['suggestions.relatedRuleOpen'] ?? 0, 0);
  });
});
