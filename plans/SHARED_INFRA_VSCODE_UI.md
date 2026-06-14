# Shared infra: `saropa-vscode-ui`

**Created:** 2026-06-14
**Status:** Plan only — no code moved. Cross-repo extraction; needs sign-off on the dependency
mechanism (a blast-radius move) before any file leaves a repo.
**Parent:** the "Shared infrastructure" section of `plans/SAROPA_SUITE_INTEGRATION.md` (and the identical
Section 7 in the two sibling docs). This doc is the detailed extraction plan for the webview UI kit.

## What it is

A reusable webview/dashboard kit for the three Saropa VS Code extensions: theme tokens, the
shell-once + postMessage rendering pattern, and the small primitives every dashboard rebuilds (CSP
nonce, HTML escaping, JSON-for-script-block, KPI cards, sortable tables, sparklines, focus rings,
skip-links). One kit so a "fixed color washes out in light/high-contrast" fix lands once, not three
times.

## Why extract (the convergence evidence)

All three extensions shipped the same building blocks and the same class of bug:

- Webview HTML helpers — `createWebviewCspNonce`, `escapeHtml`, `jsonForScriptBlock`,
  `resolveRepoUrl`. Here: `extension/src/vibrancy/views/html-utils.ts`.
- The "shell set exactly once, patch the DOM from `model` messages" architecture — see
  `extension/src/views/consolidated/{consolidatedView,consolidatedClient}.ts` and its decomposed
  section builders (`plans/CENTRAL_DASHBOARD_CONSOLIDATION.md`).
- Theme-token-first styling: every color a `--vscode-*` token with a fallback, so the surface tracks
  light / dark / high-contrast. Here: `extension/src/views/consolidated/consolidatedStyles.ts`,
  `extension/src/vibrancy/views/{report-styles,detail-view-styles,chart-styles,pill-button-styles}.ts`.
- Reusable pieces already split out in this repo: pill buttons, chart (sparkline) html/script/styles,
  detail-view section builders, comparison tables.

Lints already decomposed its dashboards into reusable section builders, so it is the natural seed. All
three repos independently hit and fixed the same "fixed color invisible in the opposite theme" defect —
the strongest signal that the styling layer belongs in one place.

## What gets extracted

1. **Primitives (TS):** `html-utils.ts` (CSP nonce, escape, script-block JSON, repo-url), the theme
   token set, and the shared focus-ring / skip-link / accessibility helpers.
2. **Dashboard kit (TS):** the shell-once webview scaffold, the `model`/`occurrences` message
   contract, KPI-card / sortable-table / sparkline builders, and the section-builder pattern from the
   consolidated dashboard and Package Vibrancy report.
3. **Style tokens:** the `--vscode-*`-first variable layer and the severity/grade color scale, so a
   contrast fix is made once.

## Non-goals

- **Not shared view models.** Each extension keeps its own data model and message payloads; the kit
  provides the rendering scaffold and primitives, not the domain content.
- **Not a component framework.** No React/Lit dependency — these are string-building webview helpers,
  matching the current zero-runtime-dependency approach.
- **Not a monorepo merge.** Extensions stay independently publishable.

## Dependency mechanism (decision needed)

Recommendation: **git submodule** pinned per consumer, same as the i18n package — the kit is pure TS
bundled into each extension by esbuild, so a path import from a pinned submodule bundles cleanly and an
upgrade is a deliberate SHA bump. Keeping i18n and UI on the same mechanism avoids two patterns for the
same kind of internal shared code.

Alternatives considered:
- **Published npm package** — cleaner semver, but adds an internal publish step and a registry
  dependency for code only these three repos consume.
- **`git+https` npm dependency** — floats to branch tip; no pin discipline.

## Migration steps (per consumer)

1. Create `saropa-vscode-ui`; seed it from Lints' `html-utils.ts`, the consolidated dashboard
   scaffold, the style-token layer, and the chart/pill/section builders.
2. Add as a submodule to Lints first; repoint imports; confirm the webview tests
   (`consolidatedClient`, `report-html`, `detail-view-html`, `html-utils`, snapshot harness) and the
   axe/light/dark/high-contrast checks pass.
3. Repeat for Drift Advisor, then Log Capture, discarding each repo's forked copy.

## Risks

- **Snapshot/HTML test coupling.** Several tests assert exact webview HTML; moving builders must keep
  the output byte-stable or update the snapshots deliberately (not silently).
- **Theme-token regressions.** The whole point is one contrast fix for all three — verify light / dark
  / high-contrast rendering after the move, the exact bug class this kit exists to prevent.
- **esbuild bundling of a submodule path** — confirm the bundle resolves the kit before deleting the
  in-repo copies.

## Related

- Parent: `plans/SAROPA_SUITE_INTEGRATION.md` (shared-infra section)
- Siblings: `plans/SHARED_INFRA_VSCODE_I18N.md`, `plans/SHARED_INFRA_RELEASE_TOOLS.md`
- Internal: `plans/CENTRAL_DASHBOARD_CONSOLIDATION.md` (the section-builder decomposition that seeds this kit)
