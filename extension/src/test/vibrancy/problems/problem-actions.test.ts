import * as assert from 'assert';
import {
    determineBestAction, calculateResolutionChain, getUnlockedPackages,
    findHighPriorityActions, formatAction, actionIcon,
    Problem, ProblemRegistry, generateProblemId,
    UnhealthyPackageProblem, UnusedProblem, BlockedUpgradeProblem,
    FamilyConflictProblem, StaleOverrideProblem, RiskyTransitiveProblem,
    VulnerabilityProblem, LicenseRiskProblem,
} from '../../../vibrancy/problems';

function makeUnhealthyProblem(name: string): UnhealthyPackageProblem {
    return {
        id: generateProblemId(name, 'unhealthy'),
        type: 'unhealthy',
        package: name,
        severity: 'high',
        line: 10,
        score: 5,
        category: 'end-of-life',
    };
}

function makeUnusedProblem(name: string): UnusedProblem {
    return {
        id: generateProblemId(name, 'unused'),
        type: 'unused',
        package: name,
        severity: 'low',
        line: 10,
    };
}

function makeBlockedProblem(name: string, blocker: string): BlockedUpgradeProblem {
    return {
        id: generateProblemId(name, 'blocked-upgrade'),
        type: 'blocked-upgrade',
        package: name,
        severity: 'medium',
        line: 10,
        currentVersion: '1.0.0',
        latestVersion: '2.0.0',
        blockerPackage: blocker,
        blockerScore: 50,
    };
}

function makeFamilyConflictProblem(
    name: string,
    familyLabel: string,
    conflicting: string[],
): FamilyConflictProblem {
    return {
        id: generateProblemId(name, 'family-conflict'),
        type: 'family-conflict',
        package: name,
        severity: 'high',
        line: 10,
        familyId: familyLabel.toLowerCase(),
        familyLabel,
        currentMajor: 2,
        conflictingPackages: conflicting,
    };
}

function makeStaleOverrideProblem(name: string): StaleOverrideProblem {
    return {
        id: generateProblemId(name, 'stale-override'),
        type: 'stale-override',
        package: name,
        severity: 'low',
        line: 10,
        overrideName: name,
        ageDays: 30,
    };
}

function makeRiskyTransitiveProblem(name: string): RiskyTransitiveProblem {
    return {
        id: generateProblemId(name, 'risky-transitive'),
        type: 'risky-transitive',
        package: name,
        severity: 'medium',
        line: 10,
        flaggedCount: 2,
        flaggedTransitives: ['bad_dep', 'old_dep'],
    };
}

function makeVulnerabilityProblem(
    name: string,
    vulnId: string,
    fixedVersion: string | null,
): VulnerabilityProblem {
    return {
        id: generateProblemId(name, 'vulnerability', vulnId),
        type: 'vulnerability',
        package: name,
        severity: 'high',
        line: 10,
        vulnId,
        vulnSeverity: 'high',
        summary: 'A security vulnerability',
        fixedVersion,
    };
}

function makeLicenseRiskProblem(name: string): LicenseRiskProblem {
    return {
        id: generateProblemId(name, 'license-risk'),
        type: 'license-risk',
        package: name,
        severity: 'medium',
        line: 10,
        license: 'GPL-3.0',
        riskLevel: 'copyleft',
    };
}

describe('determineBestAction', () => {
    it('should return none for empty problems', () => {
        const action = determineBestAction([], []);
        assert.strictEqual(action.type, 'none');
    });

    it('should suggest fix-vulnerability for vulnerability with fix', () => {
        const problems: Problem[] = [
            makeVulnerabilityProblem('pkg', 'CVE-2024-1234', '2.0.0'),
        ];
        const action = determineBestAction(problems, []);

        assert.strictEqual(action.type, 'fix-vulnerability');
        assert.ok(action.description.includes('2.0.0'));
    });

    it('should suggest remove for unused + unhealthy', () => {
        const problems: Problem[] = [
            makeUnhealthyProblem('pkg'),
            makeUnusedProblem('pkg'),
        ];
        const action = determineBestAction(problems, []);

        assert.strictEqual(action.type, 'remove');
        assert.ok(action.description.includes('unused'));
        assert.ok(action.description.includes('unhealthy'));
    });

    it('should suggest remove for unused only', () => {
        const problems: Problem[] = [makeUnusedProblem('pkg')];
        const action = determineBestAction(problems, []);

        assert.strictEqual(action.type, 'remove');
        assert.ok(action.description.includes('no imports'));
    });

    it('should suggest upgrade-blocker for blocked upgrade', () => {
        const problems: Problem[] = [
            makeBlockedProblem('pkg', 'blocker_pkg'),
        ];
        const action = determineBestAction(problems, []);

        assert.strictEqual(action.type, 'upgrade-blocker');
        assert.ok(action.description.includes('blocker_pkg'));
    });

    it('should suggest upgrade-family for family conflict', () => {
        const problems: Problem[] = [
            makeFamilyConflictProblem('firebase_core', 'Firebase', ['firebase_auth']),
        ];
        const action = determineBestAction(problems, []);

        assert.strictEqual(action.type, 'upgrade-family');
        assert.ok(action.description.includes('Firebase'));
    });

    it('should suggest remove-override for stale override', () => {
        const problems: Problem[] = [makeStaleOverrideProblem('pkg')];
        const action = determineBestAction(problems, []);

        assert.strictEqual(action.type, 'remove-override');
    });

    it('should suggest replace for unhealthy with alternatives', () => {
        const problems: Problem[] = [makeUnhealthyProblem('pkg')];
        const action = determineBestAction(problems, ['better_pkg']);

        assert.strictEqual(action.type, 'replace');
        assert.ok(action.description.includes('better_pkg'));
    });

    it('should suggest upgrade for risky transitive', () => {
        const problems: Problem[] = [makeRiskyTransitiveProblem('pkg')];
        const action = determineBestAction(problems, []);

        assert.strictEqual(action.type, 'upgrade');
        assert.ok(action.description.includes('safer transitive'));
    });

    it('should suggest review-license for license risk', () => {
        const problems: Problem[] = [makeLicenseRiskProblem('pkg')];
        const action = determineBestAction(problems, []);

        assert.strictEqual(action.type, 'review-license');
        assert.ok(action.description.includes('GPL-3.0'));
    });

    it('should prioritize vulnerability over other problems', () => {
        const problems: Problem[] = [
            makeUnusedProblem('pkg'),
            makeVulnerabilityProblem('pkg', 'CVE-2024-1234', '2.0.0'),
        ];
        const action = determineBestAction(problems, []);

        assert.strictEqual(action.type, 'fix-vulnerability');
    });
});

