"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.VibrancyFilterManager = exports.ALL_SECTIONS = exports.ALL_CATEGORIES = exports.ALL_PROBLEM_TYPES = exports.ALL_SEVERITIES = void 0;
/** All known problem severities for filter defaults. */
exports.ALL_SEVERITIES = ['high', 'medium', 'low'];
/** All known problem types for filter defaults. */
exports.ALL_PROBLEM_TYPES = [
    'unhealthy', 'vulnerability', 'family-conflict', 'risky-transitive',
    'blocked-upgrade', 'unused', 'license-risk', 'stale-override',
];
/** All known vibrancy categories for filter defaults. */
exports.ALL_CATEGORIES = [
    'vibrant', 'quiet', 'legacy-locked', 'stale', 'end-of-life',
];
/** All known dependency sections for filter defaults. */
exports.ALL_SECTIONS = [
    'dependencies', 'dev_dependencies', 'transitive',
];
/**
 * Manages filter state for the unified vibrancy tree.
 *
 * Defaults have all values enabled (= no filtering).
 * Setting a filter narrows the visible set.
 */
class VibrancyFilterManager {
    _textFilter = '';
    _viewMode = 'all';
    _severityFilter = new Set(['high', 'medium', 'low']);
    _problemTypeFilter = new Set(exports.ALL_PROBLEM_TYPES);
    _categoryFilter = new Set(exports.ALL_CATEGORIES);
    _sectionFilter = new Set(exports.ALL_SECTIONS);
    _filteredCount = 0;
    _totalCount = 0;
    /** Set text filter (case-insensitive substring). Returns true if changed. */
    setTextFilter(value) {
        const trimmed = value.trim();
        if (trimmed === this._textFilter) {
            return false;
        }
        this._textFilter = trimmed;
        return true;
    }
    /** Set view mode. Returns true if changed. */
    setViewMode(mode) {
        if (mode === this._viewMode) {
            return false;
        }
        this._viewMode = mode;
        return true;
    }
    /** Set severity filter. Returns true if changed. */
    setSeverityFilter(severities) {
        if (setsEqual(this._severityFilter, severities)) {
            return false;
        }
        this._severityFilter = new Set(severities);
        return true;
    }
    /** Set problem type filter. Returns true if changed. */
    setProblemTypeFilter(types) {
        if (setsEqual(this._problemTypeFilter, types)) {
            return false;
        }
        this._problemTypeFilter = new Set(types);
        return true;
    }
    /** Set health category filter. Returns true if changed. */
    setCategoryFilter(categories) {
        if (setsEqual(this._categoryFilter, categories)) {
            return false;
        }
        this._categoryFilter = new Set(categories);
        return true;
    }
    /** Set dependency section filter. Returns true if changed. */
    setSectionFilter(sections) {
        if (setsEqual(this._sectionFilter, sections)) {
            return false;
        }
        this._sectionFilter = new Set(sections);
        return true;
    }
    /** Reset all filters to defaults. */
    clearAll() {
        this._textFilter = '';
        this._viewMode = 'all';
        this._severityFilter = new Set(['high', 'medium', 'low']);
        this._problemTypeFilter = new Set(exports.ALL_PROBLEM_TYPES);
        this._categoryFilter = new Set(exports.ALL_CATEGORIES);
        this._sectionFilter = new Set(exports.ALL_SECTIONS);
        this._filteredCount = 0;
        this._totalCount = 0;
    }
    /** Get a snapshot of the current filter state. */
    getState() {
        return {
            textFilter: this._textFilter,
            viewMode: this._viewMode,
            severityFilter: this._severityFilter,
            problemTypeFilter: this._problemTypeFilter,
            categoryFilter: this._categoryFilter,
            sectionFilter: this._sectionFilter,
            hasActiveFilters: this._hasActiveFilters(),
            filteredCount: this._filteredCount,
            totalCount: this._totalCount,
        };
    }
    /**
     * Filter results using the current filter state.
     * Updates filteredCount/totalCount as a side-effect.
     */
    filterResults(results, registry) {
        this._totalCount = results.length;
        const filtered = results.filter(r => this._matchesResult(r, registry));
        this._filteredCount = filtered.length;
        return filtered;
    }
    _matchesResult(result, registry) {
        const name = result.package.name;
        // Text filter: case-insensitive substring match on package name
        if (this._textFilter
            && !name.toLowerCase().includes(this._textFilter.toLowerCase())) {
            return false;
        }
        // Section filter
        if (!this._sectionFilter.has(result.package.section)) {
            return false;
        }
        // Category filter
        if (!this._categoryFilter.has(result.category)) {
            return false;
        }
        const problems = registry.getForPackage(name);
        // Problems-only mode: hide packages with no problems
        if (this._viewMode === 'problems-only' && problems.length === 0) {
            return false;
        }
        // Severity filter: if package has problems, at least one must pass.
        // Packages with no problems always pass the severity filter.
        if (problems.length > 0
            && !this._isFullSeveritySet()
            && !problems.some(p => this._severityFilter.has(p.severity))) {
            return false;
        }
        // Problem type filter: if package has problems, at least one must pass.
        // Packages with no problems always pass the type filter.
        if (problems.length > 0
            && !this._isFullProblemTypeSet()
            && !problems.some(p => this._problemTypeFilter.has(p.type))) {
            return false;
        }
        return true;
    }
    _hasActiveFilters() {
        if (this._textFilter.length > 0) {
            return true;
        }
        if (this._viewMode !== 'all') {
            return true;
        }
        if (!this._isFullSeveritySet()) {
            return true;
        }
        if (!this._isFullProblemTypeSet()) {
            return true;
        }
        if (this._categoryFilter.size < exports.ALL_CATEGORIES.length) {
            return true;
        }
        if (this._sectionFilter.size < exports.ALL_SECTIONS.length) {
            return true;
        }
        return false;
    }
    _isFullSeveritySet() {
        return this._severityFilter.size >= 3;
    }
    _isFullProblemTypeSet() {
        return this._problemTypeFilter.size >= exports.ALL_PROBLEM_TYPES.length;
    }
}
exports.VibrancyFilterManager = VibrancyFilterManager;
/** Check if two sets have identical contents. */
function setsEqual(a, b) {
    if (a.size !== b.size) {
        return false;
    }
    for (const v of a) {
        if (!b.has(v)) {
            return false;
        }
    }
    return true;
}
//# sourceMappingURL=vibrancy-filter-state.js.map