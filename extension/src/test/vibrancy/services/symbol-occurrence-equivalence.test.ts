/**
 * Differential test: the tokenized symbol matcher against the alternation regex
 * it replaced.
 *
 * `collectSymbolOccurrences` originally built one escaped, length-ordered
 * alternation of every candidate name and ran it per line. That shape costs
 * O(candidates) at every source position, so it was replaced by tokenizing
 * dotted identifier chains and looking each up in the candidate Set. The
 * replacement was argued equivalent case by case in review — this file holds
 * that argument to evidence instead.
 *
 * The reference implementation below is the ORIGINAL matcher, preserved
 * verbatim in its matching behavior. Both are run over the same corpora and
 * their full output — symbol, file, line, column — must agree exactly. If a
 * future edit to the tokenizer changes what counts as a usage, this fails and
 * names the input.
 *
 * The directive-skip logic is deliberately NOT reproduced here: it changed on
 * purpose (wrapped `show` clauses, trailing line comments) and is pinned by its
 * own tests in `import-scanner.test.ts`. Corpora here therefore contain no
 * import or export directives, so the two implementations are compared on
 * symbol matching alone.
 */

import '../register-vscode-mock';
import * as assert from 'assert';
import {
    collectSymbolOccurrences,
    DartSource,
} from '../../../vibrancy/services/import-scanner';

/** Flat, comparable shape so assertion failures name the exact disagreement. */
interface FlatHit {
    readonly name: string;
    readonly filePath: string;
    readonly line: number;
    readonly column: number;
}

/**
 * The replaced implementation: one length-ordered, escaped alternation applied
 * per line. Longest-first is what made `ReelText.rich` win over `ReelText`.
 */
