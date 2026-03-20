import * as assert from 'assert';
import { ReviewStateService } from '../../../vibrancy/services/review-state';

/** In-memory mock of vscode.Memento for testing. */
class MockMemento {
    private _store = new Map<string, unknown>();

    get<T>(key: string): T | undefined;
    get<T>(key: string, defaultValue: T): T;
    get<T>(key: string, defaultValue?: T): T | undefined {
        const val = this._store.get(key);
        return val !== undefined ? val as T : defaultValue;
    }

    async update(key: string, value: unknown): Promise<void> {
        if (value === undefined) {
            this._store.delete(key);
        } else {
            this._store.set(key, value);
        }
    }

    keys(): readonly string[] {
        return [...this._store.keys()];
    }
}

describe('ReviewStateService', () => {
    let memento: MockMemento;
    let service: ReviewStateService;

    beforeEach(() => {
        memento = new MockMemento();
        service = new ReviewStateService(memento as never);
    });

    describe('getReviews', () => {
        it('should return empty array when no reviews exist', () => {
            const reviews = service.getReviews('http', '1.0.0');
            assert.deepStrictEqual(reviews, []);
        });
    });

    describe('setReview', () => {
        it('should persist a review entry', async () => {
            await service.setReview('http', '1.0.0', 42, 'applicable', 'Needs migration');

            const reviews = service.getReviews('http', '1.0.0');
            assert.strictEqual(reviews.length, 1);
            assert.strictEqual(reviews[0].itemNumber, 42);
            assert.strictEqual(reviews[0].status, 'applicable');
            assert.strictEqual(reviews[0].notes, 'Needs migration');
            assert.strictEqual(reviews[0].packageName, 'http');
        });

        it('should update an existing review entry', async () => {
            await service.setReview('http', '1.0.0', 42, 'unreviewed');
            await service.setReview('http', '1.0.0', 42, 'not-applicable', 'Wrong branch');

            const reviews = service.getReviews('http', '1.0.0');
            assert.strictEqual(reviews.length, 1);
            assert.strictEqual(reviews[0].status, 'not-applicable');
            assert.strictEqual(reviews[0].notes, 'Wrong branch');
        });

        it('should handle multiple packages independently', async () => {
            await service.setReview('http', '1.0.0', 1, 'reviewed');
            await service.setReview('dio', '5.0.0', 2, 'applicable');

            assert.strictEqual(service.getReviews('http', '1.0.0').length, 1);
            assert.strictEqual(service.getReviews('dio', '5.0.0').length, 1);
        });

        it('should keep reviews separate by version', async () => {
            await service.setReview('http', '1.0.0', 1, 'reviewed');
            await service.setReview('http', '2.0.0', 2, 'applicable');

            assert.strictEqual(service.getReviews('http', '1.0.0').length, 1);
            assert.strictEqual(service.getReviews('http', '2.0.0').length, 1);
        });
    });

    describe('getSummary', () => {
        it('should return correct counts', async () => {
            await service.setReview('http', '1.0.0', 1, 'reviewed');
            await service.setReview('http', '1.0.0', 2, 'applicable');
            await service.setReview('http', '1.0.0', 3, 'not-applicable');

            const summary = service.getSummary('http', '1.0.0', 5);
            assert.strictEqual(summary.total, 5);
            assert.strictEqual(summary.triaged, 3);
            assert.strictEqual(summary.reviewed, 1);
            assert.strictEqual(summary.applicable, 1);
            assert.strictEqual(summary.notApplicable, 1);
            assert.strictEqual(summary.unreviewed, 2);
        });

        it('should return all unreviewed when no reviews exist', () => {
            const summary = service.getSummary('http', '1.0.0', 10);
            assert.strictEqual(summary.total, 10);
            assert.strictEqual(summary.triaged, 0);
            assert.strictEqual(summary.unreviewed, 10);
        });
    });

    describe('clearPackage', () => {
        it('should remove all reviews for a package at a version', async () => {
            await service.setReview('http', '1.0.0', 1, 'reviewed');
            await service.setReview('http', '1.0.0', 2, 'applicable');
            await service.clearPackage('http', '1.0.0');

            assert.deepStrictEqual(service.getReviews('http', '1.0.0'), []);
        });

        it('should not affect other packages', async () => {
            await service.setReview('http', '1.0.0', 1, 'reviewed');
            await service.setReview('dio', '5.0.0', 2, 'applicable');
            await service.clearPackage('http', '1.0.0');

            assert.strictEqual(service.getReviews('dio', '5.0.0').length, 1);
        });
    });

    describe('pruneStale', () => {
        it('should remove reviews for packages with changed versions', async () => {
            await service.setReview('http', '1.0.0', 1, 'reviewed');
            await service.setReview('dio', '5.0.0', 2, 'applicable');

            // http upgraded to 2.0.0, dio stayed at 5.0.0
            const currentVersions = new Map([
                ['http', '2.0.0'],
                ['dio', '5.0.0'],
            ]);

            const pruned = await service.pruneStale(currentVersions);
            assert.strictEqual(pruned, 1);
            // http reviews for 1.0.0 should be gone
            assert.deepStrictEqual(service.getReviews('http', '1.0.0'), []);
            // dio reviews should remain
            assert.strictEqual(service.getReviews('dio', '5.0.0').length, 1);
        });

        it('should return 0 when nothing is stale', async () => {
            await service.setReview('http', '1.0.0', 1, 'reviewed');

            const currentVersions = new Map([['http', '1.0.0']]);
            const pruned = await service.pruneStale(currentVersions);
            assert.strictEqual(pruned, 0);
        });

        it('should remove reviews for packages no longer in the project', async () => {
            await service.setReview('http', '1.0.0', 1, 'reviewed');

            // Empty project — http was removed
            const currentVersions = new Map<string, string>();
            const pruned = await service.pruneStale(currentVersions);
            assert.strictEqual(pruned, 1);
        });
    });
});
