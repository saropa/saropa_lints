# Extension Localization Guide (Sidebar + All Dashboards)

## Goal

Fully localize the VS Code extension package under `extension/`, including:

- Activity bar container + all sidebar sections
- Command titles and descriptions
- Settings titles/descriptions
- Walkthrough copy
- Dashboard/webview UI strings (Findings, Config, Package Vibrancy, Code Health, etc.)

This guide is intentionally implementation-ready and aligned with your existing auto-translation workflow in:

- `D:\src\contacts\scripts\build\setup_arb_translate.py`

## Execution snapshot

### Next 3 (ordered)

- [ ] **L10N-01 (P0)** Establish English sources: `package.nls.json` + runtime `en` bundle and wire `%key%` usage for manifest-visible strings.
- [ ] **L10N-02 (P0)** Migrate dashboard/runtime strings to centralized lookup (`runtime.ts`) and ban new inline user-facing literals.
- [ ] **L10N-03 (P1)** Add CI parity checks (key parity, placeholder parity, manifest key coverage) before enabling additional locales.

### Done criteria for this plan

- Manifest-visible strings are sourced from `%key%` entries with `package.nls*.json` parity.
- Webview/dashboard strings resolve through runtime i18n bundles.
- CI fails on missing keys/placeholders and manifest key drift.

### L10N-01 implementation slice (active)

- [ ] Add `extension/package.nls.json` with English keys for all manifest-visible strings.
- [ ] Replace inline manifest labels in `extension/package.json` with `%key%` references.
- [ ] Add one validation script/check that all `%key%` references resolve in `package.nls.json`.

---

## Current State (Important)

- `extension/package.json` currently stores user-facing labels inline (no `package.nls.json` yet).
- Webview strings are partially centralized in `extension/src/views/webview-strings.ts`, but many dashboards still include inline text.
- The extension has no shipping locale bundles yet (for example, no `package.nls.de.json`).

So this is both a localization **foundation setup** and a **full migration** task.

---

## Design Decision: Two Localization Layers

Use two coordinated layers because VS Code extension UX has two rendering domains:

1. **Manifest/UI chrome localization** (activity bar names, command titles, settings, walkthrough metadata):
   - Source of truth: `package.nls.json` + `package.nls.<locale>.json`
   - Referenced from `package.json` as `%key%`

2. **Webview/dashboard runtime localization** (HTML/JS rendered UI):
   - Source of truth: ARB-based catalog + generated TS bundles
   - Runtime lookup helper in webview TS code

Why this split:
- VS Code natively localizes `package.json` contributions via `package.nls*`.
- Webview HTML is your code, so you need your own runtime dictionary path.

---

## Target Locale Strategy

Mirror the translation quality/cost tiers from `setup_arb_translate.py`:

- **Primary (Gemini-paid, higher quality)**: `de, es, pt, fr, hi, id, ja, tr, it, ko, zh, ru, vi`
- **Secondary (machine translate + fallback path)**: `ar, fa, he, ur, pl, th, bn, uk, fil, sw`

This keeps extension locale coverage aligned with app locale policy and reduces operator decisions.

---

## Phase 1 - Extract and Normalize All User-Facing Strings

## 1.1 Manifest strings (package.json)

Move all visible text in `extension/package.json` into localization keys:

- `contributes.viewsContainers.activitybar[*].title`
- `contributes.views[*].name`
- `contributes.viewsWelcome[*].contents`
- `contributes.commands[*].title`
- `contributes.configuration[*].title`
- `contributes.configuration[*].properties[*].description`
- `contributes.configuration[*].properties[*].markdownDescription`
- `contributes.walkthroughs[*].title`
- `contributes.walkthroughs[*].description`
- `contributes.walkthroughs[*].steps[*].title`
- `contributes.walkthroughs[*].steps[*].description`

Example direction:
- Before: `"title": "Saropa Lints: Run Analysis"`
- After: `"title": "%command.runAnalysis.title%"`

Then add `package.nls.json` with the English values.

## 1.2 Runtime strings (webviews/sidebar labels in TS)

Create a strict string policy:

- No inline user-facing literals in webview/dashboard rendering code.
- Route all user-facing strings through a centralized lookup helper.

Recommended structure:

- `extension/src/i18n/keys.ts` (typed keys)
- `extension/src/i18n/runtime.ts` (lookup + fallback + interpolation)
- `extension/src/i18n/locales/en.json` (English base for runtime surfaces)
- Optional generated per-locale runtime bundles

Migrate existing `STRINGS` in `extension/src/views/webview-strings.ts` into the shared i18n layer (or make that file the canonical runtime source if you prefer minimal refactor).

---

## Phase 2 - Build Translation Source Format (ARB) for Automation

To reuse your existing translation pipeline, define extension translation source as ARB:

- `extension/i18n/app_en.arb` for runtime strings
- `extension/i18n/package_en.arb` for manifest strings (or one unified ARB with prefixes)

Key convention:

- `manifest.command.runAnalysis.title`
- `manifest.view.editorDashboards.name`
- `runtime.dashboard.empty.noDataMessage`
- `runtime.packageVibrancy.table.column.vulns`

Include metadata entries (`@key`) where clarifying context reduces bad MT output.

---

## Phase 3 - Reuse `setup_arb_translate.py` Safely for Extension Strings

Your script already provides the operational pieces you need:

