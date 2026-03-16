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
const package_families_1 = require("../../../vibrancy/data/package-families");
describe('package-families', () => {
    describe('matchFamily', () => {
        it('should return null for firebase_core (independent version tracks)', () => {
            assert.strictEqual((0, package_families_1.matchFamily)('firebase_core'), null);
        });
        it('should return null for cloud_firestore (independent version tracks)', () => {
            assert.strictEqual((0, package_families_1.matchFamily)('cloud_firestore'), null);
        });
        it('should return null for google_fonts (independent version tracks)', () => {
            assert.strictEqual((0, package_families_1.matchFamily)('google_fonts'), null);
        });
        it('should match riverpod to Riverpod', () => {
            const result = (0, package_families_1.matchFamily)('riverpod');
            assert.deepStrictEqual(result, { id: 'riverpod', label: 'Riverpod' });
        });
        it('should match flutter_riverpod to Riverpod', () => {
            const result = (0, package_families_1.matchFamily)('flutter_riverpod');
            assert.deepStrictEqual(result, { id: 'riverpod', label: 'Riverpod' });
        });
        it('should match hooks_riverpod to Riverpod', () => {
            const result = (0, package_families_1.matchFamily)('hooks_riverpod');
            assert.deepStrictEqual(result, { id: 'riverpod', label: 'Riverpod' });
        });
        it('should match bloc to Bloc', () => {
            const result = (0, package_families_1.matchFamily)('bloc');
            assert.deepStrictEqual(result, { id: 'bloc', label: 'Bloc' });
        });
        it('should match flutter_bloc to Bloc', () => {
            const result = (0, package_families_1.matchFamily)('flutter_bloc');
            assert.deepStrictEqual(result, { id: 'bloc', label: 'Bloc' });
        });
        it('should match freezed to Freezed', () => {
            const result = (0, package_families_1.matchFamily)('freezed');
            assert.deepStrictEqual(result, { id: 'freezed', label: 'Freezed' });
        });
        it('should match drift to Drift', () => {
            const result = (0, package_families_1.matchFamily)('drift');
            assert.deepStrictEqual(result, { id: 'drift', label: 'Drift' });
        });
        it('should match drift_dev to Drift', () => {
            const result = (0, package_families_1.matchFamily)('drift_dev');
            assert.deepStrictEqual(result, { id: 'drift', label: 'Drift' });
        });
        it('should return null for non-family packages', () => {
            assert.strictEqual((0, package_families_1.matchFamily)('http'), null);
            assert.strictEqual((0, package_families_1.matchFamily)('path'), null);
            assert.strictEqual((0, package_families_1.matchFamily)('provider'), null);
        });
        it('should return null for empty string', () => {
            assert.strictEqual((0, package_families_1.matchFamily)(''), null);
        });
        it('should not match partial Riverpod names', () => {
            assert.strictEqual((0, package_families_1.matchFamily)('riverpod_lint'), null);
        });
        it('should not match partial Bloc names', () => {
            assert.strictEqual((0, package_families_1.matchFamily)('bloc_test'), null);
        });
    });
});
//# sourceMappingURL=package-families.test.js.map