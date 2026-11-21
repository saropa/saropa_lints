# Porting guide: version-gated upgrade notice ("What's New" panel)

Source: saropa_lints VS Code extension (`extension/src/views/welcomePanel*.ts`). Target: any other Saropa VS Code extension that ships a breaking change and needs to warn ONLY the users it affects.

Read sections 1-3 first. Sections 4-9 are copy-paste. Section 10 is the done-checklist.

---

## 1. What this gives you

| Situation | Warning card | Warning subtitle | Panel opens? |
|---|---|---|---|
| Upgrade from a recorded version below the breaking major | SHOWN | SHOWN | yes |
| Fresh install | hidden | hidden | yes (generic panel) |
| Upgrade from a build that never recorded its version ("can't tell") | hidden | hidden | yes (generic panel) |
| Previous version already at/above the breaking major | hidden | hidden | yes (generic panel) |

Rule behind the table: a loud warning for a change that does not apply to the user is worse than no warning. Unknown history means hidden.

Every decision is logged with all inputs and the reason, so "why did / didn't the card show?" is answered from the log, not by trial and error.

## 2. Parameters you must decide per project

| Parameter | saropa_lints value | Your project |
|---|---|---|
| Breaking major | `16` (`ENGINE_CHANGE_MAJOR`) | the major that introduced the breaking change |
| Stored-version globalState key | `saropaLints.lastActivatedVersion` | `<yourExtId>.lastActivatedVersion` (never share a key across extensions) |
| Auto-show opt-out key | `saropaLints.welcomeShowOnNextActivation` | `<yourExtId>.welcomeShowOnNextActivation` |
| Card i18n namespace | `welcome.card.engine.*` | `welcome.card.<change>.*` |
| Log tag | `[welcome]` | keep `[welcome]` so one grep works across projects |

Rename the saropa_lints symbols (`isUpgradingAcrossEngineChange`, `describeEngineCardReason`, `showEngineCard`, `ENGINE_CHANGE_MAJOR`) to describe YOUR change. They are named for the engine swap.

## 3. Prerequisites in the target project

The code below assumes these exist. If one is missing, stop and add it (or adapt) BEFORE copying:

- `l10n(key, params?)` runtime and `locales/en.json` (`../i18n/runtime`).
- A webview HTML helper set: `createWebviewCspNonce`, `escapeHtml` (saropa_lints: `vibrancy/views/html-utils`).
- Shared dashboard chrome CSS with design tokens: `--accent-critical`, `--accent-info`, `--accent-medium`, `--surface-2`, `--border`, `--muted`, `--space-*`, `--radius-md`, `--text-h3`, `--text-caption`. No raw hex.
- A report/log sink (saropa_lints: `logReport` in `reportWriter.ts`). If the project has none, use its OutputChannel; keep the line format in section 7.
- `context.globalState` available in `activate()`.

No welcome panel in the target at all? Port the whole `welcomePanel*.ts` set (panel, html, styles, script). A toast is NOT a substitute: the point of the panel is persistence until read.

## 4. File 1 (copy verbatim): pure helper, no `vscode` import

`extension/src/views/welcomePanelUpgrade.ts`

```ts
/**
 * Pure upgrade-detection helpers for the What's New panel (no `vscode` import so
 * they can be unit-tested headlessly).
 */

/** Major version in which the breaking change shipped. */
export const ENGINE_CHANGE_MAJOR = 16;

/** Extracts the major version from a semver-ish string, or null when unparseable. */
function parseMajor(version: string | undefined): number | null {
  if (!version) return null;
  const match = /^(\d+)\./.exec(version.trim());
  return match ? Number(match[1]) : null;
}

/**
 * Human-readable reason for the card decision, for the debug log. Mirrors
 * isUpgradingAcrossEngineChange's branches so the log never disagrees with behavior.
 */
export function describeEngineCardReason(previousVersion: string | undefined, shown: boolean): string {
  if (shown) return 'confirmed upgrade from before v' + ENGINE_CHANGE_MAJOR;
  if (parseMajor(previousVersion) === null) {
    return previousVersion ? 'previous version unparseable' : 'no previous version recorded (fresh install or unknown history)';
  }
  return 'previous version already v' + ENGINE_CHANGE_MAJOR + ' or later';
}

/**
 * True only when the user is KNOWN to be upgrading across the breaking change: a
 * recorded previous version below ENGINE_CHANGE_MAJOR and a current version at or
 * above it. Missing or unparseable previous version returns false — the card is an
 * upgrade warning, and showing it when the upgrade cannot be confirmed would alarm
 * users it does not apply to.
 */
export function isUpgradingAcrossEngineChange(
  previousVersion: string | undefined,
  currentVersion: string,
): boolean {
  const previous = parseMajor(previousVersion);
  const current = parseMajor(currentVersion);
  if (previous === null || current === null) return false;
  return previous < ENGINE_CHANGE_MAJOR && current >= ENGINE_CHANGE_MAJOR;
}
```

