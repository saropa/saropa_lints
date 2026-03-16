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
const sdk_detector_1 = require("../../../vibrancy/services/sdk-detector");
/**
 * sdk-detector calls execFile internally. We test the functions as
 * integration tests — they return real SDK versions when available,
 * or 'unknown' if not installed.
 */
describe('sdk-detector', () => {
    describe('detectDartVersion', () => {
        it('should return a string', async () => {
            const version = await (0, sdk_detector_1.detectDartVersion)();
            assert.strictEqual(typeof version, 'string');
            assert.ok(version.length > 0);
        });
        it('should return a version number or unknown', async () => {
            const version = await (0, sdk_detector_1.detectDartVersion)();
            const isVersion = /^\d+\.\d+\.\d+/.test(version);
            const isUnknown = version === 'unknown';
            assert.ok(isVersion || isUnknown, `Expected version or "unknown", got "${version}"`);
        });
    });
    describe('detectFlutterVersion', () => {
        it('should return a string', async () => {
            const version = await (0, sdk_detector_1.detectFlutterVersion)();
            assert.strictEqual(typeof version, 'string');
            assert.ok(version.length > 0);
        });
        it('should return a version number or unknown', async () => {
            const version = await (0, sdk_detector_1.detectFlutterVersion)();
            const isVersion = /^\d+\.\d+\.\d+/.test(version);
            const isUnknown = version === 'unknown';
            assert.ok(isVersion || isUnknown, `Expected version or "unknown", got "${version}"`);
        });
    });
    describe('version regex patterns', () => {
        it('should match Dart SDK version output', () => {
            const output = 'Dart SDK version: 3.3.0 (stable) on "windows_x64"';
            const match = output.match(/Dart SDK version:\s*(\S+)/);
            assert.strictEqual(match?.[1], '3.3.0');
        });
        it('should match Flutter version output', () => {
            const output = 'Flutter 3.19.0 • channel stable';
            const match = output.match(/Flutter\s+(\S+)/);
            assert.strictEqual(match?.[1], '3.19.0');
        });
        it('should not match random text for Dart', () => {
            const output = 'something else entirely';
            const match = output.match(/Dart SDK version:\s*(\S+)/);
            assert.strictEqual(match, null);
        });
        it('should not match random text for Flutter', () => {
            const output = 'not a flutter output';
            const match = output.match(/Flutter\s+(\S+)/);
            assert.strictEqual(match, null);
        });
        it('should handle pre-release Dart versions', () => {
            const output = 'Dart SDK version: 3.4.0-dev.1 (dev)';
            const match = output.match(/Dart SDK version:\s*(\S+)/);
            assert.strictEqual(match?.[1], '3.4.0-dev.1');
        });
        it('should handle pre-release Flutter versions', () => {
            const output = 'Flutter 3.20.0-1.0.pre • channel beta';
            const match = output.match(/Flutter\s+(\S+)/);
            assert.strictEqual(match?.[1], '3.20.0-1.0.pre');
        });
    });
});
//# sourceMappingURL=sdk-detector.test.js.map