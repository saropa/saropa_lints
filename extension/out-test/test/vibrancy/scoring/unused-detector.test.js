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
const unused_detector_1 = require("../../../vibrancy/scoring/unused-detector");
describe('unused-detector', () => {
    describe('detectUnused', () => {
        it('should return empty when all deps are imported', () => {
            const declared = ['http', 'provider', 'intl'];
            const imported = new Set(['http', 'provider', 'intl']);
            assert.deepStrictEqual((0, unused_detector_1.detectUnused)(declared, imported), []);
        });
        it('should flag deps with no matching import', () => {
            const declared = ['http', 'provider', 'intl'];
            const imported = new Set(['http']);
            const result = (0, unused_detector_1.detectUnused)(declared, imported);
            assert.deepStrictEqual(result, ['provider', 'intl']);
        });
        it('should return empty for empty declared list', () => {
            assert.deepStrictEqual((0, unused_detector_1.detectUnused)([], new Set(['http'])), []);
        });
        it('should flag all deps when no imports exist', () => {
            const declared = ['http', 'provider'];
            const result = (0, unused_detector_1.detectUnused)(declared, new Set());
            assert.deepStrictEqual(result, ['http', 'provider']);
        });
        it('should skip flutter SDK packages', () => {
            const declared = ['flutter', 'flutter_test', 'flutter_localizations'];
            const result = (0, unused_detector_1.detectUnused)(declared, new Set());
            assert.deepStrictEqual(result, []);
        });
        it('should skip flutter_web_plugins and flutter_driver', () => {
            const declared = ['flutter_web_plugins', 'flutter_driver'];
            const result = (0, unused_detector_1.detectUnused)(declared, new Set());
            assert.deepStrictEqual(result, []);
        });
        it('should skip platform plugin packages', () => {
            const declared = [
                'url_launcher_android', 'url_launcher_ios',
                'url_launcher_web', 'url_launcher_windows',
                'url_launcher_macos', 'url_launcher_linux',
                'url_launcher_platform_interface',
            ];
            const result = (0, unused_detector_1.detectUnused)(declared, new Set());
            assert.deepStrictEqual(result, []);
        });
        it('should flag non-platform packages that end with similar suffixes', () => {
            const declared = ['my_android_utils'];
            const result = (0, unused_detector_1.detectUnused)(declared, new Set());
            assert.deepStrictEqual(result, ['my_android_utils']);
        });
        it('should not flag SDK packages even when imported', () => {
            const declared = ['flutter', 'http'];
            const imported = new Set(['http']);
            const result = (0, unused_detector_1.detectUnused)(declared, imported);
            assert.deepStrictEqual(result, []);
        });
    });
});
//# sourceMappingURL=unused-detector.test.js.map