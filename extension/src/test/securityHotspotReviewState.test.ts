/** * Module overview (comment coverage pass). * comment-coverage: module overview (batch). * * Extension Jest tests: validates commands, webviews, parsers, and state against VS Code APIs (often with local mocks). */
import * as assert from 'node:assert';
import {
  SecurityHotspotReviewStateService,
  defaultSecurityHotspotReviewState,
  isSecurityHotspotViolation,
} from '../securityHotspotReviewState';
import { Violation } from '../violationsReader';

/** Security hotspot review persistence and hotspot classification helpers. */

class MockMemento {
  private readonly store = new Map<string, unknown>();

  get<T>(key: string): T | undefined;
  get<T>(key: string, defaultValue: T): T;
  get<T>(key: string, defaultValue?: T): T | undefined {
    const value = this.store.get(key);
    return value === undefined ? defaultValue : (value as T);
  }

  async update(key: string, value: unknown): Promise<void> {
    this.store.set(key, value);
  }
}

function makeViolation(overrides: Partial<Violation> = {}): Violation {
  return {
    file: 'lib/example.dart',
    line: 10,
    rule: 'example_rule',
    message: 'Example message',
    ...overrides,
  };
}

describe('security hotspot review state', () => {
  it('detects hotspots from ruleType metadata', () => {
    const violation = makeViolation({
      metadata: { ruleType: 'securityHotspot' },
    });
    assert.strictEqual(isSecurityHotspotViolation(violation), true);
  });

  it('detects hotspots from review-required tag', () => {
    const violation = makeViolation({
      metadata: { tags: ['review-required'] },
    });
    assert.strictEqual(isSecurityHotspotViolation(violation), true);
  });

  it('defaults review state to open', () => {
    const violation = makeViolation({
      metadata: { ruleType: 'securityHotspot' },
    });
    assert.strictEqual(defaultSecurityHotspotReviewState(violation), 'open');
  });

  it('uses defaultReviewState when exported by metadata snapshot', () => {
    const violation = makeViolation({
      metadata: {
        ruleType: 'securityHotspot',
        defaultReviewState: 'reviewed-safe',
      },
    });
    assert.strictEqual(defaultSecurityHotspotReviewState(violation), 'reviewed-safe');
  });

  it('persists and reads explicit review states', async () => {
    const memento = new MockMemento();
    const service = new SecurityHotspotReviewStateService(memento as never);
    const violation = makeViolation({
      metadata: { ruleType: 'securityHotspot' },
    });
    await service.set(violation, 'reviewed-fixed');
    assert.strictEqual(service.getEffective(violation), 'reviewed-fixed');
  });
});
