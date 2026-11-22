import * as assert from 'node:assert';
import { applyWindowsPriority, lowPrioritySpec } from '../../scanResources/lowPriority';

describe('lowPrioritySpec', () => {
  const has = (p: string): boolean => p === '/usr/bin/nice';
  it('wraps with nice on POSIX', () => {
    const s = lowPrioritySpec('dart', ['run', 'x'], true, 'linux', has);
    assert.strictEqual(s.command, '/usr/bin/nice');
    assert.deepStrictEqual(s.args, ['-n', '10', 'dart', 'run', 'x']);
  });
  it('is a no-op when disabled', () => {
    assert.deepStrictEqual(lowPrioritySpec('dart', ['a'], false, 'linux', has), { command: 'dart', args: ['a'] });
  });
  it('is a no-op on Windows (priority is applied after spawn)', () => {
    assert.deepStrictEqual(lowPrioritySpec('dart', ['a'], true, 'win32', has), { command: 'dart', args: ['a'] });
  });
  it('falls back to plain dart when nice is missing', () => {
    assert.deepStrictEqual(lowPrioritySpec('dart', ['a'], true, 'darwin', () => false), { command: 'dart', args: ['a'] });
  });
});

describe('applyWindowsPriority', () => {
  it('never throws, including for a bogus pid and on other platforms', () => {
    assert.doesNotThrow(() => applyWindowsPriority(undefined, true));
    assert.doesNotThrow(() => applyWindowsPriority(999999, true, 'win32'));
    assert.doesNotThrow(() => applyWindowsPriority(1, true, 'linux'));
  });
});
