# Plan: v16 Welcome Flow

**Goal:** A prominent, unmissable upgrade welcome panel that surfaces the three things every v16 user must know: the new diagnostic engine (and how to revert), the new monitoring surface, and where their sidebar went.

**Trigger:** First activation after upgrading to v16 from any earlier version (or fresh install of v16). Reopenable from Command Palette.

---

## Architecture

### Version tracking (new)

- On activate, read `globalState.get('saropaLints.lastActivatedVersion')`.
- Compare against current `extVersion` using semver major.
- If stored version is absent (fresh install) or major < 16: show the welcome panel, then write current version.
- If major >= 16: skip. The panel is a one-time upgrade gate, not a per-beta nag.
- The command palette entry (`saropaLints.showWelcome`) always opens it regardless of version state.

### Panel (WebviewPanel singleton)

Follow the HealthPanel pattern exactly:

| Piece | File |
|-------|------|
| Panel class | `extension/src/views/welcomePanel.ts` |
| HTML builder | `extension/src/views/welcomePanel-html.ts` |
| Styles | `extension/src/views/welcomePanel-styles.ts` |
| Script | `extension/src/views/welcomePanel-script.ts` |

- viewType: `saropaWelcome`
- Title: `l10n('welcome.panel.title')` → "What's New in v16"
- Uses `getDashboardChromeStyles()` + `buildDashboardHero()` shared chrome.
- `retainContextWhenHidden: false` — this panel has no live state worth keeping.

### Command

- `saropaLints.showWelcome` — registered in extension.ts alongside the other dashboard commands.
- Title: `%command.showWelcome.title%` → "Saropa Lints: What's New"
- No keybinding. No sidebar row (the panel is transient, not a workflow destination).
- Added to the Help Hub quick-pick list (`helpHub.ts`) as the top item when on v16.

---

## Content: Three Cards

The panel body is three visually distinct cards in a single scrollable column. Each card has: an icon/emoji header, 2–3 sentences of what changed, a **Why this matters** line, and one or two action buttons.

### Card 1 — New Diagnostic Engine

**Header:** "New: LSP Server (replaces Analyzer Plugin)"

**Body:**
- The default diagnostic engine is now a standalone LSP server. It provides the same diagnostics and quick fixes with far less memory (~10 GB less).
- The analyzer plugin is still available as a fallback.

**Why this matters:** If diagnostics look wrong or a rule you rely on behaves differently, you can revert in one click.

**Actions:**
- **"Open Health Panel"** → `saropaLints.showProcessHealth`
- **"Revert to Analyzer Plugin"** → posts message to extension host, which runs:
  1. `saropaLints.lspServer.enabled` → `false` (workspace setting)
  2. Shows toast confirming the revert with an "Undo" button
  - This is the same toggle the Health Panel exposes; the welcome panel just surfaces it prominently.

### Card 2 — System Monitoring

**Header:** "New: Machine Health Monitoring"

**Body:**
- The extension now monitors system RAM, every Dart analysis server, Flutter daemon, and background process — not just its own.
- A Dev Tool Budget indicator warns when dev tools exceed a configurable share of RAM (default 60%).
- Orphaned processes from crashed sessions are detected at startup with a one-click reclaim.

**Why this matters:** Large projects routinely leak analysis servers. You'll now see it before your machine slows down.

**Actions:**
- **"Open Machine Health"** → `saropaLints.showMachineDashboard`
- **"Configure Thresholds"** → opens workspace settings filtered to `saropaLints.systemHealth`

### Card 3 — Sidebar & Dashboard Overhaul

**Header:** "Changed: Sidebar Simplified"

**Body:**
- The sidebar went from up to 39 rows and 7 panels down to 13 rows and 4 panels. Severity toggles, engine controls, and settings moved into their respective dashboards.
- Debug Panel merged into Health Panel. Home hub removed — status bar and Findings Dashboard replace it.
- Rules & Tiers now has 7 tabs covering every config surface. Package Dashboard has 6 tabs.

**Why this matters:** If something you used to click in the sidebar is gone, it moved to a dashboard — it wasn't removed.

**Actions:**
- **"Browse All Commands"** → `saropaLints.showCommandCatalog`
- **"Open Walkthrough"** → `saropaLints.openWalkthrough`

---

## Strings

All user-facing text goes in `en.json` under a `welcome.*` namespace:

```
welcome.panel.title
welcome.hero.subtitle
welcome.card.engine.header
welcome.card.engine.body
welcome.card.engine.why
welcome.card.engine.actionHealth
welcome.card.engine.actionRevert
welcome.card.engine.revertConfirm
welcome.card.monitoring.header
welcome.card.monitoring.body
welcome.card.monitoring.why
welcome.card.monitoring.actionDashboard
welcome.card.monitoring.actionThresholds
welcome.card.sidebar.header
welcome.card.sidebar.body
welcome.card.sidebar.why
welcome.card.sidebar.actionCatalog
welcome.card.sidebar.actionWalkthrough
```

Approximately 18 keys. Translations regenerated at publish time per standard pipeline.

---

## Activation wiring (extension.ts)

Insert after command registration, near the end of `activate()`:

```typescript
// Show welcome panel on major-version upgrade
const lastVersion = context.globalState.get<string>('saropaLints.lastActivatedVersion');
const currentMajor = parseInt(extVersion.split('.')[0], 10);
const lastMajor = lastVersion ? parseInt(lastVersion.split('.')[0], 10) : 0;
if (currentMajor >= 16 && lastMajor < 16) {
    // Delay slightly so the sidebar finishes rendering first
    setTimeout(() => WelcomePanel.createOrShow(context), 3000);
}
context.globalState.update('saropaLints.lastActivatedVersion', extVersion);
```

The version is always written — even when the panel isn't shown — so subsequent activations on the same major skip cleanly.

---

## Scope boundaries

**In scope:**
- The four files (panel, html, styles, script)
- ~18 l10n keys in en.json
- Command registration + package.json entry
- Version-gate logic in extension.ts
- Help Hub entry

**Out of scope:**
- Locale regeneration (publish-time gate, not done mid-development)
- Walkthrough step updates (existing 10 steps are fine; welcome panel links to it)
- Sidebar row for the welcome panel (it's transient)
- Telemetry / analytics

---

## Verification

- [ ] `npm run compile` clean
- [ ] `npx tsc --noEmit -p .` and `npx tsc -p tsconfig.test.json` clean
- [ ] Panel opens from Command Palette
- [ ] Panel auto-shows on simulated upgrade (clear globalState key, reload)
- [ ] All three action-button pairs work (6 buttons total)
- [ ] "Revert to Analyzer Plugin" writes the setting and shows toast
- [ ] Panel renders in both light and dark themes (screenshot in bugs/)
- [ ] Panel renders at narrow width (~380px) without horizontal scroll
- [ ] l10n keys resolve (no raw key strings visible)
- [ ] Help Hub lists "What's New" entry
