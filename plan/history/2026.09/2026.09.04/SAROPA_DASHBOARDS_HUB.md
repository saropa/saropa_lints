# Spec: Saropa Dashboards Hub

Status: Draft
Last updated: 2026-06-22
Owner: extension UI
Scope: VS Code extension webview that composes the Project Map and Code Health
dashboards onto one page, side by side.

This spec describes the existing **Saropa Dashboards** hub (command
`saropaLints.openDashboards`, editor-tab title "Saropa Dashboards") as the source
of truth for behavior, plus the constraints any change must hold. Implementation
lives in [saropaDashboardsView.ts](../../extension/src/views/saropaDashboardsView.ts).
Companion spec: [lint_rule_configuration_screen.md](./lint_rule_configuration_screen.md).

---

## 1. Purpose

Show two independently-built dashboards together on **one** webview document so a
user sees structural and quality signals at once without juggling two tabs:

1. **Project Map** — ECharts treemap / churn-complexity scatter / hot-spot table
   (from [projectMapView.ts](../../extension/src/views/projectMapView.ts)).
2. **Code Health (Vibrancy)** — score status line, KPI preset filters, sortable
   function table (from
   [projectVibrancyReportView.ts](../../extension/src/views/projectVibrancyReportView.ts)).

The hub is **additive and composing, not replacing**: the standalone commands
`saropaLints.openProjectHealthDashboard` (Project Map) and
`saropaLints.openProjectVibrancyReport` (Code Health) are unchanged. The hub is a
third entry that runs both scans and assembles both engines' real markup, styles,
and scripts into a single document. Each pane preserves its full interactive
content; the hub adds shared chrome, a two-pane grid, and cross-pane drill-down.

---

## 2. Terminology (plain meaning first)

- **Pane** — one of the two dashboards rendered as a titled card in the grid:
  `projectMap` or `codeHealth`.
- **Composed document** — a single HTML document holding both engines' output.
  **Not** an iframe per pane (see §3 for why naive composition fails and how it
  is handled).
- **Fragment** — an engine's embeddable output: Project Map's `ProjectMapParts`
  (`bodyHtml`, `styleHtml`, `scriptHtml`, `echartsUri`), Code Health's
  `CodeHealthFragment` (`body`, `script`).
- **Loading shell** — the immediate skeleton rendered before scans finish: hero +
  two empty panes each showing a "scanning…" status.
- **API shim** — the inline script that acquires the single VS Code API handle
  once and re-exposes it so both engines share one messaging channel.

---

## 3. Composition model — two hazards, handled without rewriting either engine

The hub assembles two engines built to run standalone. Two failure modes make
naive composition break; each is solved at the host level so neither engine is
modified:

1. **`acquireVsCodeApi()` may be called only once per document.** Both engines'
   scripts call it (Project Map's inline data script, Code Health's IIFE). The
   host's **API shim** acquires the single handle up front and overrides
   `window.acquireVsCodeApi` to return that cached handle, so both get the same
   channel. The shim script must run **before** either engine script in body
   order.
2. **CSS would collide on bare selectors and `:root` tokens.** Both engines use
   `body`, `table`, `.chip`, `.panel`. Project Map's stylesheet is scoped under
   `.pm-pane`, so it cannot leak onto shared chrome or the Code Health pane. The
   two engines' DOM ids do not overlap (`treemap`/`filter`/`hot` vs
   `pvTable`/`pvSearch`/…), so a shared document is safe.

Additional composition rules:

- **ECharts is loaded once** in the host `<head>` (from `media/`), shared by the
  Project Map pane. The vendored file is the only resource served from
  `cspSource`.
- **Project Map theme tokens are rebound** to the editor theme
  (`pmPaneThemeTokens()`) so the pane matches the theme-driven Code Health pane
  rather than rendering in the fixed brand palette.
- **Project Map viewport fixups** (`pmPaneHostFixups()`) collapse the standalone
  `min-height: 100vh` to content height inside the grid cell. Scoped to
  `.dash-pane .pm-pane` only — the standalone export is untouched.
- `buildDashboardsDocument(cspSource, pmParts, chFrag)` is **pure** (no webview
  arg) so unit tests can assert the composition contract directly: shared API
  shim present, both panes present, Project Map styles scoped.

---

## 4. Scan lifecycle

1. `openDashboards()` resolves the project root and validates the
   `saropa_lints` dependency (see §7). If a scan pair is already running
   (`inflight`), it reveals the panel and shares the in-flight promise — it does
   **not** double-spawn.
2. The **loading shell** is rendered immediately and the panel revealed.
3. Both scans run **concurrently** under one cancellable progress notification
   (`vscode.window.withProgress`): `scanProjectMapToParts` and
   `scanCodeHealthFragment`. The composed view shows a **single** loading state,
   not each engine's live scan animation (those stay in the standalone panels).
4. When both finish, the composed document is assembled and set as the webview
   HTML — but only if the panel still exists (it may be disposed mid-scan).
5. A **failed or canceled pane** renders an inline `pane-failed` placeholder; it
   does **not** blank the other pane. One engine erroring must not take down the
   whole view.

Re-scan: `rescan` / `restart` messages re-run `runAndRender` against `lastRoot`,
guarded by the same `inflight` lock.

---

## 5. Screen layout

