# Rule Explain panel: script leak and dead ROADMAP link

Opening a rule in the extension's Rule Explain detail panel rendered a wall of raw
JavaScript instead of the rule's documentation, and its "View in ROADMAP" button
did nothing. Both symptoms shared one root cause in the panel's inline script;
the button additionally pointed at a documentation page that no longer exists.

## Finish Report (2026-06-23)

### Defect 1 — Inline script terminated early, dumping source as page text

The Rule Explain webview builds its page as a template literal that includes an
inline `<script>` block. A code comment inside that block contained a literal
closing-script-tag sequence — ironically, in the comment that explained why such
sequences must be escaped in injected data. Because the comment text is emitted
verbatim into the generated HTML, the browser's HTML parser treated that literal
sequence as the end of the script block. Everything after it — the remaining
script source and trailing markup — was parsed as visible text content, producing
the observed wall of JavaScript.

The existing `jsonForScriptBlock()` guard escapes the *data* value (the rule name)
but never touched the source comment, so the guard could not prevent this.

Fix: reworded the comment in `src/views/ruleExplainView.ts` to describe the
closing-tag sequence without writing it literally, plus a note warning future
editors not to reintroduce the raw sequence into emitted script text.

### Defect 2 — Dead "View in ROADMAP" link

The panel rendered a Documentation section with a "View in ROADMAP" button that
posted an `openUrl` message resolving to `RULE_DOC_BASE_URL`
(`ROADMAP.md` on the repo's main branch). `ROADMAP.md` is now a nine-line
redirect stub whose content moved to the `plans/` folder; it holds no per-rule
documentation. `getRuleDocUrl()` also ignores the rule name, so the link only
ever opened the top of that stub. The button additionally appeared non-functional
because its click handler was registered by the same inline script broken in
Defect 1.

Fix: removed the Documentation section, the "View in ROADMAP" anchor, the
`doc-link` click handler, the now-dead `openUrl` message handler, the unused
`getRuleDocUrl` import and `docUrl` local in `ruleExplainView.ts`, and the
orphaned `.doc-link.btn` CSS in `ruleExplainPanelStyles.ts`. `getRuleDocUrl`
itself remains — it is still consumed by `issuesTree.ts` and `suite/envelope.ts`.

### Tests

`test/views/ruleExplainHtml.test.ts` previously asserted the panel rendered the
`doc-link btn` button, the `View in ROADMAP` text, and an `<h4>Documentation</h4>`
heading. Those assertions were updated to pin the new behavior: the panel must
NOT render `doc-link` or `View in ROADMAP`, and the heading test now checks the
`Related rules` subsection instead. Compiled with `tsc -p tsconfig.test.json`
(exit 0) and ran the single file via mocha — 5 passing.

### Scope

VS Code extension (TypeScript) and CHANGELOG only. No Dart lint rules, no
`en.json` strings (the removed copy was hardcoded English, never localized).