function referenceMatcher(
    sources: readonly DartSource[], candidates: ReadonlySet<string>,
): FlatHit[] {
    if (candidates.size === 0) { return []; }
    const ordered = [...candidates].sort((a, b) => b.length - a.length);
    const escaped = ordered.map(c => c.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
    const re = new RegExp(`\\b(${escaped.join('|')})\\b`, 'g');

    const hits: FlatHit[] = [];
    for (const source of sources) {
        const lines = source.text.split('\n');
        for (let i = 0; i < lines.length; i++) {
            re.lastIndex = 0;
            let match: RegExpExecArray | null;
            while ((match = re.exec(lines[i])) !== null) {
                hits.push({
                    name: match[1],
                    filePath: source.path,
                    line: i + 1,
                    column: match.index + 1,
                });
            }
        }
    }
    return hits;
}

/** Flatten the production map into the same comparable shape. */
function flattenActual(
    sources: readonly DartSource[], candidates: ReadonlySet<string>,
): FlatHit[] {
    const out: FlatHit[] = [];
    for (const [name, occurrences] of collectSymbolOccurrences(sources, candidates)) {
        for (const o of occurrences) {
            out.push({ name, filePath: o.filePath, line: o.line, column: o.column });
        }
    }
    return out;
}

/** Order-independent comparison — the two walk source in different orders. */
function sortHits(hits: readonly FlatHit[]): FlatHit[] {
    return [...hits].sort((a, b) =>
        a.filePath.localeCompare(b.filePath)
        || a.line - b.line
        || a.column - b.column
        || a.name.localeCompare(b.name));
}

function assertEquivalent(
    sources: readonly DartSource[],
    candidates: ReadonlySet<string>,
    what: string,
): void {
    assert.deepStrictEqual(
        sortHits(flattenActual(sources, candidates)),
        sortHits(referenceMatcher(sources, candidates)),
        `tokenizer diverged from the alternation regex: ${what}`,
    );
}

function src(path: string, text: string): DartSource {
    return { path, text };
}

describe('collectSymbolOccurrences equivalence with the replaced matcher', () => {
    it('agrees on plain and dotted symbols', () => {
        const sources = [src('lib/a.dart', [
            '  final w = ReelText(key: key);',
            '  ReelText.rich(spans);',
            '  final c = ReelTextController();',
        ].join('\n'))];
        assertEquivalent(
            sources,
            new Set(['ReelText', 'ReelText.rich', 'ReelTextController']),
            'dotted member vs bare owner',
        );
    });

    it('agrees that a candidate is not matched inside a longer identifier', () => {
        // `\b` gives no boundary mid-word, and the tokenizer only trims at
        // dots — both must leave `Reel` unmatched inside `ReelText`.
        const sources = [src('lib/a.dart', 'final w = ReelText(); final r = Reel();')];
        assertEquivalent(sources, new Set(['Reel']), 'prefix of a longer identifier');
    });

    it('agrees on a member name used off an unrelated owner', () => {
        const sources = [src('lib/a.dart', [
            'final a = config.rich;',
            'final b = rich;',
            'final c = other.rich.deep;',
        ].join('\n'))];
        assertEquivalent(sources, new Set(['rich']), 'bare member segment');
    });

    it('agrees on identifiers containing underscores', () => {
        const sources = [src('lib/a.dart', [
            'final a = my_helper();',
            'final b = _private();',
            'final c = my_helper_extra();',
        ].join('\n'))];
        assertEquivalent(
            sources, new Set(['my_helper', '_private']), 'underscore identifiers',
        );
    });

    it('finds a $-leading identifier the alternation regex could not', () => {
        // The one deliberate divergence, found by this file rather than argued:
        // `\b` needs a word character on one side and `$` is not one, so
        // `\b\$generated\b` never matched after a space. Dart generated code
        // uses `$`-prefixed names freely, so the old matcher under-counted them
        // silently. The tokenizer accepts `$` as an identifier start and finds
        // them. Recorded here so the difference stays intentional.
        const sources = [src('lib/a.dart', 'final b = $generated;')];
        const candidates = new Set(['$generated']);

        assert.strictEqual(
            referenceMatcher(sources, candidates).length, 0,
            'the replaced matcher was blind to this',
        );
        const actual = flattenActual(sources, candidates);
        assert.strictEqual(actual.length, 1);
        assert.strictEqual(actual[0].line, 1);
        assert.strictEqual(actual[0].column, 11);
    });

    it('agrees when a dotted candidate is split by whitespace in source', () => {
        // Neither implementation crosses whitespace, so the dotted candidate
        // must go unmatched while its bare owner still matches.
        const sources = [src('lib/a.dart', 'ReelText . rich(x);')];
        assertEquivalent(
            sources, new Set(['ReelText.rich', 'ReelText']), 'whitespace around the dot',
        );
    });

    it('agrees on symbols inside string literals and comments', () => {
        // Both are text matchers with no string or comment awareness. This
        // pins that shared blindness so a future change to one is deliberate.
        const sources = [src('lib/a.dart', [
            "  final s = 'ReelText is great';",
            '  // ReelText mentioned in prose',
            '  /* ReelText in a block */',
        ].join('\n'))];
        assertEquivalent(sources, new Set(['ReelText']), 'strings and comments');
    });

    it('agrees on repeated hits within a single line', () => {
        const sources = [src('lib/a.dart', 'ReelText(ReelText(ReelText()));')];
        assertEquivalent(sources, new Set(['ReelText']), 'multiple hits per line');
    });

    it('agrees on a deep chain with candidates at several depths', () => {
        const sources = [src('lib/a.dart', 'final v = a.b.c.d;')];
        assertEquivalent(
            sources, new Set(['a.b', 'c', 'd', 'a.b.c']), 'overlapping chain candidates',
        );
    });

    it('agrees across a generated multi-file corpus', () => {
        // Breadth rather than depth: many files, many candidates, shapes mixed
        // so a divergence anywhere in the token walk surfaces here.
        const candidates = new Set<string>([
            'ReelText', 'ReelText.rich', 'rich', 'Controller', 'a.b', 'value',
        ]);
        for (let i = 0; i < 200; i++) { candidates.add(`Filler${i}Symbol`); }

        const shapes = [
            '  final w = ReelText(child: Text("ReelText"));',
            '  ReelText.rich(spans, key: key);',
            '  final v = config.rich.value;',
            '  final c = Controller<a.b>();',
            '  return a.b.rich;',
            '  // ReelText.rich in prose',
            '  final none = SomethingElse();',
            '',
        ];
        const sources: DartSource[] = [];
        for (let f = 0; f < 25; f++) {
            const body: string[] = [];
            for (let l = 0; l < 40; l++) {
                body.push(shapes[(f + l) % shapes.length]);
            }
            sources.push(src(`lib/gen/file_${f}.dart`, body.join('\n')));
        }
        assertEquivalent(sources, candidates, 'generated corpus');
    });
});
