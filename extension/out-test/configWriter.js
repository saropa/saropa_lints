"use strict";
/**
 * I2: Read/write rule overrides in analysis_options_custom.yaml.
 * Modifies only the RULE OVERRIDES section; other sections are untouched.
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.readRuleOverrides = readRuleOverrides;
exports.countDisabledOverrides = countDisabledOverrides;
exports.writeRuleOverrides = writeRuleOverrides;
exports.removeRuleOverrides = removeRuleOverrides;
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const CUSTOM_FILENAME = 'analysis_options_custom.yaml';
const OVERRIDES_MARKER = '# RULE OVERRIDES';
const OVERRIDES_SECTION_HEADER = `
# ${'\u2500'.repeat(77)}
# RULE OVERRIDES
# ${'\u2500'.repeat(77)}
# FORMAT: rule_name: true/false
# Add your custom rule overrides below:

`;
/** Regex to match a rule entry: `rule_name: true` or `rule_name: false`. */
function ruleEntryPattern(ruleName) {
    return new RegExp(`^(\\s*${ruleName}:\\s*)(true|false)`, 'm');
}
/** Read rule overrides from the RULE OVERRIDES section. */
function readRuleOverrides(root) {
    const filePath = path.join(root, CUSTOM_FILENAME);
    const overrides = new Map();
    if (!fs.existsSync(filePath))
        return overrides;
    const content = fs.readFileSync(filePath, 'utf-8');
    const markerIdx = content.indexOf(OVERRIDES_MARKER);
    if (markerIdx < 0)
        return overrides;
    // Only parse lines after the marker to avoid matching platform/package entries.
    const section = content.slice(markerIdx);
    const entryPattern = /^\s*([\w_]+):\s*(true|false)/gm;
    let match;
    while ((match = entryPattern.exec(section)) !== null) {
        overrides.set(match[1], match[2] === 'true');
    }
    return overrides;
}
/** Count rules explicitly set to false in overrides. */
function countDisabledOverrides(root) {
    let count = 0;
    for (const enabled of readRuleOverrides(root).values()) {
        if (!enabled)
            count += 1;
    }
    return count;
}
/**
 * Write rule overrides to the RULE OVERRIDES section.
 * Updates existing entries within the overrides section in-place;
 * appends new entries at end of file. Does not modify stylistic or other sections.
 */
function writeRuleOverrides(root, overrides) {
    if (overrides.length === 0)
        return;
    const filePath = path.join(root, CUSTOM_FILENAME);
    let content = fs.existsSync(filePath) ? fs.readFileSync(filePath, 'utf-8') : '';
    // Ensure the RULE OVERRIDES section exists.
    if (!content.includes(OVERRIDES_MARKER)) {
        content = content.trimEnd() + '\n' + OVERRIDES_SECTION_HEADER;
    }
    const markerIdx = content.indexOf(OVERRIDES_MARKER);
    const before = content.slice(0, markerIdx);
    let after = content.slice(markerIdx);
    for (const { rule, enabled } of overrides) {
        const pattern = ruleEntryPattern(rule);
        const value = enabled ? 'true' : 'false';
        if (pattern.test(after)) {
            // Update existing entry within the overrides section.
            after = after.replace(pattern, `$1${value}`);
        }
        else {
            // Append new entry at end of overrides section (end of file).
            after = after.trimEnd() + `\n${rule}: ${value}\n`;
        }
    }
    fs.writeFileSync(filePath, before + after, 'utf-8');
}
/**
 * Remove rule overrides (revert to tier default).
 * Only removes entries in the RULE OVERRIDES section to avoid modifying
 * stylistic or other sections that use the same key: value format.
 */
function removeRuleOverrides(root, ruleNames) {
    if (ruleNames.length === 0)
        return;
    const filePath = path.join(root, CUSTOM_FILENAME);
    if (!fs.existsSync(filePath))
        return;
    const content = fs.readFileSync(filePath, 'utf-8');
    const markerIdx = content.indexOf(OVERRIDES_MARKER);
    if (markerIdx < 0)
        return; // No overrides section — nothing to remove.
    // Only modify lines after the RULE OVERRIDES marker.
    const before = content.slice(0, markerIdx);
    let after = content.slice(markerIdx);
    for (const rule of ruleNames) {
        const linePattern = new RegExp(`^\\s*${rule}:\\s*(true|false).*\\n?`, 'm');
        after = after.replace(linePattern, '');
    }
    fs.writeFileSync(filePath, before + after, 'utf-8');
}
//# sourceMappingURL=configWriter.js.map