- **Hero header** — shared `buildDashboardHero` band, title `dashboards.heroTitle`
  ("Saropa " prefix enforced by the helper). The hub passes
  `showFullWidthToggle: false` (the two-pane grid owns width, not the per-body
  toggle).
- **Two-pane grid** (`.dash-grid`) — `grid-template-columns: 1fr 1fr`, collapses
  to a single column below 1100px. Each pane is a `.dash-pane` card:
  - `pane-head` — `<h2>` title (`dashboards.pane.projectMap` /
    `dashboards.pane.codeHealth`) plus an **"Open full screen"** button (only in
    the assembled document, not the loading shell).
  - `pane-body` — the engine fragment, or a `pane-status` / `pane-failed`
    placeholder.
- **Body scripts** — appended last, in order: API shim → Project Map script →
  Code Health script.

---

## 6. Interactions (webview → host messages)

Routed by `handleHostMessage`. Both panes post to this one host.

| Message | Payload | Effect |
|---------|---------|--------|
| `openFile` | `file`, `line?` | open target file; line ≤ 1 → shared opener (preview, line 1); line > 1 → reveal at line |
| `openProjectMapFull` | — | run `saropaLints.openProjectHealthDashboard` (standalone) |
| `openCodeHealthFull` | — | run `saropaLints.openProjectVibrancyReport` (standalone) |
| `openProjectVibrancySettings` | — | run `saropaLints.openProjectVibrancySettings` |
| `rescan` / `restart` | — | re-run both scans (guarded by `inflight`) |
| `copyJson` | — | copy last Code Health raw stdout; "run report first" if empty |
| `copyText` | `text` | copy to clipboard, capped at 1 MB |
| `suppressFlag` | `file`, `flag` | apply a file-level Code Health suppression |

The "Open full screen" buttons are wired by id (`dashOpenPmFull`,
`dashOpenChFull`) inside the API shim. Drill-down origin differs by pane: Project
Map row clicks carry no line (open at line 1); Code Health posts `{file, line}`.

Security: messages arrive over untrusted `postMessage`. `copyText` is bounded to
1 MB so a runaway selection cannot paste a multi-megabyte string. File paths are
resolved against `lastRoot`; absolute paths are honored, relative paths joined to
root. Any new message forwarding a user-supplied string to a command must
validate it before use.

---

## 7. States and gates

- **No workspace folder** → error toast `notify.commands.projectMapNoProject`;
  no panel.
- **No `saropa_lints` dependency** → error toast
  `notify.commands.projectMapMissingDep`; no panel.
- **Scan in flight** → reveal existing panel, share the running promise.
- **Panel disposed mid-scan** → assembly is skipped (no write to a dead webview).
- **One pane fails / canceled** → that pane shows `dashboards.scanFailed`; the
  other renders normally.
- **Code Health JSON not yet available** → `copyJson` shows
  `codeHealth.runReportFirst`.

---

## 8. Content Security Policy

`default-src 'none'` with:

- `img-src ${cspSource} data:`
- `style-src ${cspSource} 'unsafe-inline'` — Code Health score pills and Project
  Map cells set color via inline `style` attributes.
- `script-src ${cspSource} 'unsafe-inline'` — the host shim plus both engines'
  inline scripts run inline under one policy (no nonce, since three inline script
  origins share the document).
- `unsafe-eval` is intentionally **absent** — nothing in the document evals.
- `${cspSource}` (scripts) covers only the vendored ECharts file in `media/`.

`localResourceRoots` is limited to `media/` (ECharts). Any new bundled resource
must be added there explicitly.

---

## 9. Internationalization

All user-facing strings route through `l10n('namespace.key')` from
[i18n/runtime](../../extension/src/i18n/runtime.ts), keyed under the `dashboards`,
`codeHealth`, and `notify.commands` namespaces, with values in
[en.json](../../extension/src/i18n/locales/en.json). Per
[.claude/rules/i18n.md](../../.claude/rules/i18n.md): no hardcoded display text,
parameter interpolation (e.g. `projectMapCouldNotOpen` takes `{file}`), and the
Saropa brand is never translated. CSS, ids, command ids, and file paths are
exempt. The fragments composed in from each engine carry their own already-keyed
strings — the hub does not re-localize them.

---

## 10. Non-goals

- **Replacing the standalone dashboards** — the hub composes them; both
  standalone commands remain the owners of their full workflows (notably the Code
  Health persisted-report-file flow, which the consolidated pane omits;
  "Open full screen" reaches it).
- **Live per-engine scan animation** in the composed view — the hub shows one
  unified loading state.
- **A saved-report file for the consolidated view** — `reportFilePath` is omitted
  from the embedded Code Health fragment.
- **Editing configuration** — that is the Config Dashboard's job (separate spec).

---

## 11. Open questions / gaps

1. **More than two panes** — the grid and API shim are hard-wired to exactly two
   engines. Adding a third (e.g. Findings) would need a generalized pane
   registry and a shim that wires N "open full screen" buttons.
2. **Partial-result caching** — both scans re-run on every `rescan`; there is no
   incremental reuse of a pane whose inputs are unchanged.
3. **Cancellation granularity** — the progress notification cancels both scans
   together; there is no per-pane cancel.
4. **Independent pane refresh** — a single failed pane cannot be retried alone;
   `rescan` re-runs both.
