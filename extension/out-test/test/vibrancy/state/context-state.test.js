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
const vscode = __importStar(require("vscode"));
const context_state_1 = require("../../../vibrancy/state/context-state");
describe('ContextState', () => {
    const testKey = 'test.contextState';
    let executedCommands = [];
    beforeEach(() => {
        executedCommands = [];
        vscode.commands.executeCommand = async (id, ...args) => {
            executedCommands.push({ id, args });
        };
    });
    describe('constructor', () => {
        it('should set initial value', () => {
            const state = new context_state_1.ContextState(testKey, true);
            assert.strictEqual(state.value, true);
        });
        it('should sync initial value to context', () => {
            new context_state_1.ContextState(testKey, 'initial');
            assert.strictEqual(executedCommands.length, 1);
            assert.strictEqual(executedCommands[0].id, 'setContext');
            assert.deepStrictEqual(executedCommands[0].args, [testKey, 'initial']);
        });
        it('should handle null default value', () => {
            const state = new context_state_1.ContextState(testKey, null);
            assert.strictEqual(state.value, null);
        });
        it('should handle number default value', () => {
            const state = new context_state_1.ContextState(testKey, 42);
            assert.strictEqual(state.value, 42);
        });
    });
    describe('value setter', () => {
        it('should update value and sync to context', () => {
            const state = new context_state_1.ContextState(testKey, false);
            executedCommands = [];
            state.value = true;
            assert.strictEqual(state.value, true);
            assert.strictEqual(executedCommands.length, 1);
            assert.deepStrictEqual(executedCommands[0].args, [testKey, true]);
        });
        it('should not sync when value unchanged', () => {
            const state = new context_state_1.ContextState(testKey, 'same');
            executedCommands = [];
            state.value = 'same';
            assert.strictEqual(executedCommands.length, 0);
        });
        it('should sync when changing from null to value', () => {
            const state = new context_state_1.ContextState(testKey, null);
            executedCommands = [];
            state.value = 'notNull';
            assert.strictEqual(executedCommands.length, 1);
            assert.deepStrictEqual(executedCommands[0].args, [testKey, 'notNull']);
        });
        it('should sync when changing from value to null', () => {
            const state = new context_state_1.ContextState(testKey, 'hasValue');
            executedCommands = [];
            state.value = null;
            assert.strictEqual(executedCommands.length, 1);
            assert.deepStrictEqual(executedCommands[0].args, [testKey, null]);
        });
    });
    describe('sync', () => {
        it('should force sync current value', () => {
            const state = new context_state_1.ContextState(testKey, 'value');
            executedCommands = [];
            state.sync();
            assert.strictEqual(executedCommands.length, 1);
            assert.deepStrictEqual(executedCommands[0].args, [testKey, 'value']);
        });
    });
    describe('reset', () => {
        it('should set new value and sync', () => {
            const state = new context_state_1.ContextState(testKey, 'old');
            executedCommands = [];
            state.reset('new');
            assert.strictEqual(state.value, 'new');
            assert.strictEqual(executedCommands.length, 1);
            assert.deepStrictEqual(executedCommands[0].args, [testKey, 'new']);
        });
        it('should sync even when reset to same value', () => {
            const state = new context_state_1.ContextState(testKey, 'same');
            executedCommands = [];
            state.reset('same');
            assert.strictEqual(executedCommands.length, 1);
        });
    });
});
//# sourceMappingURL=context-state.test.js.map