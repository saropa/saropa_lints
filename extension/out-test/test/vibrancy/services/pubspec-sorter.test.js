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
describe('pubspec-sorter', () => {
    describe('SDK_PACKAGES detection', () => {
        const SDK_PACKAGES = new Set([
            'flutter', 'flutter_test', 'flutter_localizations', 'flutter_web_plugins',
        ]);
        it('should recognize flutter as SDK package', () => {
            assert.ok(SDK_PACKAGES.has('flutter'));
        });
        it('should recognize flutter_test as SDK package', () => {
            assert.ok(SDK_PACKAGES.has('flutter_test'));
        });
        it('should not recognize http as SDK package', () => {
            assert.ok(!SDK_PACKAGES.has('http'));
        });
    });
    describe('sorting logic', () => {
        function sortEntries(entries, sdkFirst) {
            return [...entries].sort((a, b) => {
                if (sdkFirst) {
                    if (a.isSdk && !b.isSdk) {
                        return -1;
                    }
                    if (!a.isSdk && b.isSdk) {
                        return 1;
                    }
                }
                return a.name.toLowerCase().localeCompare(b.name.toLowerCase());
            });
        }
        it('should sort alphabetically', () => {
            const entries = [
                { name: 'provider', isSdk: false },
                { name: 'http', isSdk: false },
                { name: 'dio', isSdk: false },
            ];
            const sorted = sortEntries(entries, false);
            assert.deepStrictEqual(sorted.map(e => e.name), ['dio', 'http', 'provider']);
        });
        it('should keep SDK packages first when sdkFirst is true', () => {
            const entries = [
                { name: 'provider', isSdk: false },
                { name: 'flutter', isSdk: true },
                { name: 'dio', isSdk: false },
            ];
            const sorted = sortEntries(entries, true);
            assert.deepStrictEqual(sorted.map(e => e.name), ['flutter', 'dio', 'provider']);
        });
        it('should sort SDK packages among themselves when sdkFirst is true', () => {
            const entries = [
                { name: 'flutter_test', isSdk: true },
                { name: 'flutter', isSdk: true },
                { name: 'http', isSdk: false },
            ];
            const sorted = sortEntries(entries, true);
            assert.deepStrictEqual(sorted.map(e => e.name), ['flutter', 'flutter_test', 'http']);
        });
        it('should be case-insensitive', () => {
            const entries = [
                { name: 'Provider', isSdk: false },
                { name: 'http', isSdk: false },
                { name: 'Dio', isSdk: false },
            ];
            const sorted = sortEntries(entries, false);
            assert.deepStrictEqual(sorted.map(e => e.name), ['Dio', 'http', 'Provider']);
        });
    });
});
//# sourceMappingURL=pubspec-sorter.test.js.map