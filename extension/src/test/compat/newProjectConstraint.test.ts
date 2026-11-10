import * as assert from 'node:assert';
import { chooseNewProjectConstraint, FALLBACK_CONSTRAINT } from '../../compat/newProjectConstraint';
import type { PubVersion } from '../../compat/pubVersions';

const V = (version: string, sdk: string): PubVersion => ({ version, sdk });
const VERSIONS: PubVersion[] = [
  V('17.1.0', '>=3.11.0 <4.0.0'),
  V('17.1.1-beta.1', '>=3.11.0 <4.0.0'),
  V('16.10.0', '>=3.9.0 <4.0.0'),
  V('16.7.0', '>=3.9.0 <4.0.0'),
];

describe('chooseNewProjectConstraint', () => {
  it('picks the newest stable the Dart SDK allows', async () => {
    assert.strictEqual(await chooseNewProjectConstraint('3.13.0', VERSIONS), '^17.1.0');
  });

  it('stays on 16.x when Dart is too old for 17', async () => {
    assert.strictEqual(await chooseNewProjectConstraint('3.10.0', VERSIONS), '^16.10.0');
  });

  it('falls back to ^16.7.0 when the Dart version is unknown', async () => {
    assert.strictEqual(await chooseNewProjectConstraint(undefined, VERSIONS), FALLBACK_CONSTRAINT);
    assert.strictEqual(FALLBACK_CONSTRAINT, '^16.7.0');
  });

  it('falls back when the pub.dev list is empty', async () => {
    assert.strictEqual(await chooseNewProjectConstraint('3.13.0', []), FALLBACK_CONSTRAINT);
  });

  it('falls back when no version fits the Dart SDK', async () => {
    assert.strictEqual(await chooseNewProjectConstraint('2.19.0', VERSIONS), FALLBACK_CONSTRAINT);
  });
});
