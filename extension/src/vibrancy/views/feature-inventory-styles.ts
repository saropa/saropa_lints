/**
 * Self-contained stylesheet for the Package Feature Inventory report.
 *
 * The report is written to `reports/` and opened in a BROWSER, not in a webview,
 * so it cannot reference `--vscode-*` theme variables the way the in-editor
 * panels do — every color is defined here, with a `prefers-color-scheme: dark`
 * override so the file is readable in either OS theme without a toggle.
 *
 * Split out of the renderer purely to keep both files under the size limit.
 */

/** Palette plus base document rules. */
function getBaseStyles(): string {
    return `
        :root {
            --fi-bg: #ffffff; --fi-fg: #1f2328; --fi-muted: #59636e;
            --fi-border: #d1d9e0; --fi-panel: #f6f8fa; --fi-link: #0969da;
            --fi-warn-bg: #fff8c5; --fi-warn-fg: #6b5900; --fi-warn-border: #d4a72c;
            --fi-unused-bg: #ffebe9; --fi-unused-fg: #8b1c13;
            --fi-unknown-bg: #eceef1; --fi-unknown-fg: #4a5057;
            --fi-adopted-bg: #dafbe1; --fi-adopted-fg: #0a5227;
            --fi-partial-bg: #fff1e5; --fi-partial-fg: #7a4100;
        }
        @media (prefers-color-scheme: dark) {
            :root {
                --fi-bg: #0d1117; --fi-fg: #e6edf3; --fi-muted: #9198a1;
                --fi-border: #30363d; --fi-panel: #161b22; --fi-link: #4493f8;
                --fi-warn-bg: #2d2000; --fi-warn-fg: #f0d47a; --fi-warn-border: #9e6a03;
                --fi-unused-bg: #3d1513; --fi-unused-fg: #ffb3ac;
                --fi-unknown-bg: #21262d; --fi-unknown-fg: #b6bec7;
                --fi-adopted-bg: #0f2f1b; --fi-adopted-fg: #7ee2a8;
                --fi-partial-bg: #3a2408; --fi-partial-fg: #f0b47a;
            }
        }
        * { box-sizing: border-box; }
        body {
            margin: 0; padding: 0 24px 64px;
            background: var(--fi-bg); color: var(--fi-fg);
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            font-size: 14px; line-height: 1.5;
        }
        a { color: var(--fi-link); }
        code, .fi-mono { font-family: ui-monospace, SFMono-Regular, Consolas, monospace; font-size: 0.9em; }
        h1 { font-size: 1.6em; margin: 24px 0 4px; }
        h2 { font-size: 1.2em; margin: 24px 0 8px; }
    `;
}

/** Header, caveat callout, controls, and package index. */
function getHeaderStyles(): string {
    return `
        .fi-meta { color: var(--fi-muted); margin: 0 0 4px; }
        .fi-caveats {
            border: 1px solid var(--fi-warn-border); background: var(--fi-warn-bg);
            color: var(--fi-warn-fg); border-radius: 6px; padding: 12px 16px; margin: 16px 0;
        }
        .fi-caveats h2 { margin: 0 0 6px; font-size: 1em; }
        .fi-caveats ul { margin: 0; padding-inline-start: 20px; }
        .fi-controls {
            display: flex; flex-wrap: wrap; gap: 8px; align-items: center;
            position: sticky; top: 0; z-index: 3; padding: 10px 0;
            background: var(--fi-bg); border-bottom: 1px solid var(--fi-border);
        }
        .fi-controls input[type="search"] {
            flex: 1 1 220px; min-width: 180px; padding: 5px 8px;
            border: 1px solid var(--fi-border); border-radius: 6px;
            background: var(--fi-panel); color: var(--fi-fg);
        }
        .fi-btn {
            border: 1px solid var(--fi-border); border-radius: 6px; cursor: pointer;
            padding: 5px 10px; background: var(--fi-panel); color: var(--fi-fg); font-size: 0.9em;
        }
        .fi-btn[aria-pressed="true"] { background: var(--fi-link); color: #ffffff; border-color: var(--fi-link); }
        .fi-index { display: flex; flex-wrap: wrap; gap: 6px; margin: 12px 0 4px; }
        .fi-index a { text-decoration: none; border: 1px solid var(--fi-border); border-radius: 12px; padding: 1px 10px; }
        .fi-hidden { display: none !important; }
    `;
}

/** Summary table, package/category/feature disclosures, chips, usage lists. */
function getBodyStyles(): string {
    return `
        .fi-table { border-collapse: collapse; width: 100%; margin: 8px 0 24px; }
        .fi-table th, .fi-table td { border-bottom: 1px solid var(--fi-border); padding: 6px 10px; text-align: right; }
        .fi-table th:first-child, .fi-table td:first-child,
        .fi-table th:nth-child(2), .fi-table td:nth-child(2) { text-align: left; }
        .fi-table thead th {
            position: sticky; top: 52px; z-index: 2; cursor: pointer;
            background: var(--fi-panel); border-bottom: 2px solid var(--fi-border); white-space: nowrap;
        }
        .fi-table tbody tr:hover { background: var(--fi-panel); }
        .fi-package, .fi-category, .fi-feature, .fi-overflow {
            border: 1px solid var(--fi-border); border-radius: 6px; margin: 8px 0; background: var(--fi-bg);
        }
        .fi-package > summary { padding: 8px 12px; font-weight: 600; cursor: pointer; background: var(--fi-panel); border-radius: 6px; }
        .fi-category > summary, .fi-feature > summary, .fi-overflow > summary { padding: 6px 10px; cursor: pointer; }
        .fi-package-body, .fi-category-body, .fi-feature-body { padding: 4px 12px 12px; }
        .fi-desc { color: var(--fi-muted); margin: 4px 0 8px; }
        .fi-note {
            border-inline-start: 3px solid var(--fi-warn-border);
            background: var(--fi-panel); padding: 8px 12px; margin: 8px 0; color: var(--fi-muted);
        }
        .fi-chip { border-radius: 10px; padding: 1px 8px; font-size: 0.78em; white-space: nowrap; margin-inline-start: 6px; }
        .fi-chip-unused { background: var(--fi-unused-bg); color: var(--fi-unused-fg); border: 1px solid var(--fi-unused-fg); }
        .fi-chip-unmeasurable { background: var(--fi-unknown-bg); color: var(--fi-unknown-fg); border: 1px dashed var(--fi-unknown-fg); }
        .fi-chip-adopted { background: var(--fi-adopted-bg); color: var(--fi-adopted-fg); border: 1px solid var(--fi-adopted-fg); }
        .fi-chip-partial { background: var(--fi-partial-bg); color: var(--fi-partial-fg); border: 1px solid var(--fi-partial-fg); }
        .fi-api-links { margin: 6px 0; }
        .fi-usages { margin: 4px 0 0; padding-inline-start: 18px; }
        .fi-usages li { margin: 2px 0; }
        .fi-snippet { color: var(--fi-muted); }
        .fi-empty { color: var(--fi-muted); font-style: italic; }
    `;
}

/** Full stylesheet, injected once into the report document. */
export function getFeatureInventoryStyles(): string {
    return getBaseStyles() + getHeaderStyles() + getBodyStyles();
}
