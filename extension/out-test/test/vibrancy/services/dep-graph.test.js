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
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const dep_graph_1 = require("../../../vibrancy/services/dep-graph");
const fixturesDir = path.join(__dirname, '..', '..', '..', 'src', 'test', 'fixtures');
const FIXTURE_PATH = path.join(fixturesDir, 'pub-deps.json');
describe('dep-graph', () => {
    describe('parseDepGraphJson', () => {
        it('should parse fixture into packages', () => {
            const json = fs.readFileSync(FIXTURE_PATH, 'utf-8');
            const result = (0, dep_graph_1.parseDepGraphJson)(json);
            assert.strictEqual(result.root, 'my_app');
            assert.ok(result.packages.length > 0);
        });
        it('should extract package fields correctly', () => {
            const json = fs.readFileSync(FIXTURE_PATH, 'utf-8');
            const result = (0, dep_graph_1.parseDepGraphJson)(json);
            const http = result.packages.find(p => p.name === 'http');
            assert.ok(http);
            assert.strictEqual(http.version, '1.2.0');
            assert.strictEqual(http.kind, 'direct');
            assert.deepStrictEqual(http.dependencies, ['http_parser', 'meta']);
        });
        it('should handle empty dependencies array', () => {
            const json = fs.readFileSync(FIXTURE_PATH, 'utf-8');
            const result = (0, dep_graph_1.parseDepGraphJson)(json);
            const meta = result.packages.find(p => p.name === 'meta');
            assert.ok(meta);
            assert.deepStrictEqual(meta.dependencies, []);
        });
        it('should return empty for invalid JSON', () => {
            const result = (0, dep_graph_1.parseDepGraphJson)('not json');
            assert.strictEqual(result.root, '');
            assert.deepStrictEqual(result.packages, []);
        });
        it('should return empty for missing packages array', () => {
            const result = (0, dep_graph_1.parseDepGraphJson)('{"root": "app"}');
            assert.strictEqual(result.root, 'app');
            assert.deepStrictEqual(result.packages, []);
        });
        it('should handle leading non-JSON text', () => {
            const json = 'Warning: something\n' + JSON.stringify({
                root: 'app',
                packages: [{ name: 'pkg', version: '1.0.0', kind: 'direct', dependencies: [] }],
            });
            const result = (0, dep_graph_1.parseDepGraphJson)(json);
            assert.strictEqual(result.packages.length, 1);
        });
    });
    describe('buildReverseDeps', () => {
        it('should build reverse lookup from fixture', () => {
            const json = fs.readFileSync(FIXTURE_PATH, 'utf-8');
            const { packages } = (0, dep_graph_1.parseDepGraphJson)(json);
            const reverse = (0, dep_graph_1.buildReverseDeps)(packages);
            const metaDeps = reverse.get('meta');
            assert.ok(metaDeps);
            const names = metaDeps.map(e => e.dependentPackage).sort();
            assert.ok(names.includes('http'));
            assert.ok(names.includes('firebase_core'));
        });
        it('should show intl is depended on by date_picker_timeline', () => {
            const json = fs.readFileSync(FIXTURE_PATH, 'utf-8');
            const { packages } = (0, dep_graph_1.parseDepGraphJson)(json);
            const reverse = (0, dep_graph_1.buildReverseDeps)(packages);
            const intlDeps = reverse.get('intl');
            assert.ok(intlDeps);
            const names = intlDeps.map(e => e.dependentPackage);
            assert.ok(names.includes('date_picker_timeline'));
        });
        it('should return empty map for empty input', () => {
            const reverse = (0, dep_graph_1.buildReverseDeps)([]);
            assert.strictEqual(reverse.size, 0);
        });
        it('should not include packages with no dependents', () => {
            const packages = [
                { name: 'a', version: '1.0.0', kind: 'direct', dependencies: [] },
            ];
            const reverse = (0, dep_graph_1.buildReverseDeps)(packages);
            assert.strictEqual(reverse.has('a'), false);
        });
        it('should handle multiple dependents', () => {
            const packages = [
                { name: 'a', version: '1.0.0', kind: 'direct', dependencies: ['c'] },
                { name: 'b', version: '1.0.0', kind: 'direct', dependencies: ['c'] },
                { name: 'c', version: '1.0.0', kind: 'transitive', dependencies: [] },
            ];
            const reverse = (0, dep_graph_1.buildReverseDeps)(packages);
            const cDeps = reverse.get('c');
            assert.strictEqual(cDeps.length, 2);
        });
    });
});
//# sourceMappingURL=dep-graph.test.js.map