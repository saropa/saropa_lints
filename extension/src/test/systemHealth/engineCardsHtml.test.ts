/**
 * Engine cards: every card carries a "Recommended" note, a summary sits above
 * the cards, and Kill/Restart buttons name the engine they act on.
 */
import * as assert from 'node:assert';
import { buildActionsBar, buildEnginesSection, type EngineStatus } from '../../systemHealth/engineCardsHtml';

const keys: EngineStatus['key'][] = ['analyzer', 'scanDaemon', 'lspServer', 'ci'];

describe('engineCardsHtml', () => {
  it('renders a recommendation summary and one note per card', () => {
    const engines = keys.map((key): EngineStatus => ({ key, name: key, enabled: false, status: 'stopped' }));
    const html = buildEnginesSection(engines);
    assert.strictEqual(html.match(/class="engine-recommendation"/g)?.length, 1);
    assert.strictEqual(html.match(/class="engine-recommended"/g)?.length, keys.length);
    assert.ok(html.includes('Recommended: LSP Server ON'));
  });

  it('names the target engine in Kill and Restart labels', () => {
    const html = buildActionsBar();
    assert.ok(html.includes('>Kill All LSP Server</button>'));
    assert.ok(html.includes('>Restart LSP Server</button>'));
  });
});
