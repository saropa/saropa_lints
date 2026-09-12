/** * Module overview (comment coverage pass). * comment-coverage: module overview (batch). * * Extension Jest tests: validates commands, webviews, parsers, and state against VS Code APIs (often with local mocks). */
import * as assert from 'assert';
import { CiThresholds, CiPlatform } from '../../../vibrancy/types';
import {
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
            assert.ok(result.includes('if (outdatedCount > maxOutdated)'));
            // A non-zero exit path so the CI job actually fails.
            assert.ok(result.includes('exit(failed ? 1 : 0)'));
            assert.ok(result.includes('failed = true'));
        });

        it('should not fabricate a vulnerability data source', () => {
            const result = generateGitHubActions(defaultThresholds);

            // failOnVulnerability has no data source from `pub outdated`; the
            // generated script must say so rather than pretending to check it.
            assert.ok(result.includes('no vulnerability data'));
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

            assert.ok(result.includes('cirrusci/flutter:stable'));
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

            assert.ok(result.includes('if (outdatedCount > maxOutdated)'));
            assert.ok(result.includes('exit(failed ? 1 : 0)'));
            assert.ok(result.includes('failed = true'));
        });

        it('should not fabricate a vulnerability data source', () => {
            const result = generateGitLabCi(defaultThresholds);

            assert.ok(result.includes('no vulnerability data'));
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

            assert.ok(result.includes('MAX_EOL=2'));
            assert.ok(result.includes('MAX_OUTDATED=5'));
            assert.ok(result.includes('MIN_AVG_VIBRANCY=60'));
            assert.ok(result.includes('FAIL_ON_VULN=true'));
        });

        it('should actually execute the Dart checker instead of piping it into a non-reading stdin', () => {
            const result = generateShellScript(defaultThresholds);

            assert.ok(!result.includes("dart run <<'DART_SCRIPT'"));
            assert.ok(!/dart run\s*<</.test(result));
            assert.ok(/cat > \S*\.dart <<'DART_SCRIPT'/.test(result));
            assert.ok(/dart run \S*\.dart/.test(result));
        });

        it('should compare parsed counts against thresholds and exit non-zero on breach', () => {
            const result = generateShellScript(defaultThresholds);

            assert.ok(result.includes('if (outdatedCount > maxOutdated)'));
            assert.ok(result.includes('exit(failed ? 1 : 0)'));
            assert.ok(result.includes('failed = true'));
            // `set -e` must be present so the script exits with the Dart
            // checker's non-zero code instead of swallowing it.
            assert.ok(result.includes('set -e'));
        });

        it('should not fabricate a vulnerability data source', () => {
            const result = generateShellScript(defaultThresholds);

            assert.ok(result.includes('no vulnerability data'));
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

        it('should mention CLI alternative', () => {
            const result = generateShellScript(defaultThresholds);

            assert.ok(result.includes('saropa_vibrancy_cli'));
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
            assert.ok(shell.includes('FAIL_ON_VULN=false'));
        });
    });
});
