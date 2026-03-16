import { ProblemSeverity, ProblemType } from '../problems/problem-types';
import { ProblemRegistry } from '../problems/problem-registry';
import { VibrancyCategory, DependencySection, VibrancyResult } from '../types';

/** View modes for the unified package tree. */
export type VibrancyViewMode = 'all' | 'problems-only';

/** All known problem types for filter defaults. */
const ALL_PROBLEM_TYPES: readonly ProblemType[] = [
    'unhealthy', 'vulnerability', 'family-conflict', 'risky-transitive',
    'blocked-upgrade', 'unused', 'license-risk', 'stale-override',
];

/** All known vibrancy categories for filter defaults. */
const ALL_CATEGORIES: readonly VibrancyCategory[] = [
    'vibrant', 'quiet', 'legacy-locked', 'end-of-life',
];

/** All known dependency sections for filter defaults. */
const ALL_SECTIONS: readonly DependencySection[] = [
    'dependencies', 'dev_dependencies', 'transitive',
];

/** Snapshot of the current filter state. */
export interface VibrancyFilterState {
    readonly textFilter: string;
    readonly viewMode: VibrancyViewMode;
    readonly severityFilter: ReadonlySet<ProblemSeverity>;
    readonly problemTypeFilter: ReadonlySet<ProblemType>;
    readonly categoryFilter: ReadonlySet<VibrancyCategory>;
    readonly sectionFilter: ReadonlySet<DependencySection>;
    readonly hasActiveFilters: boolean;
    readonly filteredCount: number;
    readonly totalCount: number;
}

/**
 * Manages filter state for the unified vibrancy tree.
 *
 * Defaults have all values enabled (= no filtering).
 * Setting a filter narrows the visible set.
 */
export class VibrancyFilterManager {
    private _textFilter = '';
    private _viewMode: VibrancyViewMode = 'all';
    private _severityFilter = new Set<ProblemSeverity>(['high', 'medium', 'low']);
    private _problemTypeFilter = new Set<ProblemType>(ALL_PROBLEM_TYPES);
    private _categoryFilter = new Set<VibrancyCategory>(ALL_CATEGORIES);
    private _sectionFilter = new Set<DependencySection>(ALL_SECTIONS);
    private _filteredCount = 0;
    private _totalCount = 0;

    /** Set text filter (case-insensitive substring). Returns true if changed. */
    setTextFilter(value: string): boolean {
        const trimmed = value.trim();
        if (trimmed === this._textFilter) { return false; }
        this._textFilter = trimmed;
        return true;
    }

    /** Set view mode. Returns true if changed. */
    setViewMode(mode: VibrancyViewMode): boolean {
        if (mode === this._viewMode) { return false; }
        this._viewMode = mode;
        return true;
    }

    /** Set severity filter. Returns true if changed. */
    setSeverityFilter(severities: ReadonlySet<ProblemSeverity>): boolean {
        if (setsEqual(this._severityFilter, severities)) { return false; }
        this._severityFilter = new Set(severities);
        return true;
    }

    /** Set problem type filter. Returns true if changed. */
    setProblemTypeFilter(types: ReadonlySet<ProblemType>): boolean {
        if (setsEqual(this._problemTypeFilter, types)) { return false; }
        this._problemTypeFilter = new Set(types);
        return true;
    }

    /** Set health category filter. Returns true if changed. */
    setCategoryFilter(categories: ReadonlySet<VibrancyCategory>): boolean {
        if (setsEqual(this._categoryFilter, categories)) { return false; }
        this._categoryFilter = new Set(categories);
        return true;
    }

    /** Set dependency section filter. Returns true if changed. */
    setSectionFilter(sections: ReadonlySet<DependencySection>): boolean {
        if (setsEqual(this._sectionFilter, sections)) { return false; }
        this._sectionFilter = new Set(sections);
        return true;
    }

    /** Reset all filters to defaults. */
    clearAll(): void {
        this._textFilter = '';
        this._viewMode = 'all';
        this._severityFilter = new Set(['high', 'medium', 'low']);
        this._problemTypeFilter = new Set(ALL_PROBLEM_TYPES);
        this._categoryFilter = new Set(ALL_CATEGORIES);
        this._sectionFilter = new Set(ALL_SECTIONS);
        this._filteredCount = 0;
        this._totalCount = 0;
    }

    /** Get a snapshot of the current filter state. */
    getState(): VibrancyFilterState {
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
    filterResults(
        results: readonly VibrancyResult[],
        registry: ProblemRegistry,
    ): VibrancyResult[] {
        this._totalCount = results.length;
        const filtered = results.filter(
            r => this._matchesResult(r, registry),
        );
        this._filteredCount = filtered.length;
        return filtered;
    }

    private _matchesResult(
        result: VibrancyResult,
        registry: ProblemRegistry,
    ): boolean {
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

    private _hasActiveFilters(): boolean {
        if (this._textFilter.length > 0) { return true; }
        if (this._viewMode !== 'all') { return true; }
        if (!this._isFullSeveritySet()) { return true; }
        if (!this._isFullProblemTypeSet()) { return true; }
        if (this._categoryFilter.size < ALL_CATEGORIES.length) { return true; }
        if (this._sectionFilter.size < ALL_SECTIONS.length) { return true; }
        return false;
    }

    private _isFullSeveritySet(): boolean {
        return this._severityFilter.size >= 3;
    }

    private _isFullProblemTypeSet(): boolean {
        return this._problemTypeFilter.size >= ALL_PROBLEM_TYPES.length;
    }
}

/** Check if two sets have identical contents. */
function setsEqual<T>(a: ReadonlySet<T>, b: ReadonlySet<T>): boolean {
    if (a.size !== b.size) { return false; }
    for (const v of a) {
        if (!b.has(v)) { return false; }
    }
    return true;
}
