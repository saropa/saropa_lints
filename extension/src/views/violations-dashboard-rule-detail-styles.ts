/**
 * CSS for the Rule Explain fold-in (`violations-dashboard-rule-detail.ts`) —
 * the how-to-fix / OWASP / related-rules content appended inside a Top-Rules
 * expander row. Split into its own file rather than growing
 * `violationsDashboardStylesParts.ts` further (already well past the
 * project's 200-line-per-file guidance; this keeps the new, reviewable-as-one
 * unit of CSS out of that pre-existing debt instead of adding to it).
 *
 * Class names reuse the `.owasp-dl` / `.related-rule` vocabulary from
 * `ruleExplainPanelStyles.ts` for definition-list and rule-chip styling so the
 * folded-in content looks like the SAME design element the standalone panel
 * uses, not a reinvented look — `.related-rule-link` is a distinct class
 * (not `.related-rule`) only because this table row context needs a slightly
 * tighter chip than the full-page panel.
 */
export function vdsRuleDetailExtras(): string {
  return `
    /* Rule Explain fold — appended after the existing message/files content
       inside a Top-Rules detail row's .trd-body. */
    .top-rules-table .trd-extra { margin-top: 4px; }
    .top-rules-table .trd-sub { margin: 10px 0 0; }
    .top-rules-table .trd-sub:first-child { margin-top: 0; }
    .top-rules-table .trd-sub h4 {
      margin: 0 0 4px;
      font-size: .82em;
      letter-spacing: .3px;
      text-transform: uppercase;
      color: var(--muted);
      font-weight: 600;
    }
    .top-rules-table .trd-sub p { margin: 0; line-height: 1.45; }

    /* OWASP mapping as a definition list — label/value pairs, not prose
       paragraphs (matches ruleExplainPanelStyles.ts's §7.2 pattern). */
    .top-rules-table .owasp-dl {
      display: grid;
      grid-template-columns: max-content 1fr;
      column-gap: 10px;
      row-gap: 2px;
      margin: 0;
    }
    .top-rules-table .owasp-dl dt { color: var(--muted); font-weight: 600; }
    .top-rules-table .owasp-dl dd { margin: 0; word-break: break-word; }

    /* Related/same-tag/supersedes rule chips — clickable, open the standalone
       Rule Explain panel for that OTHER rule (see violations-dashboard-script.ts). */
    .top-rules-table .related-rule-link {
      color: var(--link);
      text-decoration: none;
    }
    .top-rules-table .related-rule-link:hover,
    .top-rules-table .related-rule-link:focus-visible {
      text-decoration: underline;
    }
    .top-rules-table .related-rule-link code {
      font-family: var(--vscode-editor-font-family, monospace);
      font-size: .95em;
    }
  `;
}