Limit: major-only comparison. If your breaking change shipped in a MINOR (e.g. 3.4.0), replace `parseMajor` with a full semver compare; do not ship the major-only version for a minor-level break.

## 5. File 2: panel class additions

`extension/src/views/welcomePanel.ts` — add these near the top (after imports):

```ts
import { isUpgradingAcrossEngineChange, describeEngineCardReason } from './welcomePanelUpgrade';
import { logReport } from '../reportWriter';

/** globalState key holding the extension version that last activated. */
const LAST_ACTIVATED_VERSION_KEY = 'saropaLints.lastActivatedVersion';

/**
 * Whether this session is a confirmed upgrade across the breaking change. Computed once
 * per activation by recordActivationVersion() (before the stored version is overwritten)
 * and read by the panel whenever it renders, so reopening the panel from the Command
 * Palette in the same session shows the same content.
 */
let showEngineCard = false;

/**
 * Compares the previously stored version against the running one, then stores the
 * running one. MUST be called once at activation before the panel can open: after
 * this runs the old version is gone, so the upgrade decision is captured here.
 */
export function recordActivationVersion(context: vscode.ExtensionContext): void {
  const current = (context.extension.packageJSON as { version: string }).version;
  const previous = context.globalState.get<string>(LAST_ACTIVATED_VERSION_KEY);
  showEngineCard = isUpgradingAcrossEngineChange(previous, current);
  void context.globalState.update(LAST_ACTIVATED_VERSION_KEY, current);
  const showOnActivation = context.globalState.get<boolean>(SHOW_ON_ACTIVATION_KEY, true);
  logReport(
    `[welcome] previousVersion=${previous ?? '(none recorded)'} currentVersion=${current} ` +
      `engineCard=${showEngineCard ? 'SHOWN' : 'hidden'} ` +
      `reason=${describeEngineCardReason(previous, showEngineCard)} ` +
      `autoShowOnActivation=${showOnActivation} (globalState ${SHOW_ON_ACTIVATION_KEY})`,
  );
}
```

In the panel constructor, log each render and pass the flag to EVERY html build (the initial render AND any async re-render, e.g. after rule counts arrive):

```ts
logReport(`[welcome] panel rendered: version=${this.version} engineCard=${showEngineCard ? 'SHOWN' : 'hidden'}`);
this.panel.webview.html = buildWelcomePanelHtml(this.version, null, showEngineCard);
// ...and in the async .then(): buildWelcomePanelHtml(this.version, counts, showEngineCard)
```

Missing the flag on the second call makes the card flash on then vanish (or the reverse). Grep for `buildWelcomePanelHtml(` and confirm every call passes it.

## 6. Activation wiring (order matters)

`extension.ts`, inside `activate()`:

```ts
import { WelcomePanel, SHOW_ON_ACTIVATION_KEY, recordActivationVersion } from './views/welcomePanel';

// Capture upgrade history first: decides whether the red card renders, then stores this version.
recordActivationVersion(context);
if (context.globalState.get<boolean>(SHOW_ON_ACTIVATION_KEY, true)) {
  setTimeout(() => WelcomePanel.createOrShow(context), 3000); // let sidebar/status bar render first
}
```

`recordActivationVersion` MUST run before the auto-show check AND before any command that can open the panel. It runs once; never call it from the panel constructor (reopening would overwrite the stored version and the old value is lost).

## 7. File 3: HTML builder changes

`extension/src/views/welcomePanel-html.ts`

