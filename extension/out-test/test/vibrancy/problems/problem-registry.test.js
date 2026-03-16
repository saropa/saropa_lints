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
function makeUnhealthyProblem(name, score) {
    return {
        id: (0, problems_1.generateProblemId)(name, 'unhealthy'),
        type: 'unhealthy',
        package: name,
        severity: score < 20 ? 'high' : 'medium',
        line: 10,
        score,
        category: score < 20 ? 'end-of-life' : 'legacy-locked',
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
describe('ProblemRegistry', () => {
    describe('add/get', () => {
        it('should add and retrieve problems by package', () => {
            const registry = new problems_1.ProblemRegistry();
            const problem = makeUnhealthyProblem('dead_package', 5);
            registry.add(problem);
            const problems = registry.getForPackage('dead_package');
            assert.strictEqual(problems.length, 1);
            assert.strictEqual(problems[0].type, 'unhealthy');
        });
        it('should deduplicate problems with same ID', () => {
            const registry = new problems_1.ProblemRegistry();
            const problem1 = makeUnhealthyProblem('pkg', 5);
            const problem2 = makeUnhealthyProblem('pkg', 10);
            registry.add(problem1);
            registry.add(problem2);
            const problems = registry.getForPackage('pkg');
            assert.strictEqual(problems.length, 1);
        });
        it('should allow multiple problems of different types for same package', () => {
            const registry = new problems_1.ProblemRegistry();
            registry.add(makeUnhealthyProblem('pkg', 20));
            registry.add(makeUnusedProblem('pkg'));
            const problems = registry.getForPackage('pkg');
            assert.strictEqual(problems.length, 2);
        });
        it('should return empty array for unknown package', () => {
            const registry = new problems_1.ProblemRegistry();
            const problems = registry.getForPackage('unknown');
            assert.strictEqual(problems.length, 0);
        });
    });
    describe('getById', () => {
        it('should retrieve problem by ID', () => {
            const registry = new problems_1.ProblemRegistry();
            const problem = makeUnhealthyProblem('pkg', 5);
            registry.add(problem);
            const found = registry.getById(problem.id);
            assert.strictEqual(found?.package, 'pkg');
        });
        it('should return undefined for unknown ID', () => {
            const registry = new problems_1.ProblemRegistry();
            const found = registry.getById('unknown:id');
            assert.strictEqual(found, undefined);
        });
    });
    describe('getByType', () => {
        it('should return all problems of a specific type', () => {
            const registry = new problems_1.ProblemRegistry();
            registry.add(makeUnhealthyProblem('pkg1', 5));
            registry.add(makeUnhealthyProblem('pkg2', 10));
            registry.add(makeUnusedProblem('pkg3'));
            const unhealthy = registry.getByType('unhealthy');
            assert.strictEqual(unhealthy.length, 2);
        });
    });
    describe('getBySeverity', () => {
        it('should return all problems with a specific severity', () => {
            const registry = new problems_1.ProblemRegistry();
            registry.add(makeUnhealthyProblem('eol', 5));
            registry.add(makeUnhealthyProblem('legacy', 25));
            registry.add(makeUnusedProblem('unused'));
            const high = registry.getBySeverity('high');
            assert.strictEqual(high.length, 1);
            assert.strictEqual(high[0].package, 'eol');
        });
    });
    describe('getAllSortedByPriority', () => {
        it('should return packages sorted by priority (highest first)', () => {
            const registry = new problems_1.ProblemRegistry();
            registry.add(makeUnusedProblem('low'));
            registry.add(makeUnhealthyProblem('high', 5));
            registry.add(makeUnhealthyProblem('medium', 25));
            const sorted = registry.getAllSortedByPriority();
            assert.strictEqual(sorted[0].package, 'high');
        });
        it('should compute highest severity correctly', () => {
            const registry = new problems_1.ProblemRegistry();
            registry.add(makeUnhealthyProblem('pkg', 5));
            registry.add(makeUnusedProblem('pkg'));
            const sorted = registry.getAllSortedByPriority();
            assert.strictEqual(sorted[0].highestSeverity, 'high');
        });
    });
    describe('linking', () => {
        it('should link problems and track resolution chains', () => {
            const registry = new problems_1.ProblemRegistry();
            const blocker = makeUnhealthyProblem('blocker', 30);
            const blocked = makeBlockedProblem('blocked', 'blocker');
            registry.add(blocker);
            registry.add(blocked);
            registry.link(blocker.id, blocked.id, 'blocks');
            const chain = registry.getResolutionChain(blocker.id);
            assert.strictEqual(chain.length, 1);
            assert.strictEqual(chain[0].package, 'blocked');
        });
        it('should get blockers for a problem', () => {
            const registry = new problems_1.ProblemRegistry();
            const blocker = makeUnhealthyProblem('blocker', 30);
            const blocked = makeBlockedProblem('blocked', 'blocker');
            registry.add(blocker);
            registry.add(blocked);
            registry.link(blocker.id, blocked.id, 'blocks');
            const blockers = registry.getBlockers(blocked.id);
            assert.strictEqual(blockers.length, 1);
            assert.strictEqual(blockers[0].package, 'blocker');
        });
        it('should not link non-existent problems', () => {
            const registry = new problems_1.ProblemRegistry();
            const problem = makeUnhealthyProblem('pkg', 30);
            registry.add(problem);
            registry.link('unknown:id', problem.id, 'blocks');
            registry.link(problem.id, 'unknown:id', 'blocks');
            const links = registry.getLinks();
            assert.strictEqual(links.length, 0);
        });
    });
    describe('counts', () => {
        it('should count total problems', () => {
            const registry = new problems_1.ProblemRegistry();
            registry.add(makeUnhealthyProblem('pkg1', 5));
            registry.add(makeUnusedProblem('pkg1'));
            registry.add(makeUnhealthyProblem('pkg2', 10));
            assert.strictEqual(registry.totalCount, 3);
        });
        it('should count by severity', () => {
            const registry = new problems_1.ProblemRegistry();
            registry.add(makeUnhealthyProblem('eol', 5));
            registry.add(makeUnhealthyProblem('legacy', 25));
            registry.add(makeUnusedProblem('unused'));
            const counts = registry.countBySeverity();
            assert.strictEqual(counts.high, 1);
            assert.strictEqual(counts.medium, 1);
            assert.strictEqual(counts.low, 1);
        });
        it('should count by type', () => {
            const registry = new problems_1.ProblemRegistry();
            registry.add(makeUnhealthyProblem('pkg1', 5));
            registry.add(makeUnhealthyProblem('pkg2', 10));
            registry.add(makeUnusedProblem('pkg3'));
            const counts = registry.countByType();
            assert.strictEqual(counts['unhealthy'], 2);
            assert.strictEqual(counts['unused'], 1);
        });
    });
    describe('clear', () => {
        it('should clear all problems and links', () => {
            const registry = new problems_1.ProblemRegistry();
            registry.add(makeUnhealthyProblem('pkg', 5));
            registry.add(makeUnusedProblem('pkg'));
            registry.clear();
            assert.strictEqual(registry.totalCount, 0);
            assert.strictEqual(registry.isEmpty(), true);
        });
    });
    describe('toArray', () => {
        it('should export all problems as flat array', () => {
            const registry = new problems_1.ProblemRegistry();
            registry.add(makeUnhealthyProblem('pkg1', 5));
            registry.add(makeUnusedProblem('pkg2'));
            const all = registry.toArray();
            assert.strictEqual(all.length, 2);
        });
    });
});
describe('generateProblemId', () => {
    it('should generate ID without suffix', () => {
        const id = (0, problems_1.generateProblemId)('my_package', 'unhealthy');
        assert.strictEqual(id, 'my_package:unhealthy');
    });
    it('should generate ID with suffix', () => {
        const id = (0, problems_1.generateProblemId)('my_package', 'vulnerability', 'CVE-2024-1234');
        assert.strictEqual(id, 'my_package:vulnerability:CVE-2024-1234');
    });
});
//# sourceMappingURL=problem-registry.test.js.map