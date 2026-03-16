import * as assert from 'assert';
import { classifyAdoption, AdoptionInput } from '../../../vibrancy/scoring/adoption-classifier';

function makeInput(overrides: Partial<AdoptionInput> = {}): AdoptionInput {
    return {
        pubPoints: 0,
        verifiedPublisher: false,
        isDiscontinued: false,
        knownIssueStatus: null,
        knownIssueReason: null,
        exists: true,
        ...overrides,
    };
}

describe('adoption-classifier', () => {
    describe('classifyAdoption', () => {
        it('should return healthy for high points and verified publisher', () => {
            const result = classifyAdoption(makeInput({
                pubPoints: 120, verifiedPublisher: true,
            }));
            assert.strictEqual(result.tier, 'healthy');
            assert.ok(result.badgeText.includes('120'));
            assert.ok(result.badgeText.includes('verified'));
        });

        it('should return caution for medium points and unverified', () => {
            const result = classifyAdoption(makeInput({
                pubPoints: 45, verifiedPublisher: false,
            }));
            assert.strictEqual(result.tier, 'caution');
            assert.ok(result.badgeText.includes('45'));
            assert.ok(result.badgeText.includes('unverified'));
        });

        it('should return caution for high points but unverified', () => {
            const result = classifyAdoption(makeInput({
                pubPoints: 120, verifiedPublisher: false,
            }));
            assert.strictEqual(result.tier, 'caution');
            assert.ok(result.badgeText.includes('120'));
        });

        it('should return warning for discontinued package', () => {
            const result = classifyAdoption(makeInput({
                pubPoints: 100, verifiedPublisher: true,
                isDiscontinued: true,
            }));
            assert.strictEqual(result.tier, 'warning');
            assert.ok(result.badgeText.includes('Discontinued'));
        });

        it('should return warning for known end-of-life issue', () => {
            const result = classifyAdoption(makeInput({
                knownIssueStatus: 'end-of-life',
                knownIssueReason: 'replaced by new_pkg',
            }));
            assert.strictEqual(result.tier, 'warning');
            assert.ok(result.badgeText.includes('replaced by new_pkg'));
        });

        it('should return unknown when not found on pub.dev', () => {
            const result = classifyAdoption(makeInput({ exists: false }));
            assert.strictEqual(result.tier, 'unknown');
            assert.ok(result.badgeText.includes('Not found'));
        });

        it('should return caution for zero points but existing', () => {
            const result = classifyAdoption(makeInput({
                pubPoints: 0, exists: true,
            }));
            assert.strictEqual(result.tier, 'caution');
        });

        it('should include point count in healthy badge', () => {
            const result = classifyAdoption(makeInput({
                pubPoints: 140, verifiedPublisher: true,
            }));
            assert.ok(result.badgeText.includes('140'));
        });

        it('should include point count in caution badge', () => {
            const result = classifyAdoption(makeInput({
                pubPoints: 55,
            }));
            assert.ok(result.badgeText.includes('55'));
        });

        it('should prioritize discontinued over high score', () => {
            const result = classifyAdoption(makeInput({
                pubPoints: 150, verifiedPublisher: true,
                isDiscontinued: true,
            }));
            assert.strictEqual(result.tier, 'warning');
        });

        it('should prioritize not-found over known issue', () => {
            const result = classifyAdoption(makeInput({
                exists: false,
                knownIssueStatus: 'end-of-life',
            }));
            assert.strictEqual(result.tier, 'unknown');
        });

        it('should show default reason for end-of-life without reason', () => {
            const result = classifyAdoption(makeInput({
                knownIssueStatus: 'end-of-life',
                knownIssueReason: null,
            }));
            assert.strictEqual(result.tier, 'warning');
            assert.ok(result.badgeText.includes('end of life'));
        });

        it('should return caution for verified publisher with low points', () => {
            const result = classifyAdoption(makeInput({
                pubPoints: 30, verifiedPublisher: true,
            }));
            assert.strictEqual(result.tier, 'caution');
            assert.ok(result.badgeText.includes('verified'));
        });
    });
});