describe('calculateResolutionChain', () => {
    it('should return empty for package with no linked problems', () => {
        const registry = new ProblemRegistry();
        registry.add(makeUnhealthyProblem('pkg'));

        const chain = calculateResolutionChain('pkg', registry);
        assert.strictEqual(chain.length, 0);
    });

    it('should return actions for linked problems', () => {
        const registry = new ProblemRegistry();
        const blocker = makeUnhealthyProblem('blocker');
        const blocked = makeBlockedProblem('blocked', 'blocker');

        registry.add(blocker);
        registry.add(blocked);
        registry.link(blocker.id, blocked.id, 'blocks');

        const chain = calculateResolutionChain('blocker', registry);
        assert.strictEqual(chain.length, 1);
        assert.ok(chain[0].targetPackages.includes('blocked'));
    });
});

describe('getUnlockedPackages', () => {
    it('should return empty for package with no linked problems', () => {
        const registry = new ProblemRegistry();
        registry.add(makeUnhealthyProblem('pkg'));

        const unlocked = getUnlockedPackages('pkg', registry);
        assert.strictEqual(unlocked.length, 0);
    });

    it('should return packages that would be unblocked', () => {
        const registry = new ProblemRegistry();
        const blocker = makeUnhealthyProblem('blocker');
        const blocked = makeBlockedProblem('blocked', 'blocker');

        registry.add(blocker);
        registry.add(blocked);
        registry.link(blocker.id, blocked.id, 'blocks');

        const unlocked = getUnlockedPackages('blocker', registry);
        assert.strictEqual(unlocked.length, 1);
        assert.strictEqual(unlocked[0], 'blocked');
    });
});

describe('findHighPriorityActions', () => {
    it('should return sorted high-priority actions', () => {
        const registry = new ProblemRegistry();
        registry.add(makeUnusedProblem('low_priority'));
        registry.add(makeVulnerabilityProblem('high_priority', 'CVE-2024-1234', '2.0.0'));

        const actions = findHighPriorityActions(registry, 10);
        assert.strictEqual(actions.length, 2);
        assert.strictEqual(actions[0].type, 'fix-vulnerability');
    });

    it('should respect limit', () => {
        const registry = new ProblemRegistry();
        registry.add(makeUnusedProblem('pkg1'));
        registry.add(makeUnusedProblem('pkg2'));
        registry.add(makeUnusedProblem('pkg3'));

        const actions = findHighPriorityActions(registry, 2);
        assert.strictEqual(actions.length, 2);
    });
});

describe('formatAction', () => {
    it('should format action with single problem', () => {
        const action = determineBestAction([makeUnusedProblem('pkg')], []);
        const formatted = formatAction(action);

        assert.ok(formatted.includes('Remove'));
    });

    it('should format action with multiple resolved problems', () => {
        const problems: Problem[] = [
            makeUnusedProblem('pkg'),
            makeUnhealthyProblem('pkg'),
        ];
        const action = determineBestAction(problems, []);
        const formatted = formatAction(action);

        assert.ok(formatted.includes('2 problems') || formatted.includes('resolves'));
    });
});

describe('actionIcon', () => {
    it('should return appropriate icons', () => {
        assert.strictEqual(actionIcon('remove'), '🗑️');
        assert.strictEqual(actionIcon('upgrade'), '⬆️');
        assert.strictEqual(actionIcon('fix-vulnerability'), '🛡️');
        assert.strictEqual(actionIcon('none'), '💡');
    });
});