- audited mode (`--run-mode audit`)
- quality tier run modes (`all`, `primary`, `secondary`, `machine-all`)
- locale allow/deny filters (`--locales`, `--exclude-locales`)
- dry-run planning (`--dry-run`)
- checkpoint resume (`--resume-last`)
- stale-value/fingerprint handling (`.arb_fingerprint.json` style behavior)
- artifacts/logging (`reports/<date>/<timestamp>_arb_translate.log`)

## 3.1 Recommended integration pattern

Add a thin extension-focused wrapper script (example name):

- `scripts/build/setup_extension_translate.py`

Responsibilities:

1. Copy extension ARBs into the script's expected working location (or point the pipeline to extension ARB dir if you add path support upstream).
2. Call translation with standard flags.
3. Emit:
   - `extension/package.nls.<locale>.json`
   - `extension/src/i18n/locales/<locale>.json`
4. Validate key parity and placeholder parity.
5. Write translation summary JSON for CI visibility.

This avoids polluting app ARB space while maximizing reuse.

## 3.2 Baseline run sequence

1. Preflight only:
   - `python scripts/build/setup_arb_translate.py --run-mode audit --locales de,es,fr`
2. Dry-run mutation report:
   - `python scripts/build/setup_arb_translate.py --dry-run --run-mode all`
3. Primary quality pass:
   - `python scripts/build/setup_arb_translate.py --run-mode primary`
4. Secondary cost pass:
   - `python scripts/build/setup_arb_translate.py --run-mode secondary`
5. Full fallback route (no paid):
   - `python scripts/build/setup_arb_translate.py --run-mode machine-all`

Use `--summary-json` in CI to capture machine-readable pass/fail and per-locale status.

---

## Phase 4 - Generate VS Code NLS Files and Runtime Bundles

From translated ARBs, generate:

- `extension/package.nls.json` (English)
- `extension/package.nls.<locale>.json` (translated)
- `extension/src/i18n/locales/en.json`
- `extension/src/i18n/locales/<locale>.json`

Rules:

- `package.nls*.json` must include only keys referenced by `%...%` in `package.json`.
- Runtime locale bundles can include richer keys for dashboards/webviews.
- Keep placeholders consistent (`{name}` style or your preferred interpolation syntax) across all locales.

---

## Phase 5 - Wire Runtime Locale Resolution

At extension activation:

1. Read VS Code locale (`vscode.env.language`).
2. Resolve best match (`pt-BR` -> `pt` fallback).
3. Load runtime locale bundle, fall back to `en`.
4. Pass dictionary into dashboard/webview HTML builders.

For webviews:

- Serialize locale map in the HTML payload (or expose just needed keys per view for payload size control).
- Use a tiny `t(key, params?)` helper in each webview script.

---

## Phase 6 - Quality Gates (Must-Have)

Add CI checks to prevent localization regressions:

1. **Key parity check**
   - Every locale has exactly the same keyset as English for each catalog.

2. **Placeholder parity check**
   - If English has `{count}`, all locales for that key also have `{count}`.

3. **No inline literal guard for webview/dashboard code**
   - Lint/test that rendering modules use i18n keys, not hardcoded UI text.

4. **Manifest key coverage check**
   - Every `%key%` used in `package.json` exists in `package.nls.json`.

5. **Snapshot tests per major dashboard locale**
   - At minimum: `en`, one primary locale, one secondary locale, one RTL locale.

---

## Suggested File Additions

- `extension/package.nls.json`
- `extension/package.nls.de.json` (and other locales)
- `extension/src/i18n/runtime.ts`
- `extension/src/i18n/keys.ts`
- `extension/src/i18n/locales/en.json`
- `extension/scripts/generate_nls_from_arb.ts` (or Python equivalent)
- `extension/scripts/check_i18n_parity.ts`
- `extension/scripts/check_manifest_nls.ts`

---

## Rollout Plan (Low Risk)

1. **PR 1: Foundations**
   - Add i18n runtime layer + `package.nls.json` + manifest `%key%` wiring in English only.

2. **PR 2: Sidebar + command palette + settings**
   - Move all manifest-visible text into NLS keys and verify no behavior changes.

3. **PR 3: Dashboards/webviews**
   - Migrate all dashboard text to runtime i18n keys.

4. **PR 4: Auto-translate integration**
   - Add ARB source + generation scripts + translated bundles for selected locales.

5. **PR 5: CI gates + docs**
   - Enforce parity, placeholder checks, and string-extraction policy.

---

## Definition of Done (Full Localization)

The extension is "fully localized" when all are true:

- No user-facing English literals remain hardcoded in manifest-visible fields.
- All dashboard/webview strings resolve through runtime i18n keys.
- `package.nls.<locale>.json` exists for each shipped locale.
- Runtime locale bundle exists for each shipped locale.
- CI blocks key/placeholder drift.
- RTL locales render without broken layout or placeholder corruption.
- Translation workflow supports audit, dry-run, subset locale runs, and machine-readable summary.

---

## Practical Notes from `setup_arb_translate.py` Review

The script already includes several production-grade behaviors worth preserving in extension-localization automation:

- Single-instance locking and recovery (`tmp/setup_arb_translate.lock` + resume flow)
- Strong preflight visibility for untranslated/missing slots
- Structured run modes by cost/quality intent
- Detailed transcript logs under dated `reports/` paths
- Dry-run support to validate mutating steps before writing files

If you reuse these primitives for extension catalogs, you will get a robust pipeline immediately instead of rebuilding translation orchestration from scratch.
