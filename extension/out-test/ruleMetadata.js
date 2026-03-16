"use strict";
/**
 * Rule metadata for tooltips and docs. Used by the Issues tree violation tooltip (W3).
 * Optional short descriptions can be added here; otherwise tooltip shows rule name + link.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.RULE_DOC_BASE_URL = void 0;
exports.getRuleDescription = getRuleDescription;
exports.getRuleDocUrl = getRuleDocUrl;
/** Base URL for rule documentation (ROADMAP and repo). */
exports.RULE_DOC_BASE_URL = 'https://github.com/saropa/saropa_lints/blob/main/ROADMAP.md';
/**
 * Optional one-line description for a rule. Returns undefined if not known.
 * Extension can ship a small map; for now we rely on message + "More" link.
 */
function getRuleDescription(_ruleName) {
    return undefined;
}
/**
 * URL to point users to rule documentation (ROADMAP or search).
 * @param _ruleName Reserved for future rule-specific anchors/fragments.
 */
function getRuleDocUrl(_ruleName) {
    return exports.RULE_DOC_BASE_URL;
}
//# sourceMappingURL=ruleMetadata.js.map