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
const codelens_toggle_1 = require("../../../vibrancy/ui/codelens-toggle");
describe('CodeLensToggle', () => {
    let toggle;
    beforeEach(() => {
        toggle = new codelens_toggle_1.CodeLensToggle();
    });
    afterEach(() => {
        toggle.dispose();
    });
    describe('initial state', () => {
        it('should be enabled by default', () => {
            assert.strictEqual(toggle.isEnabled, true);
        });
    });
    describe('toggle', () => {
        it('should flip state from enabled to disabled', () => {
            toggle.toggle();
            assert.strictEqual(toggle.isEnabled, false);
        });
        it('should flip state from disabled to enabled', () => {
            toggle.toggle();
            toggle.toggle();
            assert.strictEqual(toggle.isEnabled, true);
        });
    });
    describe('show', () => {
        it('should enable when disabled', () => {
            toggle.hide();
            toggle.show();
            assert.strictEqual(toggle.isEnabled, true);
        });
        it('should stay enabled when already enabled', () => {
            toggle.show();
            assert.strictEqual(toggle.isEnabled, true);
        });
    });
    describe('hide', () => {
        it('should disable when enabled', () => {
            toggle.hide();
            assert.strictEqual(toggle.isEnabled, false);
        });
        it('should stay disabled when already disabled', () => {
            toggle.hide();
            toggle.hide();
            assert.strictEqual(toggle.isEnabled, false);
        });
    });
    describe('onDidChange event', () => {
        it('should fire when toggled', (done) => {
            toggle.onDidChange((enabled) => {
                assert.strictEqual(enabled, false);
                done();
            });
            toggle.toggle();
        });
        it('should fire when shown', (done) => {
            toggle.hide();
            toggle.onDidChange((enabled) => {
                assert.strictEqual(enabled, true);
                done();
            });
            toggle.show();
        });
        it('should fire when hidden', (done) => {
            toggle.onDidChange((enabled) => {
                assert.strictEqual(enabled, false);
                done();
            });
            toggle.hide();
        });
        it('should not fire when show called while enabled', () => {
            let fired = false;
            toggle.onDidChange(() => { fired = true; });
            toggle.show();
            assert.strictEqual(fired, false);
        });
        it('should not fire when hide called while disabled', () => {
            toggle.hide();
            let fired = false;
            toggle.onDidChange(() => { fired = true; });
            toggle.hide();
            assert.strictEqual(fired, false);
        });
    });
    describe('dispose', () => {
        it('should be callable multiple times', () => {
            toggle.dispose();
            toggle.dispose();
        });
    });
});
//# sourceMappingURL=codelens-toggle.test.js.map