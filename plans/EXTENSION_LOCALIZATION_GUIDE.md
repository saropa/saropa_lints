# Extension Localization Guide (Sidebar + All Dashboards)

## Goal

Fully localize the VS Code extension package under `extension/`, including:

- Activity bar container + all sidebar sections
- Command titles and descriptions
- Settings titles/descriptions
- Walkthrough copy
- Dashboard/webview UI strings (Findings, Config, Package Vibrancy, Code Health, etc.)

This guide is intentionally implementation-ready. Optional alignment with an external ARB/Gemini pipeline (`setup_arb_translate.py`) is documented below; **this repository ships a JSON + dictionary generator** instead (see Phase 2–4).

## Execution snapshot

### Status (2026-05-08)

| Track | Status | Notes |
|-------|--------|--------|
| **L10N-01** Manifest NLS | **Done** | `extension/package.json` uses `%key%`; `extension/package.nls.json` is the English source; `extension/package.nls.<locale>.json` shipped for the default locale set; local guard `npm run verify-nls-keys` (runs `extension/scripts/verify-manifest-nls-keys.mjs`). |
| **L10N-02** Runtime webviews | **Done** (shipped set) | Findings / triage dashboards, keyboard overlay, full-width toggle, command catalog webview, Package Vibrancy `report-html.ts`, and wide-report host strings use `t()` + `en.json`; non-English catalogs are regenerated via `generate_locales.py` (dictionary + optional `SAROPA_I18N_MACHINE_TRANSLATE`). **Shipped runtime + manifest locales (24):** `ar, bn, de, es, fa, fil, fr, he, hi, id, it, ja, ko, nl, pl, pt, ru, sw, th, tr, uk, ur, vi, zh` (matches primary + secondary tiers in [Target locale strategy](#target-locale-strategy), plus `nl`). New locale files default to English until you run the generator with machine translation enabled. |
| **L10N-03** CI quality gates | **Partial** | **CI runs manifest key coverage** (`node extension/scripts/verify-manifest-nls-keys.mjs` on every push/PR). Locale key parity, placeholder parity, and “no inline literals” lint are **not** automated yet; use `python extension/scripts/i18n/audit_coverage.py` locally for coverage reports. |

### Next work (ordered)

1. **Dashboard migration** — Route remaining webview/dashboard literals through `runtime.ts` keys (prioritize high-traffic surfaces: Findings / violations HTML).
2. **Locale expansion** — Add missing locales vs [Target locale strategy](#target-locale-strategy) (e.g. `id`, `tr`, `vi`, secondary tier); extend `extension/scripts/i18n/dictionaries.py` + `generate_locales.py`.
3. **Stronger CI** — Add automated key/placeholder parity across `package.nls*.json` and `locales/*.json`; optional ESLint/custom check for new inline UI strings in `extension/src/views/`.

### Done criteria for this plan

- [x] Manifest-visible strings are sourced from `%key%` entries with `package.nls.json` (English) and translated `package.nls.<locale>.json` where shipped.
- [ ] Webview/dashboard strings resolve through runtime i18n keys **everywhere** (no residual inline user-facing literals in dashboard HTML builders).
- [x] CI fails when a `%key%` in `package.json` is missing from `package.nls.json`.
- [ ] CI fails on locale key/placeholder drift (pending).

---

## Current state (authoritative)

- **Manifest:** User-facing contributed strings live behind `%…%` keys; English text is in `extension/package.nls.json`.
- **Runtime:** JSON catalogs under `extension/src/i18n/locales/` are loaded by `runtime.ts`; regenerate non-English files with `python extension/scripts/i18n/generate_locales.py` after editing English or `dictionaries.py` (see `extension/scripts/i18n/README.md`).
- **Gaps:** Not every locale from the target tier list is shipped; some smaller webviews may still contain literals — run `python extension/scripts/i18n/audit_coverage.py` for a heuristic report.

---

## CI and contributor workflow

- After editing `extension/package.json` contributed labels or `extension/package.nls.json`, run under `extension/`: **`npm run verify-nls-keys`** (or from repo root: **`node extension/scripts/verify-manifest-nls-keys.mjs`**).
- **GitHub Actions** (`ci.yml`, job `extension-manifest-nls`) runs the same manifest check so missing keys fail CI before merge.

---

## Design Decision: Two Localization Layers

Use two coordinated layers because VS Code extension UX has two rendering domains:

1. **Manifest/UI chrome localization** (activity bar names, command titles, settings, walkthrough metadata):
   - Source of truth: `package.nls.json` + `package.nls.<locale>.json`
   - Referenced from `package.json` as `%key%`

2. **Webview/dashboard runtime localization** (HTML/JS rendered UI):
   - Source of truth: **`extension/src/i18n/locales/en.json`** plus generated **`extension/src/i18n/locales/<locale>.json`** (Python `generate_locales.py` + `dictionaries.py`). An ARB export path remains optional for parity with external translation tooling (Phase 2).
   - Runtime lookup: **`extension/src/i18n/runtime.ts`** (`t`, `format`, locale normalization).

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

## Phase 2 - Translation source format (implemented: JSON; optional ARB)

**Shipped in this repo:** English runtime strings live in **`extension/src/i18n/locales/en.json`**; manifest English strings live in **`extension/package.nls.json`**. Locale files are produced by **`extension/scripts/i18n/generate_locales.py`** (see `extension/scripts/i18n/README.md`).

**Optional future:** To reuse an external ARB-based translation pipeline, define extension translation source as ARB:

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

## Phase 4 - Generate VS Code NLS files and runtime bundles

From English JSON sources (today via **`python extension/scripts/i18n/generate_locales.py`**; alternatively from translated ARBs if Phase 2 ARB path is adopted), emit:

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

## Phase 6 - Quality gates

CI and local checks to prevent localization regressions:

1. **Key parity check** — *Todo.* Every shipped locale should share the same keyset as English for each catalog (`package.nls.*` and runtime `locales/*.json`). Use **`python extension/scripts/i18n/audit_coverage.py`** for a markdown report; automate in CI when stable.

2. **Placeholder parity check** — *Todo.* If English has `{count}`, every locale for that key must include the same placeholders.

3. **No inline literal guard for webview/dashboard code** — *Todo.* Lint or review rule so new UI strings go through i18n keys.

4. **Manifest key coverage check** — **Done in CI.** Every `%key%` used in `extension/package.json` exists in `extension/package.nls.json` (`extension-manifest-nls` job in `.github/workflows/ci.yml`; local: `npm run verify-nls-keys` in `extension/`).

5. **Snapshot tests per major dashboard locale** — *Todo.* At minimum: `en`, one primary locale, one secondary locale, one RTL locale.

---

## Repository files (reference)

| Path | Role |
|------|------|
| `extension/package.nls.json` | English manifest strings |
| `extension/package.nls.<locale>.json` | Translated manifest strings |
| `extension/scripts/verify-manifest-nls-keys.mjs` | Manifest `%key%` → `package.nls.json` CI/local guard |
| `extension/src/i18n/runtime.ts` | Runtime `t` / `format`, locale catalogs |
| `extension/src/i18n/locales/en.json` | English runtime catalog |
| `extension/src/i18n/locales/<locale>.json` | Translated runtime catalogs |
| `extension/scripts/i18n/generate_locales.py` | Regenerate locale JSON from English + dictionaries |
| `extension/scripts/i18n/dictionaries.py` | Per-locale phrase translations |
| `extension/scripts/i18n/audit_coverage.py` | Coverage / gap report (`extension/reports/i18n_coverage_report.md`) |

Optional later: typed keys (`keys.ts`), dedicated parity scripts, or ARB export/import helpers.

---

## Rollout plan (status)

1. **Foundations** — Done: `runtime.ts`, `locales/en.json`, `package.nls.json`, `%key%` manifest wiring.

2. **Sidebar + command palette + settings** — Done: contributed strings use NLS keys.

3. **Dashboards/webviews** — In progress: migrate remaining inline dashboard HTML/TS strings to runtime keys.

4. **Locale generation** — Done for default set: `generate_locales.py` + `dictionaries.py`; expand locales toward [target list](#target-locale-strategy).

5. **CI gates + docs** — Partial: manifest NLS check in CI; parity / placeholder / literal guards still open (see [Phase 6](#phase-6---quality-gates)).

---

## Definition of done (full localization)

The extension meets the **full** bar when all are true:

- [x] No user-facing English literals remain in manifest-visible fields (NLS keys + translated `package.nls.<locale>.json` per shipped locale).
- [ ] All dashboard/webview strings resolve through runtime i18n keys (manifest done; large HTML builders still in flight — see [Execution snapshot](#execution-snapshot)).
- [ ] `package.nls.<locale>.json` and matching runtime `locales/<locale>.json` exist for each **target** locale you commit to ship (see [Target locale strategy](#target-locale-strategy)).
- [ ] CI blocks locale key/placeholder drift (manifest-only coverage today).
- [ ] RTL locales validated for layout and placeholders.
- [ ] Optional: translation workflow with audit/dry-run (`audit_coverage.py` locally; ARB/Gemini bridge remains optional per Phase 2–3).

---

## Practical Notes from `setup_arb_translate.py` Review

The script already includes several production-grade behaviors worth preserving in extension-localization automation:

- Single-instance locking and recovery (`tmp/setup_arb_translate.lock` + resume flow)
- Strong preflight visibility for untranslated/missing slots
- Structured run modes by cost/quality intent
- Detailed transcript logs under dated `reports/` paths
- Dry-run support to validate mutating steps before writing files

If you reuse these primitives for extension catalogs, you will get a robust pipeline immediately instead of rebuilding translation orchestration from scratch.
