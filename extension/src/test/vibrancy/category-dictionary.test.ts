import * as assert from 'assert';
import {
    CATEGORY_DICTIONARY,
    categoryLabel,
    categoryIcon,
    categoryToSeverity,
    categoryToGrade,
    categoryEmoji,
    categoryCssClass,
} from '../../vibrancy/category-dictionary';
import { VibrancyCategory } from '../../vibrancy/types';

/** All VibrancyCategory values — kept in sync with the union type. */
const ALL_CATEGORIES: VibrancyCategory[] = [
    'vibrant', 'stable', 'outdated', 'abandoned', 'end-of-life',
];

describe('category-dictionary', () => {
    describe('CATEGORY_DICTIONARY completeness', () => {
        it('should have an entry for every VibrancyCategory', () => {
            for (const cat of ALL_CATEGORIES) {
                assert.ok(
                    CATEGORY_DICTIONARY[cat],
                    `Missing dictionary entry for '${cat}'`,
                );
            }
        });

        it('every entry should have all required fields', () => {
            for (const cat of ALL_CATEGORIES) {
                const data = CATEGORY_DICTIONARY[cat];
                assert.ok(data.label.length > 0, `${cat}: label is empty`);
                assert.ok(data.shortLabel.length > 0, `${cat}: shortLabel is empty`);
                assert.ok(data.emoji.length > 0, `${cat}: emoji is empty`);
                assert.ok(data.grade.length === 1, `${cat}: grade should be a single letter`);
                assert.ok(data.iconId.length > 0, `${cat}: iconId is empty`);
                assert.ok(data.severity >= 1 && data.severity <= 3, `${cat}: severity out of range`);
                assert.ok(data.cssClass.length > 0, `${cat}: cssClass is empty`);
            }
        });
    });

    describe('accessor functions', () => {
        it('categoryLabel returns full label', () => {
            assert.strictEqual(categoryLabel('vibrant'), 'Vibrant');
            assert.strictEqual(categoryLabel('end-of-life'), 'End of Life');
        });

        it('categoryIcon returns ThemeIcon id', () => {
            assert.strictEqual(categoryIcon('vibrant'), 'pass');
            assert.strictEqual(categoryIcon('stable'), 'info');
            assert.strictEqual(categoryIcon('outdated'), 'warning');
            assert.strictEqual(categoryIcon('end-of-life'), 'error');
        });

        it('categoryToSeverity returns DiagnosticSeverity values', () => {
            // 1=Error, 2=Warning, 3=Information
            assert.strictEqual(categoryToSeverity('end-of-life'), 1);
            assert.strictEqual(categoryToSeverity('abandoned'), 2);
            assert.strictEqual(categoryToSeverity('outdated'), 2);
            assert.strictEqual(categoryToSeverity('stable'), 3);
            assert.strictEqual(categoryToSeverity('vibrant'), 3);
        });

        it('categoryToGrade returns A through F', () => {
            assert.strictEqual(categoryToGrade('vibrant'), 'A');
            assert.strictEqual(categoryToGrade('stable'), 'B');
            assert.strictEqual(categoryToGrade('outdated'), 'C');
            assert.strictEqual(categoryToGrade('abandoned'), 'E');
            assert.strictEqual(categoryToGrade('end-of-life'), 'F');
        });

        it('categoryEmoji returns default emoji', () => {
            assert.strictEqual(categoryEmoji('vibrant'), '🟢');
            assert.strictEqual(categoryEmoji('stable'), '🟡');
            assert.strictEqual(categoryEmoji('outdated'), '🟠');
            assert.strictEqual(categoryEmoji('abandoned'), '🟠');
            assert.strictEqual(categoryEmoji('end-of-life'), '🔴');
        });

        it('categoryCssClass returns CSS class name', () => {
            assert.strictEqual(categoryCssClass('vibrant'), 'vibrant');
            assert.strictEqual(categoryCssClass('end-of-life'), 'eol');
        });
    });

    describe('data consistency', () => {
        it('shortLabel matches label when no abbreviation exists', () => {
            // Only end-of-life uses a different shortLabel ('EOL')
            for (const cat of ALL_CATEGORIES) {
                const data = CATEGORY_DICTIONARY[cat];
                if (cat === 'end-of-life') {
                    assert.strictEqual(data.shortLabel, 'EOL');
                    assert.notStrictEqual(data.shortLabel, data.label);
                } else {
                    assert.strictEqual(data.shortLabel, data.label,
                        `${cat}: shortLabel should equal label when no abbreviation`);
                }
            }
        });

        it('severity decreases as health worsens', () => {
            // vibrant/stable (3) > outdated/abandoned (2) > end-of-life (1)
            assert.ok(
                categoryToSeverity('vibrant') > categoryToSeverity('outdated'),
            );
            assert.ok(
                categoryToSeverity('outdated') > categoryToSeverity('end-of-life'),
            );
        });

        it('grades follow alphabetical order by health', () => {
            const grades = ALL_CATEGORIES.map(c => categoryToGrade(c));
            // A < B < C < E < F (D is reserved)
            assert.strictEqual(grades[0], 'A'); // vibrant
            assert.strictEqual(grades[4], 'F'); // end-of-life
        });
    });
});
