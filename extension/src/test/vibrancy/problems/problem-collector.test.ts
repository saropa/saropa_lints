import * as assert from 'assert';
import { collectProblemsForPackage } from '../../../vibrancy/problems/problem-collector';
import { ProblemRegistry } from '../../../vibrancy/problems/problem-registry';
import { makeMinimalResult } from '../test-helpers';

describe('ProblemCollector', () => {
    describe('collectProblemsForPackage', () => {
        it('should add unused problem when isUnused and section is dependencies', () => {
            const registry = new ProblemRegistry();
            const result = {
                ...makeMinimalResult({ name: 'unused_pkg', section: 'dependencies' }),
                isUnused: true,
            };
            collectProblemsForPackage(result, 5, new Map(), new Map(), registry);
            const problems = registry.getForPackage('unused_pkg');
            assert.strictEqual(problems.some(p => p.type === 'unused'), true);
        });

        it('should not add unused problem when isUnused but section is dev_dependencies', () => {
            const registry = new ProblemRegistry();
            const result = {
                ...makeMinimalResult({ name: 'build_runner', section: 'dev_dependencies' }),
                isUnused: true,
            };
            collectProblemsForPackage(result, 5, new Map(), new Map(), registry);
            const problems = registry.getForPackage('build_runner');
            assert.strictEqual(problems.some(p => p.type === 'unused'), false);
        });
    });
});
