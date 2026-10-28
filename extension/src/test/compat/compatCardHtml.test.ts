import '../vibrancy/register-vscode-mock';
import * as assert from 'node:assert';
import { buildCompatSection } from '../../compat/compatCardHtml';

describe('buildCompatSection', () => {
  it('renders nothing before the card is opened', () => {
    assert.strictEqual(buildCompatSection(undefined), '');
  });
  it('renders facts, message, blockers, fixes and buttons', () => {
    const html = buildCompatSection({
      hasEdits: true,
      facts: { dartVersion: '3.9.0', locked: { saropaLints: { version: '16.0.0', source: 'hosted' }, analyzer: '8.0.0' }, inPubspec: true, pluginBlockDisabled: false },
      rec: {
        route: 'dependency', constraint: '^16.10.0', pluginVersion: '16.10.0',
        messageKey: 'compat.recommend.latestOk', messageParams: { version: '16.10.0' },
        blockers: [{ key: 'compat.recommend.blockerSdk', params: { version: '17.0.0', dart: '3.9.0' } }],
        fixes: [{ key: 'compat.recommend.fixFlutterUpgrade', params: {} }], notes: [],
      },
    });
    assert.ok(html.includes('3.9.0') && html.includes('16.0.0') && html.includes('8.0.0'));
    assert.ok(html.includes('flutter upgrade'));
    assert.ok(html.includes('data-action="compatApply"') && html.includes('data-action="compatPreview"'));
    assert.ok(!/data-action="compatApply"[^>]*disabled/.test(html));
  });
  it('disables Apply when there is nothing to change', () => {
    const html = buildCompatSection({ hasEdits: false, rec: {
      route: 'dependency', constraint: '', pluginVersion: '', messageKey: 'compat.recommend.alreadyCorrect',
      messageParams: {}, blockers: [], fixes: [], notes: [] } });
    assert.ok(/data-action="compatApply"[^>]*disabled/.test(html));
  });
  it('escapes error text', () => {
    assert.ok(buildCompatSection({ error: '<b>x</b>' }).includes('&lt;b&gt;'));
  });
});
