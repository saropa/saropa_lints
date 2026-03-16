"use strict";
/**
 * Persist and load view suppressions (hidden folders, files, rules) for the Issues tree.
 * Stored in workspace state so they survive reload.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.DEFAULT_SUPPRESSIONS = void 0;
exports.loadSuppressions = loadSuppressions;
exports.saveSuppressions = saveSuppressions;
exports.addHiddenFolder = addHiddenFolder;
exports.addHiddenFile = addHiddenFile;
exports.addHiddenRule = addHiddenRule;
exports.addHiddenRuleInFile = addHiddenRuleInFile;
exports.addHiddenSeverity = addHiddenSeverity;
exports.addHiddenImpact = addHiddenImpact;
exports.clearSuppressions = clearSuppressions;
exports.isPathHidden = isPathHidden;
exports.isRuleHidden = isRuleHidden;
const KEY = 'saropaLints.suppressions';
exports.DEFAULT_SUPPRESSIONS = {
    hiddenFolders: [],
    hiddenFiles: [],
    hiddenRules: [],
    hiddenRuleInFile: {},
    hiddenSeverities: [],
    hiddenImpacts: [],
};
function loadSuppressions(workspaceState) {
    const raw = workspaceState.get(KEY);
    if (!raw || typeof raw !== 'object')
        return { ...exports.DEFAULT_SUPPRESSIONS };
    const o = raw;
    return {
        hiddenFolders: Array.isArray(o.hiddenFolders) ? o.hiddenFolders : [],
        hiddenFiles: Array.isArray(o.hiddenFiles) ? o.hiddenFiles : [],
        hiddenRules: Array.isArray(o.hiddenRules) ? o.hiddenRules : [],
        hiddenRuleInFile: o.hiddenRuleInFile && typeof o.hiddenRuleInFile === 'object' && !Array.isArray(o.hiddenRuleInFile)
            ? o.hiddenRuleInFile
            : {},
        hiddenSeverities: Array.isArray(o.hiddenSeverities) ? o.hiddenSeverities : [],
        hiddenImpacts: Array.isArray(o.hiddenImpacts) ? o.hiddenImpacts : [],
    };
}
function saveSuppressions(workspaceState, s) {
    void workspaceState.update(KEY, s);
}
function addHiddenFolder(s, folderPath) {
    const normalized = folderPath.replace(/\\/g, '/').replace(/\/$/, '') || '/';
    if (s.hiddenFolders.includes(normalized))
        return s;
    return { ...s, hiddenFolders: [...s.hiddenFolders, normalized].sort() };
}
function addHiddenFile(s, filePath) {
    const normalized = filePath.replace(/\\/g, '/');
    if (s.hiddenFiles.includes(normalized))
        return s;
    return { ...s, hiddenFiles: [...s.hiddenFiles, normalized].sort() };
}
function addHiddenRule(s, rule) {
    if (s.hiddenRules.includes(rule))
        return s;
    return { ...s, hiddenRules: [...s.hiddenRules, rule].sort() };
}
function addHiddenRuleInFile(s, filePath, rule) {
    const normalized = filePath.replace(/\\/g, '/');
    const existing = s.hiddenRuleInFile[normalized] ?? [];
    if (existing.includes(rule))
        return s;
    return {
        ...s,
        hiddenRuleInFile: { ...s.hiddenRuleInFile, [normalized]: [...existing, rule].sort() },
    };
}
function addHiddenSeverity(s, severity) {
    if (s.hiddenSeverities.includes(severity))
        return s;
    return { ...s, hiddenSeverities: [...s.hiddenSeverities, severity] };
}
function addHiddenImpact(s, impact) {
    if (s.hiddenImpacts.includes(impact))
        return s;
    return { ...s, hiddenImpacts: [...s.hiddenImpacts, impact] };
}
function clearSuppressions() {
    return { ...exports.DEFAULT_SUPPRESSIONS };
}
/** True if file path is hidden by folder prefix or file/glob suppression. Globs match full path. */
function isPathHidden(s, filePath) {
    const normalized = filePath.replace(/\\/g, '/');
    for (const folder of s.hiddenFolders) {
        if (folder === '/' && normalized.length > 0)
            continue;
        if (normalized === folder || normalized.startsWith(folder + '/'))
            return true;
    }
    if (s.hiddenFiles.includes(normalized))
        return true;
    for (const pattern of s.hiddenFiles) {
        if (pattern.includes('*') && simpleGlobMatch(pattern, normalized))
            return true;
    }
    return false;
}
/** True if rule is hidden globally or in this file. */
function isRuleHidden(s, filePath, rule) {
    if (s.hiddenRules.includes(rule))
        return true;
    const normalized = filePath.replace(/\\/g, '/');
    const fileRules = s.hiddenRuleInFile[normalized];
    return Array.isArray(fileRules) && fileRules.includes(rule);
}
function simpleGlobMatch(pattern, path) {
    const parts = pattern.split('*');
    if (parts.length === 1)
        return path === pattern;
    let remaining = path;
    for (let i = 0; i < parts.length; i++) {
        const p = parts[i];
        if (p === '')
            continue;
        const idx = remaining.indexOf(p);
        if (idx < 0)
            return false;
        remaining = remaining.slice(idx + p.length);
    }
    return true;
}
//# sourceMappingURL=suppressionsStore.js.map