# Plan — Embed Package Dashboard deep-link tabs as inline content

**Created:** 2026-09-05 · **Status:** Not started
**Parent:** `PLAN_ext_ui_redesign.md` Phase 5 deferred item
**Scope:** TS-only, extension side. No Dart changes.
**Model:** Sonnet for implementation.

---

## 1. Problem

The Package Dashboard has 6 tabs. Overview and Settings render their content natively in the
same webview document. The other four (Upgrades, Full report, Known issues, Compare) are
"deep-link cards" — each shows a description and an "Open" button that launches a separate
standalone webview panel. Clicking a tab should show content inline, not open a new editor tab.

## 2. The `acquireVsCodeApi()` constraint

VS Code enforces that `acquireVsCodeApi()` may be called **exactly once** per webview document.
Each of the four standalone panels calls it in its own `<script>`. Inlining their HTML verbatim
into the Package Dashboard document would trigger a second call and throw.

## 3. Proven pattern: `getEmbeddedBodyHtml`

The Analysis Optimizer was embedded into Rules & Tiers using this exact approach:

1. The standalone provider exposes `getEmbeddedBodyHtml()` — returns only the body fragment
   (no `<!DOCTYPE>`, no `<html>`, no `acquireVsCodeApi()` call).
2. The host dashboard calls it inside a `<section>` wrapper.
3. The host dashboard's single inline `<script>` forwards optimizer-related messages to
   `handleEmbeddedMessage()`, which mirrors the standalone's own `onDidReceiveMessage`.
4. The embedded content shares the host's single `vscode` API instance.

## 4. Per-tab audit and work

### Tab 3: Upgrades (`opportunities-html.ts`, 301 lines)

- Produces a full `<!DOCTYPE html>` document. Calls `acquireVsCodeApi()`.
- **Work:** Extract a `getEmbeddedBodyHtml()` that returns the body content without the
  document shell or API call. Add `handleEmbeddedMessage()` for the upgrade/apply/dismiss
  actions. Wire into `packages-tabs.ts` as an inline panel instead of a deep link.

### Tab 4: Full report (`feature-inventory-html.ts`, 103 lines)

- Produces a full `<!DOCTYPE html>` but does **NOT** call `acquireVsCodeApi()` — this is a
  browser-opened report written to `reports/`, not a webview panel.
- **Work:** This is the simplest embed. Extract the body content into an `getEmbeddedBodyHtml()`.
  No message forwarding needed (it has no webview interactions). It may need to be reworked
  to use `--vscode-*` CSS tokens instead of its own stylesheet (it was designed for browser
  display, not in-editor rendering).

### Tab 5: Known issues (`known-issues-html.ts`, 406 lines)

- Produces a full `<!DOCTYPE html>` document. Calls `acquireVsCodeApi()`.
- **Work:** Same pattern as Upgrades — extract body, add message handler, wire as inline panel.

### Tab 6: Compare (`comparison-html.ts`, 489 lines)

- Produces a full `<!DOCTYPE html>` document. Calls `acquireVsCodeApi()` **twice** (two
  separate `<script>` blocks / builder functions).
- **Work:** The most complex embed. Must consolidate the two script blocks into one and
  extract a single `getEmbeddedBodyHtml()`. The comparison view has the most interactive
  state (package selection, diff rendering, metric highlighting).

## 5. Implementation order

1. **Full report** (simplest — no `acquireVsCodeApi`, no message forwarding)
2. **Upgrades** (moderate — standard embed pattern)
3. **Known issues** (moderate — same pattern as Upgrades)
4. **Compare** (hardest — dual script consolidation, most interactive state)

Each tab is independently shippable. The deep-link card is the fallback for any tab not yet
embedded — no big-bang cutover.

## 6. Files touched per tab

| File | Change |
|---|---|
| `vibrancy/views/{target}-html.ts` | Add `getEmbeddedBodyHtml()` + `handleEmbeddedMessage()` |
| `vibrancy/views/packages-tabs.ts` | Replace the deep-link card with inline content call |
| `vibrancy/views/report-webview.ts` | Add message forwarding for the embedded tab's messages |
| `vibrancy/views/report-script-parts.ts` | Add client-side script for the embedded tab |
| `i18n/locales/en.json` | Any new l10n keys for inline UI (unlikely — reusing existing) |

## 7. Verification checklist (per tab)

- [ ] `tsc --noEmit` clean
- [ ] Standalone panel still works (regression — the `getEmbeddedBodyHtml` extraction must
      not break the standalone path)
- [ ] Embedded tab renders correctly inside the Package Dashboard
- [ ] All message-based interactions work (apply, dismiss, navigate, etc.)
- [ ] Keyboard navigation works within the embedded tab
- [ ] `npm run ux:gen && npm run ux:test --workers=2` passes
- [ ] Extension Dev Host visual check (dark + light theme)

## 8. Estimate

- Full report: < 1 hour (Sonnet)
- Upgrades: 1 session (Sonnet)
- Known issues: 1 session (Sonnet)
- Compare: 1-2 sessions (Sonnet)
- Total: ~2-3 sessions across 1-2 days

## 9. Risks

- **CSP nonce collision:** The embedded content must NOT inject its own `<style nonce="...">` or
  `<script nonce="...">` — it shares the host's nonce. Each `getEmbeddedBodyHtml()` must strip
  any nonce-bearing tags and return only the body markup; styles go into the host's single
  `<style>` block via a `getEmbeddedStyles()` companion.
- **DOM id collisions:** Each embedded panel's ids must be unique within the host document.
  Prefix with the tab id (e.g., `upgrades-*`, `compare-*`).
- **Comparison's dual scripts:** Consolidating two `acquireVsCodeApi()` calls and their separate
  state into one shared message handler is the highest-risk work item. If it proves too
  entangled, keep Compare as a deep-link card and embed the other three.
