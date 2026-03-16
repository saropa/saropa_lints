import {
    Problem, ProblemType, ProblemLink, ProblemSeverity,
} from './problem-types';

// Re-export convertLegacyProblem so existing callers that import from
// this module continue to work without changes.
export { convertLegacyProblem } from './problem-legacy';

/** Weight multipliers for computing priority scores. */
const SEVERITY_WEIGHTS: Record<ProblemSeverity, number> = {
    high: 30,
    medium: 20,
    low: 10,
};

/** Additional weight for specific problem types. */
const TYPE_WEIGHTS: Record<ProblemType, number> = {
    'unhealthy': 25,
    'vulnerability': 30,
    'family-conflict': 25,
    'license-risk': 20,
    'risky-transitive': 15,
    'blocked-upgrade': 10,
    'stale-override': 10,
    'unused': 5,
};

/** A package with its associated problems and priority. */
export interface PackageProblems {
    readonly package: string;
    readonly problems: readonly Problem[];
    readonly priorityScore: number;
    readonly highestSeverity: ProblemSeverity;
}

/**
 * Central registry for all problems detected during a scan.
 * Stores problems, handles deduplication, links related problems,
 * and computes priority scores.
 */
export class ProblemRegistry {
    private readonly _problems = new Map<string, Problem[]>();
    private readonly _links: ProblemLink[] = [];
    private readonly _problemById = new Map<string, Problem>();

    /**
     * Add a problem to the registry.
     * Deduplicates by (package, type) unless the problem has a unique suffix.
     */
    add(problem: Problem): void {
        const key = problem.package;
        const existing = this._problems.get(key) ?? [];

        if (!existing.some(p => p.id === problem.id)) {
            existing.push(problem);
            this._problems.set(key, existing);
            this._problemById.set(problem.id, problem);
        }
    }

    /**
     * Add multiple problems at once.
     */
    addAll(problems: readonly Problem[]): void {
        for (const problem of problems) {
            this.add(problem);
        }
    }

    /**
     * Link two problems to indicate a cause-effect relationship.
     * When the cause is resolved, the effect may also be resolved.
     */
    link(
        causeId: string,
        effectId: string,
        relationship: ProblemLink['relationship'] = 'causes',
    ): void {
        if (!this._problemById.has(causeId) || !this._problemById.has(effectId)) {
            return;
        }
        if (this._links.some(l => l.causeId === causeId && l.effectId === effectId)) {
            return;
        }
        this._links.push({ causeId, effectId, relationship });
    }

    /**
     * Get all problems for a specific package.
     */
    getForPackage(name: string): readonly Problem[] {
        return this._problems.get(name) ?? [];
    }

    /**
     * Get a problem by its ID.
     */
    getById(id: string): Problem | undefined {
        return this._problemById.get(id);
    }

    /**
     * Get all problems of a specific type.
     */
    getByType(type: ProblemType): readonly Problem[] {
        const result: Problem[] = [];
        for (const problems of this._problems.values()) {
            result.push(...problems.filter(p => p.type === type));
        }
        return result;
    }

    /**
     * Get all problems with a specific severity.
     */
    getBySeverity(severity: ProblemSeverity): readonly Problem[] {
        const result: Problem[] = [];
        for (const problems of this._problems.values()) {
            result.push(...problems.filter(p => p.severity === severity));
        }
        return result;
    }

    /**
     * Get all packages with problems, sorted by priority (highest first).
     */
    getAllSortedByPriority(): readonly PackageProblems[] {
        const packages: PackageProblems[] = [];

        for (const [pkg, problems] of this._problems) {
            if (problems.length === 0) { continue; }

            const priorityScore = this._computePriorityScore(problems);
            const highestSeverity = this._computeHighestSeverity(problems);

            packages.push({
                package: pkg,
                problems,
                priorityScore,
                highestSeverity,
            });
        }

        return packages.sort((a, b) => b.priorityScore - a.priorityScore);
    }

    /**
     * Get all packages that have problems.
     */
    getAffectedPackages(): readonly string[] {
        return Array.from(this._problems.keys()).filter(
            pkg => (this._problems.get(pkg)?.length ?? 0) > 0,
        );
    }

    /**
     * Get the resolution chain for a problem.
     * Returns other problems that would be resolved if this one is fixed.
     */
    getResolutionChain(problemId: string): readonly Problem[] {
        const resolved: Problem[] = [];
        const visited = new Set<string>();
        this._collectResolutions(problemId, resolved, visited);
        return resolved;
    }

    /**
     * Get all problems that block this problem from being resolved.
     */
    getBlockers(problemId: string): readonly Problem[] {
        return this._links
            .filter(l => l.effectId === problemId)
            .map(l => this._problemById.get(l.causeId))
            .filter((p): p is Problem => p !== undefined);
    }

    /**
     * Get total problem count.
     */
    get totalCount(): number {
        let count = 0;
        for (const problems of this._problems.values()) {
            count += problems.length;
        }
        return count;
    }

    /**
     * Get count by severity.
     */
    countBySeverity(): Record<ProblemSeverity, number> {
        const counts: Record<ProblemSeverity, number> = {
            high: 0,
            medium: 0,
            low: 0,
        };
        for (const problems of this._problems.values()) {
            for (const p of problems) {
                counts[p.severity]++;
            }
        }
        return counts;
    }

    /**
     * Get count by type.
     */
    countByType(): Partial<Record<ProblemType, number>> {
        const counts: Partial<Record<ProblemType, number>> = {};
        for (const problems of this._problems.values()) {
            for (const p of problems) {
                counts[p.type] = (counts[p.type] ?? 0) + 1;
            }
        }
        return counts;
    }

    /**
     * Clear all problems and links.
     */
    clear(): void {
        this._problems.clear();
        this._links.length = 0;
        this._problemById.clear();
    }

    /**
     * Check if the registry has any problems.
     */
    isEmpty(): boolean {
        return this._problems.size === 0;
    }

    /**
     * Export all problems as a flat array.
     */
    toArray(): readonly Problem[] {
        const all: Problem[] = [];
        for (const problems of this._problems.values()) {
            all.push(...problems);
        }
        return all;
    }

    /**
     * Get all links.
     */
    getLinks(): readonly ProblemLink[] {
        return this._links;
    }

    private _computePriorityScore(problems: readonly Problem[]): number {
        let score = 0;
        for (const p of problems) {
            score += SEVERITY_WEIGHTS[p.severity];
            score += TYPE_WEIGHTS[p.type];
        }
        return score;
    }

    private _computeHighestSeverity(problems: readonly Problem[]): ProblemSeverity {
        let highest: ProblemSeverity = 'low';
        for (const p of problems) {
            if (p.severity === 'high') { return 'high'; }
            if (p.severity === 'medium') {
                highest = 'medium';
            }
        }
        return highest;
    }

    private _collectResolutions(
        problemId: string,
        resolved: Problem[],
        visited: Set<string>,
    ): void {
        if (visited.has(problemId)) { return; }
        visited.add(problemId);

        for (const link of this._links) {
            if (link.causeId === problemId) {
                const effect = this._problemById.get(link.effectId);
                if (effect) {
                    resolved.push(effect);
                    this._collectResolutions(link.effectId, resolved, visited);
                }
            }
        }
    }
}
