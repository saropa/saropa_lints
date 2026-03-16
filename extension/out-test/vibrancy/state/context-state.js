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
exports.ContextState = void 0;
const vscode = __importStar(require("vscode"));
/**
 * Syncs a typed value with VS Code's context system for `when` clause evaluation.
 *
 * When the value changes, it automatically calls `setContext` to update VS Code's
 * context, enabling reactive UI updates via `when` clauses in package.json.
 *
 * @example
 * const isScanning = new ContextState('myExt.isScanning', false);
 * isScanning.value = true;  // Automatically syncs to VS Code context
 *
 * // In package.json:
 * // "when": "!myExt.isScanning"
 */
class ContextState {
    key;
    _value;
    constructor(key, defaultValue) {
        this.key = key;
        this._value = defaultValue;
        this.sync();
    }
    get value() {
        return this._value;
    }
    set value(newValue) {
        if (this._value !== newValue) {
            this._value = newValue;
            this.sync();
        }
    }
    /** Re-sync current value to VS Code context (useful after activation). */
    sync() {
        vscode.commands.executeCommand('setContext', this.key, this._value);
    }
    /** Reset to a new value and sync. */
    reset(newValue) {
        this._value = newValue;
        this.sync();
    }
}
exports.ContextState = ContextState;
//# sourceMappingURL=context-state.js.map