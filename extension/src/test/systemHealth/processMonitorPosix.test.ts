/**
 * ProcessMonitor.start() polling on a stubbed darwin platform, and the
 * analysis-server notification firing once then throttling (10 min).
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as sinon from 'sinon';
import { messageMock, setTestConfig, clearTestConfig } from '../vibrancy/vscode-mock';
import { ProcessMonitor, isSystemHealthPlatformSupported } from '../../systemHealth/processMonitor';
import * as processQuery from '../../systemHealth/processQuery';
import * as systemQuery from '../../systemHealth/systemQuery';
import type { DartProcessInfo } from '../../systemHealth/types';

const GB = 1024 * 1024 * 1024;
const SECTION = 'saropaLints.systemHealth';

function analysisServer(bytes: number): DartProcessInfo {
  return {
    processId: 1432,
    parentProcessId: 1,
    workingSetSize: bytes,
    creationDate: '2026-09-18T10:15:02.000Z',
    commandLine: '/x/dart-sdk/bin/dart language-server --protocol=lsp',
  };
}

describe('ProcessMonitor on darwin', () => {
  let clock: sinon.SinonFakeTimers;
  let queryStub: sinon.SinonStub;
  let originalPlatform: PropertyDescriptor | undefined;
  let monitor: ProcessMonitor;

  function setPlatform(value: string): void {
    Object.defineProperty(process, 'platform', { value, configurable: true });
  }

  beforeEach(() => {
    originalPlatform = Object.getOwnPropertyDescriptor(process, 'platform');
    setPlatform('darwin');
    clock = sinon.useFakeTimers({ now: 1_000_000_000_000 });
    messageMock.reset();
    clearTestConfig();
    setTestConfig(SECTION, 'pollIntervalSeconds', 60);
    queryStub = sinon.stub(processQuery, 'queryDartProcesses').resolves([analysisServer(6 * GB)]);
    // Healthy machine so only the analysis-server check can notify.
    sinon.stub(systemQuery, 'querySystemMemory').resolves({
      totalBytes: 16 * GB,
      freeBytes: 8 * GB,
      freeFraction: 0.5,
    });
    monitor = new ProcessMonitor();
  });

  afterEach(() => {
    monitor.dispose();
    sinon.restore();
    clock.restore();
    clearTestConfig();
    if (originalPlatform) Object.defineProperty(process, 'platform', originalPlatform);
  });

  it('treats darwin as supported and freebsd as unsupported', () => {
    assert.ok(isSystemHealthPlatformSupported());
    assert.ok(!isSystemHealthPlatformSupported('freebsd'));
  });

  it('start() polls immediately and then every interval', async () => {
    monitor.start();
    await clock.tickAsync(0);
    assert.strictEqual(queryStub.callCount, 1);
    assert.ok(monitor.getLastSnapshot());
    await clock.tickAsync(60_000);
    assert.strictEqual(queryStub.callCount, 2);
    await clock.tickAsync(60_000);
    assert.strictEqual(queryStub.callCount, 3);
  });

  it('start() does not poll on an unsupported platform', async () => {
    setPlatform('freebsd');
    monitor.start();
    await clock.tickAsync(120_000);
    assert.strictEqual(queryStub.callCount, 0);
  });

  it('start() does not poll when disabled', async () => {
    setTestConfig(SECTION, 'enabled', false);
    monitor.start();
    await clock.tickAsync(120_000);
    assert.strictEqual(queryStub.callCount, 0);
  });

  it('analysis-server warning fires once, throttles for 10 min, then fires again', async () => {
    monitor.start();
    await clock.tickAsync(0);
    assert.strictEqual(messageMock.warnings.length, 1, 'first poll notifies');

    // Polls at +1..+9 min are inside the 10 min throttle window.
    await clock.tickAsync(9 * 60_000);
    assert.strictEqual(messageMock.warnings.length, 1, 'throttled');

    // Past 10 min since the first notification.
    await clock.tickAsync(2 * 60_000);
    assert.strictEqual(messageMock.warnings.length, 2, 'fires again after throttle');
  });

  it('does not notify when the analysis server is under the threshold', async () => {
    queryStub.resolves([analysisServer(1 * GB)]);
    monitor.start();
    await clock.tickAsync(0);
    assert.strictEqual(messageMock.warnings.length, 0);
  });

  it('does not notify when showNotifications is off', async () => {
    setTestConfig(SECTION, 'showNotifications', false);
    monitor.start();
    await clock.tickAsync(0);
    assert.strictEqual(messageMock.warnings.length, 0);
  });
});
