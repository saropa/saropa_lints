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
const purl_builder_1 = require("../../../vibrancy/scoring/purl-builder");
describe('purl-builder', () => {
    it('should build basic pub PURL', () => {
        assert.strictEqual((0, purl_builder_1.buildPurl)('http', '1.2.0'), 'pkg:pub/http@1.2.0');
    });
    it('should handle scoped package names', () => {
        assert.strictEqual((0, purl_builder_1.buildPurl)('flutter_bloc', '8.1.3'), 'pkg:pub/flutter_bloc@8.1.3');
    });
    it('should handle pre-release versions', () => {
        assert.strictEqual((0, purl_builder_1.buildPurl)('pkg', '2.0.0-dev.1'), 'pkg:pub/pkg@2.0.0-dev.1');
    });
    it('should encode special characters in name', () => {
        const result = (0, purl_builder_1.buildPurl)('my%pkg', '1.0.0');
        assert.ok(result.includes('my%25pkg'));
    });
});
//# sourceMappingURL=purl-builder.test.js.map