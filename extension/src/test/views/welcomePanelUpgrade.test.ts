import * as assert from 'assert';
import { isUpgradingAcrossEngineChange } from '../../views/welcomePanelUpgrade';

describe('isUpgradingAcrossEngineChange', () => {
  // Positive case: the only situation where the red engine card may render.
  it('is true for a recorded pre-v16 version upgrading to v16+', () => {
    assert.strictEqual(isUpgradingAcrossEngineChange('15.2.0', '17.4.9'), true);
    assert.strictEqual(isUpgradingAcrossEngineChange('9.0.1', '16.0.0'), true);
  });

  // Unknown history (fresh install, or a build that never recorded its version)
  // must hide the card — the user's explicit requirement.
  it('is false when the previous version is unknown or unparseable', () => {
    assert.strictEqual(isUpgradingAcrossEngineChange(undefined, '17.4.9'), false);
    assert.strictEqual(isUpgradingAcrossEngineChange('', '17.4.9'), false);
    assert.strictEqual(isUpgradingAcrossEngineChange('garbage', '17.4.9'), false);
  });

  // Already on v16+ means the engine change happened in an earlier upgrade.
  it('is false when the previous version is already v16 or later', () => {
    assert.strictEqual(isUpgradingAcrossEngineChange('16.0.1', '17.4.9'), false);
    assert.strictEqual(isUpgradingAcrossEngineChange('17.4.8', '17.4.9'), false);
  });
});
