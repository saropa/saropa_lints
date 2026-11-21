# Rate Us / Review Prompt — Porting Guide

Portable pattern for asking VS Code extension users to rate and review the extension
on both the VS Code Marketplace and Open VSX Registry, plus surface feedback/issue links.
Designed to be copied to other Saropa extensions with minimal changes.

## What it does

Three surfaces, one nudge:

1. **Scan-gated notification toast** — after N successful scans (default 2), shows an
   info message with buttons for both stores + "Report an issue" + "Don't ask again".
   Uses `globalState` so it fires once per machine. "Not now" defers to a higher
   threshold (N+10 more scans). Respects the proactive-nudge opt-out setting.

2. **Help Hub entries** — two always-available rows in the Help quick pick:
   "Rate on VS Code Marketplace" and "Rate on Open VSX" with `$(star-full)` icons.

3. **Welcome panel CTA** — a visually prominent gradient card with animated star
   accents, three buttons (Marketplace, Open VSX, GitHub Issues), positioned between
   the discovery grid and the show-next-time checkbox. Emphasizes the extension is
   **free and open source**.

## Files to copy / adapt

| File | What to change |
|------|---------------|
| `src/ratePrompt.ts` | Update `MARKETPLACE_REVIEW_URL` and `OPEN_VSX_REVIEW_URL` with the correct publisher/extension-id. Update `INITIAL_SCAN_THRESHOLD` and `DEFERRED_SCAN_INCREMENT` if the extension has a different usage cadence. |
| `src/i18n/locales/en.json` → `rate.*` keys | Update copy to match the extension's voice. The GitHub issues URL is in `welcomePanel.ts`, not in en.json. |
| `src/views/welcomePanel-html.ts` → `buildRateCta()` | Copy the function. Update the GitHub Issues URL in the data-action handler. |
| `src/views/welcomePanel-styles.ts` → `.welcome-rate-*` classes | Copy the CSS block. Uses chrome tokens (`--accent-good`, `--accent-info`, `--surface-2`, `--border`, `--muted`) — works in any dashboard that imports `getDashboardChromeStyles()`. |
| `src/views/welcomePanel.ts` | Add `rateMarketplace`, `rateOpenVsx`, `openGitHubIssues` message types and handlers. |
| `src/views/helpHub.ts` | Add two entries with `$(star-full)` icon. |
| `src/views/commandCatalogEntriesMisc.ts` | Add two catalog entries. |
| `package.json` → `contributes.commands` | Register `rateOnMarketplace` and `rateOnOpenVsx` commands. |
| `package.nls.json` | Add `command.rateOnMarketplace.title` and `command.rateOnOpenVsx.title`. |
| `extension.ts` | Import `maybePromptForRating` + URLs. Register the two commands. Call `maybePromptForRating(context)` after a successful scan/analysis completion. |

## Store review URLs

Format for each store:

- **VS Code Marketplace:**
  `https://marketplace.visualstudio.com/items?itemName=<publisher>.<extension-id>&ssr=false#review-details`
- **Open VSX:**
  `https://open-vsx.org/extension/<publisher>/<extension-id>/reviews`

Replace `<publisher>` and `<extension-id>` from `package.json`.

## globalState keys used

| Key | Type | Purpose |
|-----|------|---------|
| `saropaLints.rate.dismissed` | boolean | Permanently suppress the toast (rated or opted out) |
| `saropaLints.rate.scanCount` | number | Cumulative scans since install |
| `saropaLints.rate.deferred` | number | Number of "Not now" deferrals (raises the threshold) |

When porting, rename the `saropaLints.rate.` prefix to match the extension's namespace.

## Open source messaging

The copy explicitly states the extension is free and open source. This is intentional —
users are more likely to rate a project they know is community-driven and non-commercial.
The welcome panel CTA headline reads "Free, open source, and built for the community"
and the toast mentions "free and open source" before asking for a rating. Keep this
framing when porting to other Saropa extensions (all are open source).

## Nudge behavior

- **Threshold:** 2 scans before first prompt. Each "Not now" adds 10 more scans.
- **"Don't ask again":** permanently suppresses via globalState.
- **Proactive-nudge opt-out:** respects `upgradePackNudge.enabled === false` (shared
  with upgrade-pack and suite nudges). Adapt the config key to the target extension.
- **No re-prompt after rating:** clicking either store button sets `dismissed = true`.
- **Thread-safe:** writes `dismissed` before showing the toast so concurrent activations
  cannot double-prompt.

## Testing

- Help hub test (`helpHub.test.ts`) validates the command count — update the assertion
  when adding/removing entries.
- The nudge module exports `MARKETPLACE_REVIEW_URL` and `OPEN_VSX_REVIEW_URL` as
  constants so the welcome panel can import them without duplicating the URLs.
- Type-check with `npx tsc --noEmit -p .` and `npx tsc -p tsconfig.test.json`.
