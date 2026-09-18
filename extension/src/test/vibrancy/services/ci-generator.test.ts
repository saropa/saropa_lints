/** * Module overview (comment coverage pass). * comment-coverage: module overview (batch). * * Extension Jest tests: validates commands, webviews, parsers, and state against VS Code APIs (often with local mocks). */
import * as assert from 'assert';
import { execFileSync, spawnSync } from 'child_process';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { CiThresholds, CiPlatform } from '../../../vibrancy/types';
import {
    buildCheckerScript,
    generateCiWorkflow,
    generateGitHubActions,
    generateGitLabCi,
    generateShellScript,
    getDefaultOutputPath,
    getPlatformDisplayName,
    getAvailablePlatforms,
} from '../../../vibrancy/services/ci-generator';

/**
 * Golden-style tests for **ci-generator**: workflow YAML / shell snippets for each [CiPlatform],
 * default output paths, display names, and threshold wiring from [CiThresholds].
 */

describe('ci-generator', () => {
    const defaultThresholds: CiThresholds = {
        maxAbandoned: 3,
        maxEndOfLife: 2,
        maxOutdated: 5,
        minAverageVibrancy: 60,
        failOnVulnerability: true,
    };

    describe('generateCiWorkflow', () => {
        it('should route to GitHub Actions generator', () => {
            const result = generateCiWorkflow('github-actions', defaultThresholds);

            assert.ok(result.includes('name: Dependency Health Check'));
            assert.ok(result.includes('actions/github-script'));
        });

        it('should route to GitLab CI generator', () => {
            const result = generateCiWorkflow('gitlab-ci', defaultThresholds);

            assert.ok(result.includes('vibrancy-check:'));
            assert.ok(result.includes('stage: test'));
        });

        it('should route to shell script generator', () => {
            const result = generateCiWorkflow('shell-script', defaultThresholds);

            assert.ok(result.includes('#!/bin/bash'));
            assert.ok(result.includes('flutter pub get'));
        });
    });

    describe('generateGitHubActions', () => {
        it('should generate valid YAML structure', () => {
            const result = generateGitHubActions(defaultThresholds);

            assert.ok(result.includes('name:'));
            assert.ok(result.includes('on:'));
            assert.ok(result.includes('jobs:'));
            assert.ok(result.includes('runs-on:'));
            assert.ok(result.includes('steps:'));
        });

        it('should include pubspec file triggers', () => {
            const result = generateGitHubActions(defaultThresholds);

            assert.ok(result.includes("'pubspec.yaml'"));
            assert.ok(result.includes("'pubspec.lock'"));
        });

        it('should include Flutter setup action', () => {
            const result = generateGitHubActions(defaultThresholds);

            assert.ok(result.includes('subosito/flutter-action@v2'));
        });

        it('should include threshold values in script', () => {
            const result = generateGitHubActions(defaultThresholds);

            assert.ok(result.includes('const maxEol = 2'));
            assert.ok(result.includes('const maxOutdated = 5'));
            assert.ok(result.includes('const minAvgVibrancy = 60'));
            assert.ok(result.includes('const failOnVuln = true'));
        });

        it('should actually execute the Dart checker instead of piping it into a non-reading stdin', () => {
            const result = generateGitHubActions(defaultThresholds);

            // `dart run` does not read a program from stdin, so a heredoc
            // piped straight into it is not a valid invocation.
            assert.ok(!result.includes("dart run <<'DART_SCRIPT'"));
            assert.ok(!/dart run\s*<</.test(result));

            // The Dart source must be written to a real file and that file
            // must actually be run.
            assert.ok(/cat > \S*\.dart <<'DART_SCRIPT'/.test(result));
            assert.ok(/dart run \S*\.dart/.test(result));
        });

        it('should compare parsed counts against thresholds and exit non-zero on breach', () => {
            const result = generateGitHubActions(defaultThresholds);

            // A real comparison against a threshold, not just a print().
            assert.ok(result.includes('if (outdated.length > maxOutdated)'));
            // A non-zero exit path so the CI job actually fails.
            assert.ok(result.includes('exit(failed ? 1 : 0)'));
            assert.ok(result.includes('failed = true'));
        });

        it('fails on a security advisory, from pub outdated\'s own advisory data', () => {
            const result = generateGitHubActions(defaultThresholds);

            assert.ok(result.includes("pkg['isCurrentAffectedByAdvisory'] == true"));
            assert.ok(!result.includes('no vulnerability data'));
        });

        it('should handle zero thresholds', () => {
            const thresholds: CiThresholds = {
                maxAbandoned: 0,
                maxEndOfLife: 0,
                maxOutdated: 0,
                minAverageVibrancy: 0,
                failOnVulnerability: false,
            };

            const result = generateGitHubActions(thresholds);

            assert.ok(result.includes('const maxEol = 0'));
            assert.ok(result.includes('const failOnVuln = false'));
        });

        it('should include artifact upload step', () => {
            const result = generateGitHubActions(defaultThresholds);

            assert.ok(result.includes('actions/upload-artifact@v4'));
            assert.ok(result.includes('dependency-report'));
        });

        it('should include PR comment step', () => {
            const result = generateGitHubActions(defaultThresholds);

            assert.ok(result.includes('actions/github-script@v7'));
            assert.ok(result.includes('createComment'));
        });

        it('should include header comment', () => {
            const result = generateGitHubActions(defaultThresholds);

            assert.ok(result.startsWith('# Generated by Package Vibrancy'));
        });
    });

    describe('generateGitLabCi', () => {
        it('should generate valid GitLab CI structure', () => {
            const result = generateGitLabCi(defaultThresholds);

            assert.ok(result.includes('vibrancy-check:'));
            assert.ok(result.includes('stage: test'));
            assert.ok(result.includes('image:'));
            assert.ok(result.includes('script:'));
        });

        it('should use Flutter Docker image', () => {
            const result = generateGitLabCi(defaultThresholds);

            // The Docker Hub image is no longer updated; Cirrus Labs publish here.
            assert.ok(result.includes('ghcr.io/cirruslabs/flutter:stable'));
        });

        it('should include pubspec file triggers', () => {
            const result = generateGitLabCi(defaultThresholds);

            assert.ok(result.includes('pubspec.yaml'));
            assert.ok(result.includes('pubspec.lock'));
        });

        it('should include threshold values', () => {
            const result = generateGitLabCi(defaultThresholds);

            assert.ok(result.includes('const maxEol = 2'));
            assert.ok(result.includes('const maxOutdated = 5'));
            assert.ok(result.includes('const minAvgVibrancy = 60'));
        });

        it('should actually execute the Dart checker instead of piping it into a non-reading stdin', () => {
            const result = generateGitLabCi(defaultThresholds);

            assert.ok(!result.includes("dart run <<'DART_SCRIPT'"));
            assert.ok(!/dart run\s*<</.test(result));
            assert.ok(/cat > \S*\.dart <<'DART_SCRIPT'/.test(result));
            assert.ok(/dart run \S*\.dart/.test(result));
        });

        it('should compare parsed counts against thresholds and exit non-zero on breach', () => {
            const result = generateGitLabCi(defaultThresholds);

            assert.ok(result.includes('if (outdated.length > maxOutdated)'));
            assert.ok(result.includes('exit(failed ? 1 : 0)'));
            assert.ok(result.includes('failed = true'));
        });

        it('fails on a security advisory, from pub outdated\'s own advisory data', () => {
            const result = generateGitLabCi(defaultThresholds);

            assert.ok(result.includes("pkg['isCurrentAffectedByAdvisory'] == true"));
            assert.ok(!result.includes('no vulnerability data'));
        });

        it('should include artifact configuration', () => {
            const result = generateGitLabCi(defaultThresholds);

            assert.ok(result.includes('artifacts:'));
            assert.ok(result.includes('paths:'));
            assert.ok(result.includes('outdated.json'));
        });
    });

    describe('generateShellScript', () => {
        it('should start with shebang', () => {
            const result = generateShellScript(defaultThresholds);

            assert.ok(result.startsWith('#!/bin/bash'));
        });

        it('should include threshold variables', () => {
            const result = generateShellScript(defaultThresholds);

            // In the checker itself: shell variables here were never read by
            // it, so editing them silently changed nothing.
            assert.ok(result.includes('const maxEol = 2;'));
            assert.ok(result.includes('const maxOutdated = 5;'));
            assert.ok(result.includes('const minAvgVibrancy = 60;'));
            assert.ok(result.includes('const failOnVuln = true;'));
        });

        it('should actually execute the Dart checker instead of piping it into a non-reading stdin', () => {
            const result = generateShellScript(defaultThresholds);

            assert.ok(!result.includes("dart run <<'DART_SCRIPT'"));
            assert.ok(!/dart run\s*<</.test(result));
            assert.ok(result.includes(`cat > "$work/vibrancy_check.dart" <<'DART_SCRIPT'`));
            assert.ok(result.includes('dart run "$work/vibrancy_check.dart" "$work/outdated.json"'));
        });

        it('should compare parsed counts against thresholds and exit non-zero on breach', () => {
            const result = generateShellScript(defaultThresholds);

            assert.ok(result.includes('if (outdated.length > maxOutdated)'));
            assert.ok(result.includes('exit(failed ? 1 : 0)'));
            assert.ok(result.includes('failed = true'));
            // `set -e` must be present so the script exits with the Dart
            // checker's non-zero code instead of swallowing it.
            assert.ok(result.includes('set -e'));
        });

        it('fails on a security advisory, from pub outdated\'s own advisory data', () => {
            const result = generateShellScript(defaultThresholds);

            assert.ok(result.includes("pkg['isCurrentAffectedByAdvisory'] == true"));
            assert.ok(!result.includes('no vulnerability data'));
        });

        it('should check for Flutter availability', () => {
            const result = generateShellScript(defaultThresholds);

            assert.ok(result.includes('command -v flutter'));
            assert.ok(result.includes('Flutter not found'));
        });

        it('should run flutter pub get', () => {
            const result = generateShellScript(defaultThresholds);

            assert.ok(result.includes('flutter pub get'));
        });

        it('should run flutter pub outdated', () => {
            const result = generateShellScript(defaultThresholds);

            assert.ok(result.includes('flutter pub outdated --json'));
        });

        it('works in a private temporary directory, not fixed /tmp paths', () => {
            const result = generateShellScript(defaultThresholds);

            assert.ok(result.includes('work="$(mktemp -d)"'));
            assert.ok(!result.includes('/tmp/'));
        });
    });

    describe('getDefaultOutputPath', () => {
        it('should return GitHub Actions path', () => {
            const path = getDefaultOutputPath('github-actions');

            assert.strictEqual(path, '.github/workflows/vibrancy-check.yml');
        });

        it('should return GitLab CI path', () => {
            const path = getDefaultOutputPath('gitlab-ci');

            assert.strictEqual(path, '.gitlab-ci-vibrancy.yml');
        });

        it('should return shell script path', () => {
            const path = getDefaultOutputPath('shell-script');

            assert.strictEqual(path, 'scripts/vibrancy-check.sh');
        });
    });

    describe('getPlatformDisplayName', () => {
        it('should return GitHub Actions display name', () => {
            assert.strictEqual(getPlatformDisplayName('github-actions'), 'GitHub Actions');
        });

        it('should return GitLab CI display name', () => {
            assert.strictEqual(getPlatformDisplayName('gitlab-ci'), 'GitLab CI');
        });

        it('should return shell script display name', () => {
            assert.strictEqual(getPlatformDisplayName('shell-script'), 'Shell Script (portable)');
        });
    });

    describe('getAvailablePlatforms', () => {
        it('should return all three platforms', () => {
            const platforms = getAvailablePlatforms();

            assert.strictEqual(platforms.length, 3);
        });

        it('should include GitHub Actions', () => {
            const platforms = getAvailablePlatforms();
            const gh = platforms.find(p => p.id === 'github-actions');

            assert.ok(gh);
            assert.ok(gh.label.includes('GitHub'));
            assert.ok(gh.description.includes('.github'));
        });

        it('should include GitLab CI', () => {
            const platforms = getAvailablePlatforms();
            const gl = platforms.find(p => p.id === 'gitlab-ci');

            assert.ok(gl);
            assert.ok(gl.label.includes('GitLab'));
        });

        it('should include shell script', () => {
            const platforms = getAvailablePlatforms();
            const sh = platforms.find(p => p.id === 'shell-script');

            assert.ok(sh);
            assert.ok(sh.label.includes('Shell'));
            assert.ok(sh.description.includes('portable'));
        });

        it('should have unique ids', () => {
            const platforms = getAvailablePlatforms();
            const ids = platforms.map(p => p.id);
            const uniqueIds = new Set(ids);

            assert.strictEqual(ids.length, uniqueIds.size);
        });
    });

    describe('threshold interpolation edge cases', () => {
        it('should handle large threshold values', () => {
            const thresholds: CiThresholds = {
                maxAbandoned: 50,
                maxEndOfLife: 100,
                maxOutdated: 200,
                minAverageVibrancy: 95,
                failOnVulnerability: true,
            };

            const github = generateGitHubActions(thresholds);
            const gitlab = generateGitLabCi(thresholds);
            const shell = generateShellScript(thresholds);

            assert.ok(github.includes('100'));
            assert.ok(gitlab.includes('100'));
            assert.ok(shell.includes('100'));
        });

        it('should handle all-zero thresholds', () => {
            const thresholds: CiThresholds = {
                maxAbandoned: 0,
                maxEndOfLife: 0,
                maxOutdated: 0,
                minAverageVibrancy: 0,
                failOnVulnerability: false,
            };

            const github = generateGitHubActions(thresholds);
            const shell = generateShellScript(thresholds);

            assert.ok(github.includes('const maxEol = 0'));
            assert.ok(shell.includes('const failOnVuln = false;'));
        });
    });

    describe('the generated checker, run for real', () => {
        // `pub outdated --json` shape, with the cases that decide the count.
        const outdatedJson = {
            packages: [
                // Direct, behind, and affected by an advisory.
                { package: 'http', kind: 'direct', isDiscontinued: false, isCurrentAffectedByAdvisory: true,
                  current: { version: '0.13.0' }, latest: { version: '1.6.0' } },
                // Dev, behind.
                { package: 'lints', kind: 'dev', isDiscontinued: false, isCurrentAffectedByAdvisory: false,
                  current: { version: '2.0.0' }, latest: { version: '6.1.0' } },
                // Direct, 0.x minor bump: behind (and breaking).
                { package: 'zero', kind: 'direct', isDiscontinued: true, isCurrentAffectedByAdvisory: false,
                  current: { version: '0.3.1' }, latest: { version: '0.4.0' } },
                // Direct, up to date.
                { package: 'path', kind: 'direct', isDiscontinued: false, isCurrentAffectedByAdvisory: false,
                  current: { version: '1.9.0' }, latest: { version: '1.9.0' } },
                // Direct, on a pre-release AHEAD of the latest stable: not behind.
                { package: 'ahead', kind: 'direct', isDiscontinued: false, isCurrentAffectedByAdvisory: false,
                  current: { version: '2.0.0-dev.1' }, latest: { version: '1.9.0' } },
                // Transitive and behind: pinned by others, not counted.
                { package: 'meta', kind: 'transitive', isDiscontinued: false, isCurrentAffectedByAdvisory: true,
                  current: { version: '1.0.0' }, latest: { version: '2.0.0' } },
                // Not resolved in this project.
                { package: 'web', kind: 'transitive', current: null, latest: { version: '1.1.1' } },
            ],
        };
        const hasDart = spawnSync('dart', ['--version']).status === 0;

        function runChecker(thresholds: CiThresholds): { status: number | null; summary: Record<string, unknown>; out: string } {
            const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'vibrancy-check-'));
            try {
                fs.writeFileSync(path.join(dir, 'outdated.json'), JSON.stringify(outdatedJson));
                fs.writeFileSync(path.join(dir, 'check.dart'), buildCheckerScript(thresholds));
                const res = spawnSync('dart', ['run', 'check.dart', 'outdated.json', 'summary.json'], {
                    cwd: dir,
                    encoding: 'utf8',
                    timeout: 120_000,
                });
                const summary = JSON.parse(fs.readFileSync(path.join(dir, 'summary.json'), 'utf8'));
                return { status: res.status, summary, out: res.stdout };
            } finally {
                fs.rmSync(dir, { recursive: true, force: true });
            }
        }

        it('counts direct and dev dependencies that are behind, and nothing else', function () {
            if (!hasDart) this.skip();
            this.timeout(180_000);
            const { status, summary } = runChecker({ ...defaultThresholds, maxOutdated: 3, failOnVulnerability: false });
            assert.strictEqual(summary['outdated'], 3); // http, lints, zero
            assert.deepStrictEqual(summary['vulnerable'], ['http']); // meta is transitive
            assert.deepStrictEqual(summary['discontinued'], ['zero']);
            assert.strictEqual(status, 0);
        });

        it('exits 1 when outdated dependencies exceed the maximum', function () {
            if (!hasDart) this.skip();
            this.timeout(180_000);
            const { status, summary } = runChecker({ ...defaultThresholds, maxOutdated: 2, failOnVulnerability: false });
            assert.strictEqual(status, 1);
            assert.strictEqual(summary['failed'], true);
        });

        it('exits 1 on a security advisory when failOnVulnerability is set', function () {
            if (!hasDart) this.skip();
            this.timeout(180_000);
            const { status, out } = runChecker({ ...defaultThresholds, maxOutdated: 10, failOnVulnerability: true });
            assert.strictEqual(status, 1);
            assert.ok(out.includes('security advisory: http'));
        });

        it('embeds exactly this checker in every platform, as valid YAML', () => {
            let yaml: { load(text: string): unknown } | undefined;
            try {
                // eslint-disable-next-line @typescript-eslint/no-require-imports
                yaml = require('js-yaml');
            } catch {
                yaml = undefined;
            }
            // The YAML platforms drop the checker's final newline before the
            // indented terminator; the program is otherwise byte-identical.
            const checker = buildCheckerScript(defaultThresholds).trimEnd();
            const heredoc = (text: string): string => {
                const m = /<<'DART_SCRIPT'\n([\s\S]*?)^DART_SCRIPT$/m.exec(text);
                assert.ok(m, 'heredoc found');
                return m[1].trimEnd();
            };

            const gh = generateGitHubActions(defaultThresholds);
            const glab = generateGitLabCi(defaultThresholds);
            if (yaml) {
                const ghDoc = yaml.load(gh) as { jobs: Record<string, { steps: { id?: string; run?: string }[] }> };
                const step = ghDoc.jobs['vibrancy-check'].steps.find((x) => x.id === 'health-check');
                assert.strictEqual(heredoc(step!.run!), checker);
                const glDoc = yaml.load(glab) as Record<string, { script: string[] }>;
                const block = glDoc['vibrancy-check'].script.find((x) => x.includes('DART_SCRIPT'));
                assert.strictEqual(heredoc(block!), checker);
            }
            assert.strictEqual(heredoc(generateShellScript(defaultThresholds)), checker);
        });

        it('the shell script passes bash syntax checking', function () {
            const bash = spawnSync('bash', ['--version']);
            if (bash.status !== 0) this.skip();
            const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'vibrancy-sh-'));
            try {
                const file = path.join(dir, 'check.sh');
                fs.writeFileSync(file, generateShellScript(defaultThresholds));
                execFileSync('bash', ['-n', file]);
            } finally {
                fs.rmSync(dir, { recursive: true, force: true });
            }
        });
    });
});
