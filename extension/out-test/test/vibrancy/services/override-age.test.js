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
const override_age_1 = require("../../../vibrancy/services/override-age");
describe('override-age', () => {
    describe('calculateAgeDays', () => {
        it('should return null for null date', () => {
            assert.strictEqual((0, override_age_1.calculateAgeDays)(null), null);
        });
        it('should calculate days since a past date', () => {
            const oneWeekAgo = new Date();
            oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);
            const days = (0, override_age_1.calculateAgeDays)(oneWeekAgo);
            assert.ok(days !== null);
            assert.ok(days >= 6 && days <= 8);
        });
        it('should return 0 for today', () => {
            const today = new Date();
            const days = (0, override_age_1.calculateAgeDays)(today);
            assert.ok(days !== null);
            assert.ok(days >= 0 && days <= 1);
        });
    });
    describe('formatAge', () => {
        it('should return "unknown age" for null', () => {
            assert.strictEqual((0, override_age_1.formatAge)(null), 'unknown age');
        });
        it('should format days for less than a week', () => {
            assert.strictEqual((0, override_age_1.formatAge)(1), '1 day');
            assert.strictEqual((0, override_age_1.formatAge)(3), '3 days');
            assert.strictEqual((0, override_age_1.formatAge)(6), '6 days');
        });
        it('should format weeks for 7-29 days', () => {
            assert.strictEqual((0, override_age_1.formatAge)(7), '1 week');
            assert.strictEqual((0, override_age_1.formatAge)(14), '2 weeks');
            assert.strictEqual((0, override_age_1.formatAge)(21), '3 weeks');
        });
        it('should format months for 30-364 days', () => {
            assert.strictEqual((0, override_age_1.formatAge)(30), '1 month');
            assert.strictEqual((0, override_age_1.formatAge)(60), '2 months');
            assert.strictEqual((0, override_age_1.formatAge)(180), '6 months');
        });
        it('should format years for 365+ days', () => {
            assert.strictEqual((0, override_age_1.formatAge)(365), '1 year');
            assert.strictEqual((0, override_age_1.formatAge)(730), '2 years');
        });
    });
});
//# sourceMappingURL=override-age.test.js.map