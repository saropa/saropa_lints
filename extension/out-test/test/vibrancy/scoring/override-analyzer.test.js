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
const override_analyzer_1 = require("../../../vibrancy/scoring/override-analyzer");
const override_runner_1 = require("../../../vibrancy/services/override-runner");
describe('override-analyzer', () => {
    describe('analyzeOverrides', () => {
        const makeOverride = (name, version, isPathDep = false, isGitDep = false) => ({
            name,
            version,
            line: 10,
            isPathDep,
            isGitDep,
        });
        const makeDep = (name, version, constraint, isDirect = true) => ({
            name,
            version,
            constraint,
            source: 'hosted',
            isDirect,
            section: 'dependencies',
        });
        const makeGraphPkg = (name, dependencies = []) => ({
            name,
            version: '1.0.0',
            kind: 'direct',
            dependencies,
        });
        it('should mark path overrides as active', () => {
            const overrides = [makeOverride('local_pkg', 'path', true, false)];
            const result = (0, override_analyzer_1.analyzeOverrides)(overrides, [], [], new Map());
            assert.strictEqual(result.length, 1);
            assert.strictEqual(result[0].status, 'active');
            assert.strictEqual(result[0].blocker, 'local path override');
        });
        it('should mark git overrides as active', () => {
            const overrides = [makeOverride('git_pkg', 'git', false, true)];
            const result = (0, override_analyzer_1.analyzeOverrides)(overrides, [], [], new Map());
            assert.strictEqual(result.length, 1);
            assert.strictEqual(result[0].status, 'active');
            assert.strictEqual(result[0].blocker, 'git override');
        });
        it('should mark overrides without conflicts as stale', () => {
            const overrides = [makeOverride('intl', '0.18.5')];
            const deps = [makeDep('intl', '0.18.5', '^0.18.0')];
            const graph = [makeGraphPkg('intl')];
            const result = (0, override_analyzer_1.analyzeOverrides)(overrides, deps, graph, new Map());
            assert.strictEqual(result.length, 1);
            assert.strictEqual(result[0].status, 'stale');
            assert.strictEqual(result[0].blocker, null);
        });
        it('should include age information when provided', () => {
            const overrides = [makeOverride('intl', '0.19.0')];
            const addedDate = new Date('2024-01-01');
            const ages = new Map([['intl', addedDate]]);
            const result = (0, override_analyzer_1.analyzeOverrides)(overrides, [], [], ages);
            assert.strictEqual(result.length, 1);
            assert.ok(result[0].addedDate);
            assert.ok(result[0].ageDays !== null);
            assert.ok(result[0].ageDays > 0);
        });
        it('should handle missing age information', () => {
            const overrides = [makeOverride('intl', '0.19.0')];
            const result = (0, override_analyzer_1.analyzeOverrides)(overrides, [], [], new Map());
            assert.strictEqual(result.length, 1);
            assert.strictEqual(result[0].addedDate, null);
            assert.strictEqual(result[0].ageDays, null);
        });
    });
    describe('isOldOverride', () => {
        const makeAnalysis = (ageDays) => ({
            entry: { name: 'test', version: '1.0.0', line: 0, isPathDep: false, isGitDep: false },
            status: 'active',
            blocker: null,
            addedDate: null,
            ageDays,
        });
        it('should return true for overrides older than threshold', () => {
            const analysis = makeAnalysis(200);
            assert.strictEqual((0, override_analyzer_1.isOldOverride)(analysis, 180), true);
        });
        it('should return false for overrides newer than threshold', () => {
            const analysis = makeAnalysis(90);
            assert.strictEqual((0, override_analyzer_1.isOldOverride)(analysis, 180), false);
        });
        it('should return false for null age', () => {
            const analysis = makeAnalysis(null);
            assert.strictEqual((0, override_analyzer_1.isOldOverride)(analysis), false);
        });
        it('should use default threshold of 180 days', () => {
            const old = makeAnalysis(181);
            const recent = makeAnalysis(179);
            assert.strictEqual((0, override_analyzer_1.isOldOverride)(old), true);
            assert.strictEqual((0, override_analyzer_1.isOldOverride)(recent), false);
        });
    });
    describe('groupByStatus', () => {
        const makeAnalysis = (status) => ({
            entry: { name: 'test', version: '1.0.0', line: 0, isPathDep: false, isGitDep: false },
            status,
            blocker: null,
            addedDate: null,
            ageDays: null,
        });
        it('should group analyses by status', () => {
            const analyses = [
                makeAnalysis('active'),
                makeAnalysis('stale'),
                makeAnalysis('active'),
                makeAnalysis('stale'),
            ];
            const { active, stale } = (0, override_analyzer_1.groupByStatus)(analyses);
            assert.strictEqual(active.length, 2);
            assert.strictEqual(stale.length, 2);
        });
        it('should handle empty array', () => {
            const { active, stale } = (0, override_analyzer_1.groupByStatus)([]);
            assert.strictEqual(active.length, 0);
            assert.strictEqual(stale.length, 0);
        });
        it('should handle all active', () => {
            const analyses = [makeAnalysis('active'), makeAnalysis('active')];
            const { active, stale } = (0, override_analyzer_1.groupByStatus)(analyses);
            assert.strictEqual(active.length, 2);
            assert.strictEqual(stale.length, 0);
        });
        it('should handle all stale', () => {
            const analyses = [makeAnalysis('stale'), makeAnalysis('stale')];
            const { active, stale } = (0, override_analyzer_1.groupByStatus)(analyses);
            assert.strictEqual(active.length, 0);
            assert.strictEqual(stale.length, 2);
        });
    });
    describe('applyKnownOverrideReasons', () => {
        it('should flip stale to active when known override reason exists', () => {
            const analyses = [{
                    entry: { name: 'path_provider_foundation', version: '2.4.0', line: 10, isPathDep: false, isGitDep: false },
                    status: 'stale',
                    blocker: null,
                    addedDate: null,
                    ageDays: null,
                }];
            const result = (0, override_runner_1.applyKnownOverrideReasons)(analyses);
            assert.strictEqual(result[0].status, 'active');
            assert.ok(result[0].blocker);
        });
        it('should not change stale status when no known override reason', () => {
            const analyses = [{
                    entry: { name: 'unknown_pkg', version: '1.0.0', line: 10, isPathDep: false, isGitDep: false },
                    status: 'stale',
                    blocker: null,
                    addedDate: null,
                    ageDays: null,
                }];
            const result = (0, override_runner_1.applyKnownOverrideReasons)(analyses);
            assert.strictEqual(result[0].status, 'stale');
            assert.strictEqual(result[0].blocker, null);
        });
        it('should not change already-active overrides', () => {
            const analyses = [{
                    entry: { name: 'path_provider_foundation', version: '2.4.0', line: 10, isPathDep: false, isGitDep: false },
                    status: 'active',
                    blocker: 'direct constraint',
                    addedDate: null,
                    ageDays: null,
                }];
            const result = (0, override_runner_1.applyKnownOverrideReasons)(analyses);
            assert.strictEqual(result[0].status, 'active');
            assert.strictEqual(result[0].blocker, 'direct constraint');
        });
    });
});
//# sourceMappingURL=override-analyzer.test.js.map