```ts
interface WelcomeCard {
  icon: string; header: string; body: string; why: string;
  actions: WelcomeAction[];
  /** Marks the breaking-change card so it renders with elevated visual weight. */
  critical?: boolean;
  /** Chrome accent token (no `var()`) for the left border when not critical. */
  tone?: string;
}

function buildCards(showEngineCard: boolean): WelcomeCard[] {
  const cards: WelcomeCard[] = [
    {
      icon: '🚨',
      header: l10n('welcome.card.engine.header'),
      body: l10n('welcome.card.engine.body'),
      why: l10n('welcome.card.engine.why'),
      actions: [
        { label: l10n('welcome.card.engine.actionHealth'), action: 'openHealthPanel' },
        { label: l10n('welcome.card.engine.actionRevert'), action: 'revertToAnalyzer' },
      ],
      critical: true,
    },
    // ...non-critical feature cards, each with tone: 'accent-info' | 'accent-medium'
  ];
  // The critical card is an upgrade warning: drop it unless the upgrade is confirmed.
  return showEngineCard ? cards : cards.filter((c) => !c.critical);
}

export function buildWelcomePanelHtml(
  version: string,
  ruleCounts: RuleCountSummary | null = null,
  showEngineCard = false,            // default false: safe if a caller forgets
): string {
  // ...
  const cardsHtml = buildCards(showEngineCard).map(buildCardHtml).join('\n');
  // The subtitle warns about the breaking change, so it only renders alongside the card.
  const subtitleHtml = showEngineCard
    ? `<p class="welcome-subtitle">${escapeHtml(l10n('welcome.hero.subtitle'))}</p>`
    : '';
  // in the template: ${subtitleHtml} where the unconditional <p class="welcome-subtitle"> was
}
```

`buildCardHtml` adds `welcome-card welcome-card-critical` when `card.critical`, otherwise `welcome-card` with an inline `border-left-color: var(--<tone>)`.

CSS (`welcomePanel-styles.ts`), token-only:

```css
.welcome-card-critical {
  border-color: var(--accent-critical);
  border-left-width: 4px;
  background: color-mix(in srgb, var(--accent-critical) 6%, var(--surface-2));
}
.welcome-card-critical h2 { color: var(--accent-critical); }
```

## 8. i18n keys (`locales/en.json`, English values to adapt)

```json
"welcome": {
  "panel":    { "title": "What's New" },
  "hero":     { "subtitle": "<one sentence: this release changes X; it affects Y>" },
  "checkbox": {
    "label": "Show this next time",
    "hint": "Scroll to the bottom to unlock this. Until then, this notice will keep reappearing.",
    "hintEnabled": "Uncheck this to stop the notice from reappearing."
  },
  "card": { "engine": {
    "header": "CRITICAL: <what changed>",
    "body": "<what it is now, what to expect, how to undo it>",
    "why": "<why this is not cosmetic; what to verify>",
    "actionHealth": "<primary action label>",
    "actionRevert": "<undo action label>",
    "revertConfirm": "<toast after undo>"
  } }
}
```

- Panel title is version-free ("What's New"). The hero already shows the live version badge. The original "What's New in v16" string went stale at v17 and had to be fixed in English plus 23 locale files.
- Do NOT concatenate strings around dynamic values; use `{token}` placeholders.
- After editing `en.json`, translated catalogs are stale. Regenerate at publish time with the project's translation process. Never run a machine-translation pipeline without an explicit go-ahead.
- If the panel/title/subtitle keys already exist in the target, reuse them; only add the card namespace.

## 9. Test (copy, adjust imports and the major)

`extension/src/test/views/welcomePanelUpgrade.test.ts`

```ts
import * as assert from 'assert';
import { isUpgradingAcrossEngineChange } from '../../views/welcomePanelUpgrade';

describe('isUpgradingAcrossEngineChange', () => {
  it('is true for a recorded pre-v16 version upgrading to v16+', () => {
    assert.strictEqual(isUpgradingAcrossEngineChange('15.2.0', '17.4.9'), true);
    assert.strictEqual(isUpgradingAcrossEngineChange('9.0.1', '16.0.0'), true);
  });
  it('is false when the previous version is unknown or unparseable', () => {
    assert.strictEqual(isUpgradingAcrossEngineChange(undefined, '17.4.9'), false);
    assert.strictEqual(isUpgradingAcrossEngineChange('', '17.4.9'), false);
    assert.strictEqual(isUpgradingAcrossEngineChange('garbage', '17.4.9'), false);
  });
  it('is false when the previous version is already v16 or later', () => {
    assert.strictEqual(isUpgradingAcrossEngineChange('16.0.1', '17.4.9'), false);
    assert.strictEqual(isUpgradingAcrossEngineChange('17.4.8', '17.4.9'), false);
  });
});
```

