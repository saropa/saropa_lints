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
const time_formatter_1 = require("../../../vibrancy/scoring/time-formatter");
describe('time-formatter', () => {
    describe('formatRelativeTime', () => {
        it('should return "today" for 0 days', () => {
            assert.strictEqual((0, time_formatter_1.formatRelativeTime)(0), 'today');
        });
        it('should return "yesterday" for 1 day', () => {
            assert.strictEqual((0, time_formatter_1.formatRelativeTime)(1), 'yesterday');
        });
        it('should return days for 2-29', () => {
            assert.strictEqual((0, time_formatter_1.formatRelativeTime)(2), '2 days ago');
            assert.strictEqual((0, time_formatter_1.formatRelativeTime)(15), '15 days ago');
            assert.strictEqual((0, time_formatter_1.formatRelativeTime)(29), '29 days ago');
        });
        it('should return "1 month ago" for 30-59 days', () => {
            assert.strictEqual((0, time_formatter_1.formatRelativeTime)(30), '1 month ago');
            assert.strictEqual((0, time_formatter_1.formatRelativeTime)(59), '1 month ago');
        });
        it('should return months for 60-364 days', () => {
            assert.strictEqual((0, time_formatter_1.formatRelativeTime)(60), '2 months ago');
            assert.strictEqual((0, time_formatter_1.formatRelativeTime)(150), '5 months ago');
            assert.strictEqual((0, time_formatter_1.formatRelativeTime)(364), '12 months ago');
        });
        it('should return "1 year ago" for 365-729 days', () => {
            assert.strictEqual((0, time_formatter_1.formatRelativeTime)(365), '1 year ago');
            assert.strictEqual((0, time_formatter_1.formatRelativeTime)(729), '1 year ago');
        });
        it('should return years for 730+ days', () => {
            assert.strictEqual((0, time_formatter_1.formatRelativeTime)(730), '2 years ago');
            assert.strictEqual((0, time_formatter_1.formatRelativeTime)(1095), '3 years ago');
        });
        it('should clamp negative days to "today"', () => {
            // Negative days can occur from clock skew or bad data
            assert.strictEqual((0, time_formatter_1.formatRelativeTime)(-1), 'today');
            assert.strictEqual((0, time_formatter_1.formatRelativeTime)(-100), 'today');
        });
        it('should floor fractional days', () => {
            // 1.9 days → floor to 1 → "yesterday"
            assert.strictEqual((0, time_formatter_1.formatRelativeTime)(1.9), 'yesterday');
            assert.strictEqual((0, time_formatter_1.formatRelativeTime)(0.5), 'today');
            assert.strictEqual((0, time_formatter_1.formatRelativeTime)(29.99), '29 days ago');
        });
    });
});
//# sourceMappingURL=time-formatter.test.js.map