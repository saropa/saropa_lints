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
const adoption_gate_1 = require("../../../vibrancy/providers/adoption-gate");
// Note: getLatestResults() returns [] in test context (no scan has run),
// so all parsed dependency names are treated as candidates.
const PUBSPEC_WITH_DEPS = `
name: my_app
dependencies:
  http: ^1.2.0
  bloc: ^8.1.0
  path: ^1.9.0

dev_dependencies:
  test: ^1.25.0
`;
const PUBSPEC_EMPTY_DEPS = `
name: my_app
dependencies:
`;
const PUBSPEC_NO_DEPS = `
name: my_app
version: 1.0.0
`;
describe('adoption-gate', () => {
    describe('findCandidates', () => {
        it('should find all deps as candidates when no scan results exist', () => {
            const candidates = (0, adoption_gate_1.findCandidates)(PUBSPEC_WITH_DEPS);
            assert.ok(candidates.includes('http'));
            assert.ok(candidates.includes('bloc'));
            assert.ok(candidates.includes('path'));
            assert.ok(candidates.includes('test'));
            assert.strictEqual(candidates.length, 4);
        });
        it('should return empty for empty dependency section', () => {
            const candidates = (0, adoption_gate_1.findCandidates)(PUBSPEC_EMPTY_DEPS);
            assert.strictEqual(candidates.length, 0);
        });
        it('should return empty when no dependency section exists', () => {
            const candidates = (0, adoption_gate_1.findCandidates)(PUBSPEC_NO_DEPS);
            assert.strictEqual(candidates.length, 0);
        });
        it('should handle both direct and dev dependencies', () => {
            const candidates = (0, adoption_gate_1.findCandidates)(PUBSPEC_WITH_DEPS);
            // http, bloc, path are direct; test is dev
            assert.ok(candidates.includes('http'));
            assert.ok(candidates.includes('test'));
        });
        it('should not include non-dependency lines', () => {
            const yaml = `
name: my_app
version: 1.0.0
dependencies:
  http: ^1.0.0
environment:
  sdk: ">=3.0.0 <4.0.0"
`;
            const candidates = (0, adoption_gate_1.findCandidates)(yaml);
            assert.deepStrictEqual(candidates, ['http']);
        });
    });
});
//# sourceMappingURL=adoption-gate.test.js.map