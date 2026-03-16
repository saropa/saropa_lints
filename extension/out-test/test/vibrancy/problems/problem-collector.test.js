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
const problem_collector_1 = require("../../../vibrancy/problems/problem-collector");
const problem_registry_1 = require("../../../vibrancy/problems/problem-registry");
const test_helpers_1 = require("../test-helpers");
describe('ProblemCollector', () => {
    describe('collectProblemsForPackage', () => {
        it('should add unused problem when isUnused and section is dependencies', () => {
            const registry = new problem_registry_1.ProblemRegistry();
            const result = {
                ...(0, test_helpers_1.makeMinimalResult)({ name: 'unused_pkg', section: 'dependencies' }),
                isUnused: true,
            };
            (0, problem_collector_1.collectProblemsForPackage)(result, 5, new Map(), new Map(), registry);
            const problems = registry.getForPackage('unused_pkg');
            assert.strictEqual(problems.some(p => p.type === 'unused'), true);
        });
        it('should not add unused problem when isUnused but section is dev_dependencies', () => {
            const registry = new problem_registry_1.ProblemRegistry();
            const result = {
                ...(0, test_helpers_1.makeMinimalResult)({ name: 'build_runner', section: 'dev_dependencies' }),
                isUnused: true,
            };
            (0, problem_collector_1.collectProblemsForPackage)(result, 5, new Map(), new Map(), registry);
            const problems = registry.getForPackage('build_runner');
            assert.strictEqual(problems.some(p => p.type === 'unused'), false);
        });
    });
});
//# sourceMappingURL=problem-collector.test.js.map