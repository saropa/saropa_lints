/**
 * CSS for the **Rule explain** editor webview (`ruleExplainView.ts`).
 *
 * Body / hero / button / status-line styling all come from the shared chrome
 * (`getDashboardChromeStyles()`) — this stylesheet only adds patterns the chrome
 * does not own: the inset detail-card section block (§7.2), the OWASP definition
 * list (§7.2), and the link-hover underline (§8.2).
 *
 * Previously this file shipped its own `body`, `h1`, `h2/h3`, and `.meta` rules
 * that overrode the chrome and broke the body max-width / full-width-toggle
 * (§4) and the gold-standard h-hierarchy (§8.1). Those overrides are gone;
 * the panel now inherits the same chrome the Findings / Code Health
 * dashboards use.
 */
export function getRuleExplainPanelStyles(): string {
    return `
    /* §7.2 / §14.6 — section.block is an inset detail card, not a flat
       top-bordered band. Layered surface depth lets the eye separate the
       hero from the section bodies without relying on heading weight alone. */
    section.block {
      margin: 0 0 12px 0;
      padding: 12px 14px;
      border: 1px solid var(--border);
      border-radius: 6px;
      background: var(--surface-2);
    }
    section.block h4 {
      margin: 0 0 6px 0;
      font-size: 0.92em;
      font-weight: 600;
      letter-spacing: 0.2px;
      color: var(--muted);
      text-transform: uppercase;
    }
    section.block p {
      margin: 0;
      white-space: pre-wrap;
      word-break: break-word;
    }
    /* §7.2 — OWASP label/value pairs as a definition list. The grid keeps
       *Mobile* / *Web* labels aligned with their values regardless of value
       length. */
    .owasp-dl {
      display: grid;
      grid-template-columns: max-content 1fr;
      gap: 4px 12px;
      margin: 0;
    }
    .owasp-dl dt {
      font-weight: 600;
      color: var(--muted);
    }
    .owasp-dl dd { margin: 0; word-break: break-word; }
    /* External links: no underline by default, underline on hover. */
    a {
      color: var(--vscode-textLink-foreground);
      text-decoration: none;
    }
    a:hover {
      color: var(--vscode-textLink-activeForeground);
      text-decoration: underline;
    }
    /* Inline rule-name links inside section blocks read better as monospace
       chips than as plain text — they are rule identifiers, not prose. */
    section.block code {
      font-family: var(--vscode-editor-font-family, ui-monospace, monospace);
      font-size: 0.92em;
    }
  `;
}
