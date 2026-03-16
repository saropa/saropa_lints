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
const flutter_cli_1 = require("../../../vibrancy/services/flutter-cli");
/**
 * flutter-cli calls execFile internally. Tests are integration-style:
 * they return real results when Flutter is installed, or fail gracefully.
 */
describe('flutter-cli', () => {
    describe('runPubGet', () => {
        it('should return a CommandResult with success boolean', async () => {
            const result = await (0, flutter_cli_1.runPubGet)('.');
            assert.strictEqual(typeof result.success, 'boolean');
            assert.strictEqual(typeof result.output, 'string');
        });
        it('should fail for a non-existent directory', async () => {
            const result = await (0, flutter_cli_1.runPubGet)('/nonexistent-path-12345');
            assert.strictEqual(result.success, false);
        });
    });
    describe('runFlutterTest', () => {
        it('should return a CommandResult with success boolean', async () => {
            const result = await (0, flutter_cli_1.runFlutterTest)('.');
            assert.strictEqual(typeof result.success, 'boolean');
            assert.strictEqual(typeof result.output, 'string');
        });
        it('should fail for a non-existent directory', async () => {
            const result = await (0, flutter_cli_1.runFlutterTest)('/nonexistent-path-12345');
            assert.strictEqual(result.success, false);
        });
    });
});
//# sourceMappingURL=flutter-cli.test.js.map