Use boundary values from YOUR breaking major (`N-1.x.x` true, `N.0.0` false). Add a positive case; a defensive-only suite hides a helper that always returns false.

## 10. Debug log format (grep `[welcome]`)

```
[welcome] previousVersion=15.2.0 currentVersion=17.4.9 engineCard=SHOWN reason=confirmed upgrade from before v16 autoShowOnActivation=true (globalState saropaLints.welcomeShowOnNextActivation)
[welcome] previousVersion=(none recorded) currentVersion=17.4.9 engineCard=hidden reason=no previous version recorded (fresh install or unknown history) autoShowOnActivation=true (...)
[welcome] previousVersion=16.0.1 currentVersion=17.4.9 engineCard=hidden reason=previous version already v16 or later autoShowOnActivation=true (...)
[welcome] panel rendered: version=17.4.9 engineCard=hidden
```

Diagnosing "the card is not showing for someone who upgraded": check the first line. `(none recorded)` means they upgraded from a build that predates this tracking: expected, not a bug. To force the card for testing: Command Palette > "Developer: Open Extension Storage"/clear the extension's globalState, or temporarily seed the key with an old version.

## 11. Done checklist (copy into the target's task)

1. Copy `welcomePanelUpgrade.ts`; rename symbols; set the breaking major.
2. Add `recordActivationVersion` + flag + logging to the panel class; set the project's globalState keys.
3. Pass `showEngineCard` to every `buildWelcomePanelHtml` call (grep to confirm).
4. Call `recordActivationVersion(context)` in `activate()` before the auto-show check.
5. Filter the critical card and the subtitle in the HTML builder; default the param to `false`.
6. Add card + subtitle keys to `en.json`; title stays version-free.
7. Add the unit test; run `npx tsc --noEmit -p .`, `npx tsc -p tsconfig.test.json`, scoped mocha on the new suite.
8. Add a CHANGELOG entry under the top unreleased section (one sentence).
9. Regenerate translated catalogs at publish time (not now).
10. Verify visually (see below) and report as UNVERIFIED until a screenshot exists.

Visual verification (an agent cannot do the Extension Development Host step; a human must):
- `npm run compile`, then F5 the Extension Development Host against the fresh bundle.
- Look at three states: confirmed upgrade (seed the stored version to an old value), fresh install (clear globalState), already-current.
- Both light and dark themes; narrow (~380px) width; no horizontal page scroll.
- Screenshot to `bugs/` and share it.

## 12. Gotchas we already hit

- Hardcoded version in the panel title ("What's New in v16") went stale at v17. Keep versions out of titles.
- The auto-show flag defaults to true, so the panel reappears every activation until the user unchecks "Show this next time" (the checkbox is disabled until the page is scrolled to the bottom — `welcomePanel-script.ts`). The version gate only controls the WARNING; if you do not want the panel itself to reappear for non-upgraders, also gate `SHOW_ON_ACTIVATION_KEY`'s default on the same decision. That change is NOT made in saropa_lints.
- Users already on the new major with no stored version never see the card. Intended.
- The script and checkbox hint copy still reference "the critical engine-change card" in comments; reword for your change.
- `revertToAnalyzer` is specific to saropa_lints (flips `saropaLints.lspServer.enabled`). Replace with your project's undo action, or drop the second button.
- Changelog hook fails if `pubspec.yaml`/`package.json` version drifts from the last published tag. Do not bump versions by hand.
- Do not hand-edit generated locale files unless explicitly told to; the 23-locale title fix here was a deliberate exception.

## 13. Status in saropa_lints (as of this guide)

- `npx tsc --noEmit -p .` and `npx tsc -p tsconfig.test.json`: pass.
- New mocha test: written, NOT yet run.
- Rendered panel (card hidden, no subtitle, new title) in the Extension Development Host: NOT yet seen.
- Debug log lines in the extension report: NOT yet seen.
