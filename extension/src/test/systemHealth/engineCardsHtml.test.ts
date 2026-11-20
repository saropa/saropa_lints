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

  // --- Master switch card -------------------------------------------------
  // Helper: one engine per real key plus an enabled/disabled master entry.
  const withMaster = (masterOn: boolean): EngineStatus[] => [
    { key: 'master', name: 'Saropa Lints', enabled: masterOn, status: masterOn ? 'active' : 'stopped' },
    ...keys.map((key): EngineStatus => ({ key, name: key, enabled: true, status: 'active' })),
  ];

  // Slice of the HTML for the card carrying a given data-engine key.
  const cardFor = (html: string, key: string): string => {
    const start = html.indexOf(`data-engine="${key}"`);
    assert.ok(start >= 0, `card ${key} missing`);
    const next = html.indexOf('class="engine-card', start);
    return html.slice(start, next < 0 ? undefined : next);
  };

  it('renders the master card above the engine cards, not in the loop', () => {
    const html = buildEnginesSection(withMaster(true), true);
    assert.strictEqual(html.match(/data-engine="master"/g)?.length, 1);
    assert.ok(html.indexOf('data-engine="master"') < html.indexOf('data-engine="analyzer"'));
    assert.ok(html.includes('master-switch-card'));
  });

  it('master off disables ONLY the scan daemon card', () => {
    const html = buildEnginesSection(withMaster(false), false);
    assert.ok(/ disabled[ >]/.test(cardFor(html, 'scanDaemon')));
    assert.ok(!/ disabled[ >]/.test(cardFor(html, 'analyzer')));
    assert.ok(!/ disabled[ >]/.test(cardFor(html, 'lspServer')));
    assert.ok(!/ disabled[ >]/.test(cardFor(html, 'master')));
  });

  it('master on or unspecified disables nothing', () => {
    for (const flag of [true, undefined]) {
      const html = buildEnginesSection(withMaster(true), flag);
      assert.ok(!html.includes('engine-disabled'));
      assert.ok(!cardFor(html, 'scanDaemon').includes(' disabled'));
    }
  });

  it('derives the gate from the master entry when the flag is omitted', () => {
    // Regression: master OFF with no second argument must still dim the daemon.
    const html = buildEnginesSection(withMaster(false));
    assert.ok(/ disabled[ >]/.test(cardFor(html, 'scanDaemon')));
  });

  it('shows the override note on the master card only when supplied', () => {
    const engines = withMaster(true);
    assert.ok(!buildEnginesSection(engines).includes('folder-level'));
    engines[0] = { ...engines[0], rssNote: 'A folder-level override applies' };
    assert.ok(cardFor(buildEnginesSection(engines), 'master').includes('folder-level'));
  });

  it('names the target engine in Kill and Restart labels', () => {
    const html = buildActionsBar();
    assert.ok(html.includes('>Kill All LSP Server</button>'));
    assert.ok(html.includes('>Restart LSP Server</button>'));
  });
});
