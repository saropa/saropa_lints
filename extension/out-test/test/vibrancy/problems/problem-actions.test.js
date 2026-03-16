"use strict";
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
const assert = __importStar(require("assert"));
const problems_1 = require("../../../vibrancy/problems");
function makeUnhealthyProblem(name) {
    return {
        id: (0, problems_1.generateProblemId)(name, 'unhealthy'),
        type: 'unhealthy',
        package: name,
        severity: 'high',
        line: 10,
        score: 5,
        category: 'end-of-life',
    };
}
function makeUnusedProblem(name) {
    return {
        id: (0, problems_1.generateProblemId)(name, 'unused'),
        type: 'unused',
        package: name,
        severity: 'low',
        line: 10,
    };
}
function makeBlockedProblem(name, blocker) {
    return {
        id: (0, problems_1.generateProblemId)(name, 'blocked-upgrade'),
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
function makeFamilyConflictProblem(name, familyLabel, conflicting) {
    return {
        id: (0, problems_1.generateProblemId)(name, 'family-conflict'),
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
function makeStaleOverrideProblem(name) {
    return {
        id: (0, problems_1.generateProblemId)(name, 'stale-override'),
        type: 'stale-override',
        package: name,
        severity: 'low',
        line: 10,
        overrideName: name,
        ageDays: 30,
    };
}
function makeRiskyTransitiveProblem(name) {
    return {
        id: (0, problems_1.generateProblemId)(name, 'risky-transitive'),
        type: 'risky-transitive',
        package: name,
        severity: 'medium',
        line: 10,
        flaggedCount: 2,
        flaggedTransitives: ['bad_dep', 'old_dep'],
    };
}
function makeVulnerabilityProblem(name, vulnId, fixedVersion) {
    return {
        id: (0, problems_1.generateProblemId)(name, 'vulnerability', vulnId),
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
function makeLicenseRiskProblem(name) {
    return {
        id: (0, problems_1.generateProblemId)(name, 'license-risk'),
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
        const action = (0, problems_1.determineBestAction)([], []);
        assert.strictEqual(action.type, 'none');
    });
    it('should suggest fix-vulnerability for vulnerability with fix', () => {
        const problems = [
            makeVulnerabilityProblem('pkg', 'CVE-2024-1234', '2.0.0'),
        ];
        const action = (0, problems_1.determineBestAction)(problems, []);
        assert.strictEqual(action.type, 'fix-vulnerability');
        assert.ok(action.description.includes('2.0.0'));
    });
    it('should suggest remove for unused + unhealthy', () => {
        const problems = [
            makeUnhealthyProblem('pkg'),
            makeUnusedProblem('pkg'),
        ];
        const action = (0, problems_1.determineBestAction)(problems, []);
        assert.strictEqual(action.type, 'remove');
        assert.ok(action.description.includes('unused'));
        assert.ok(action.description.includes('unhealthy'));
    });
    it('should suggest remove for unused only', () => {
        const problems = [makeUnusedProblem('pkg')];
        const action = (0, problems_1.determineBestAction)(problems, []);
        assert.strictEqual(action.type, 'remove');
        assert.ok(action.description.includes('no imports'));
    });
    it('should suggest upgrade-blocker for blocked upgrade', () => {
        const problems = [
            makeBlockedProblem('pkg', 'blocker_pkg'),
        ];
        const action = (0, problems_1.determineBestAction)(problems, []);
        assert.strictEqual(action.type, 'upgrade-blocker');
        assert.ok(action.description.includes('blocker_pkg'));
    });
    it('should suggest upgrade-family for family conflict', () => {
        const problems = [
            makeFamilyConflictProblem('firebase_core', 'Firebase', ['firebase_auth']),
        ];
        const action = (0, problems_1.determineBestAction)(problems, []);
        assert.strictEqual(action.type, 'upgrade-family');
        assert.ok(action.description.includes('Firebase'));
    });
    it('should suggest remove-override for stale override', () => {
        const problems = [makeStaleOverrideProblem('pkg')];
        const action = (0, problems_1.determineBestAction)(problems, []);
        assert.strictEqual(action.type, 'remove-override');
    });
    it('should suggest replace for unhealthy with alternatives', () => {
        const problems = [makeUnhealthyProblem('pkg')];
        const action = (0, problems_1.determineBestAction)(problems, ['better_pkg']);
        assert.strictEqual(action.type, 'replace');
        assert.ok(action.description.includes('better_pkg'));
    });
    it('should suggest upgrade for risky transitive', () => {
        const problems = [makeRiskyTransitiveProblem('pkg')];
        const action = (0, problems_1.determineBestAction)(problems, []);
        assert.strictEqual(action.type, 'upgrade');
        assert.ok(action.description.includes('safer transitive'));
    });
    it('should suggest review-license for license risk', () => {
        const problems = [makeLicenseRiskProblem('pkg')];
        const action = (0, problems_1.determineBestAction)(problems, []);
        assert.strictEqual(action.type, 'review-license');
        assert.ok(action.description.includes('GPL-3.0'));
    });
    it('should prioritize vulnerability over other problems', () => {
        const problems = [
            makeUnusedProblem('pkg'),
            makeVulnerabilityProblem('pkg', 'CVE-2024-1234', '2.0.0'),
        ];
        const action = (0, problems_1.determineBestAction)(problems, []);
        assert.strictEqual(action.type, 'fix-vulnerability');
    });
});
describe('calculateResolutionChain', () => {
    it('should return empty for package with no linked problems', () => {
        const registry = new problems_1.ProblemRegistry();
        registry.add(makeUnhealthyProblem('pkg'));
        const chain = (0, problems_1.calculateResolutionChain)('pkg', registry);
        assert.strictEqual(chain.length, 0);
    });
    it('should return actions for linked problems', () => {
        const registry = new problems_1.ProblemRegistry();
        const blocker = makeUnhealthyProblem('blocker');
        const blocked = makeBlockedProblem('blocked', 'blocker');
        registry.add(blocker);
        registry.add(blocked);
        registry.link(blocker.id, blocked.id, 'blocks');
        const chain = (0, problems_1.calculateResolutionChain)('blocker', registry);
        assert.strictEqual(chain.length, 1);
        assert.ok(chain[0].targetPackages.includes('blocked'));
    });
});
describe('getUnlockedPackages', () => {
    it('should return empty for package with no linked problems', () => {
        const registry = new problems_1.ProblemRegistry();
        registry.add(makeUnhealthyProblem('pkg'));
        const unlocked = (0, problems_1.getUnlockedPackages)('pkg', registry);
        assert.strictEqual(unlocked.length, 0);
    });
    it('should return packages that would be unblocked', () => {
        const registry = new problems_1.ProblemRegistry();
        const blocker = makeUnhealthyProblem('blocker');
        const blocked = makeBlockedProblem('blocked', 'blocker');
        registry.add(blocker);
        registry.add(blocked);
        registry.link(blocker.id, blocked.id, 'blocks');
        const unlocked = (0, problems_1.getUnlockedPackages)('blocker', registry);
        assert.strictEqual(unlocked.length, 1);
        assert.strictEqual(unlocked[0], 'blocked');
    });
});
describe('findHighPriorityActions', () => {
    it('should return sorted high-priority actions', () => {
        const registry = new problems_1.ProblemRegistry();
        registry.add(makeUnusedProblem('low_priority'));
        registry.add(makeVulnerabilityProblem('high_priority', 'CVE-2024-1234', '2.0.0'));
        const actions = (0, problems_1.findHighPriorityActions)(registry, 10);
        assert.strictEqual(actions.length, 2);
        assert.strictEqual(actions[0].type, 'fix-vulnerability');
    });
    it('should respect limit', () => {
        const registry = new problems_1.ProblemRegistry();
        registry.add(makeUnusedProblem('pkg1'));
        registry.add(makeUnusedProblem('pkg2'));
        registry.add(makeUnusedProblem('pkg3'));
        const actions = (0, problems_1.findHighPriorityActions)(registry, 2);
        assert.strictEqual(actions.length, 2);
    });
});
describe('formatAction', () => {
    it('should format action with single problem', () => {
        const action = (0, problems_1.determineBestAction)([makeUnusedProblem('pkg')], []);
        const formatted = (0, problems_1.formatAction)(action);
        assert.ok(formatted.includes('Remove'));
    });
    it('should format action with multiple resolved problems', () => {
        const problems = [
            makeUnusedProblem('pkg'),
            makeUnhealthyProblem('pkg'),
        ];
        const action = (0, problems_1.determineBestAction)(problems, []);
        const formatted = (0, problems_1.formatAction)(action);
        assert.ok(formatted.includes('2 problems') || formatted.includes('resolves'));
    });
});
describe('actionIcon', () => {
    it('should return appropriate icons', () => {
        assert.strictEqual((0, problems_1.actionIcon)('remove'), '🗑️');
        assert.strictEqual((0, problems_1.actionIcon)('upgrade'), '⬆️');
        assert.strictEqual((0, problems_1.actionIcon)('fix-vulnerability'), '🛡️');
        assert.strictEqual((0, problems_1.actionIcon)('none'), '💡');
    });
});
//# sourceMappingURL=problem-actions.test.js.map