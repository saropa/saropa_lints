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
const ci_generator_1 = require("../../../vibrancy/services/ci-generator");
describe('ci-generator', () => {
    const defaultThresholds = {
        maxStale: 3,
        maxEndOfLife: 2,
        maxLegacyLocked: 5,
        minAverageVibrancy: 60,
        failOnVulnerability: true,
    };
    describe('generateCiWorkflow', () => {
        it('should route to GitHub Actions generator', () => {
            const result = (0, ci_generator_1.generateCiWorkflow)('github-actions', defaultThresholds);
            assert.ok(result.includes('name: Dependency Health Check'));
            assert.ok(result.includes('actions/github-script'));
        });
        it('should route to GitLab CI generator', () => {
            const result = (0, ci_generator_1.generateCiWorkflow)('gitlab-ci', defaultThresholds);
            assert.ok(result.includes('vibrancy-check:'));
            assert.ok(result.includes('stage: test'));
        });
        it('should route to shell script generator', () => {
            const result = (0, ci_generator_1.generateCiWorkflow)('shell-script', defaultThresholds);
            assert.ok(result.includes('#!/bin/bash'));
            assert.ok(result.includes('flutter pub get'));
        });
    });
    describe('generateGitHubActions', () => {
        it('should generate valid YAML structure', () => {
            const result = (0, ci_generator_1.generateGitHubActions)(defaultThresholds);
            assert.ok(result.includes('name:'));
            assert.ok(result.includes('on:'));
            assert.ok(result.includes('jobs:'));
            assert.ok(result.includes('runs-on:'));
            assert.ok(result.includes('steps:'));
        });
        it('should include pubspec file triggers', () => {
            const result = (0, ci_generator_1.generateGitHubActions)(defaultThresholds);
            assert.ok(result.includes("'pubspec.yaml'"));
            assert.ok(result.includes("'pubspec.lock'"));
        });
        it('should include Flutter setup action', () => {
            const result = (0, ci_generator_1.generateGitHubActions)(defaultThresholds);
            assert.ok(result.includes('subosito/flutter-action@v2'));
        });
        it('should include threshold values in script', () => {
            const result = (0, ci_generator_1.generateGitHubActions)(defaultThresholds);
            assert.ok(result.includes('const maxEol = 2'));
            assert.ok(result.includes('const maxLegacy = 5'));
            assert.ok(result.includes('const minAvgVibrancy = 60'));
            assert.ok(result.includes('const failOnVuln = true'));
        });
        it('should handle zero thresholds', () => {
            const thresholds = {
                maxStale: 0,
                maxEndOfLife: 0,
                maxLegacyLocked: 0,
                minAverageVibrancy: 0,
                failOnVulnerability: false,
            };
            const result = (0, ci_generator_1.generateGitHubActions)(thresholds);
            assert.ok(result.includes('const maxEol = 0'));
            assert.ok(result.includes('const failOnVuln = false'));
        });
        it('should include artifact upload step', () => {
            const result = (0, ci_generator_1.generateGitHubActions)(defaultThresholds);
            assert.ok(result.includes('actions/upload-artifact@v4'));
            assert.ok(result.includes('dependency-report'));
        });
        it('should include PR comment step', () => {
            const result = (0, ci_generator_1.generateGitHubActions)(defaultThresholds);
            assert.ok(result.includes('actions/github-script@v7'));
            assert.ok(result.includes('createComment'));
        });
        it('should include header comment', () => {
            const result = (0, ci_generator_1.generateGitHubActions)(defaultThresholds);
            assert.ok(result.startsWith('# Generated by Saropa Package Vibrancy'));
        });
    });
    describe('generateGitLabCi', () => {
        it('should generate valid GitLab CI structure', () => {
            const result = (0, ci_generator_1.generateGitLabCi)(defaultThresholds);
            assert.ok(result.includes('vibrancy-check:'));
            assert.ok(result.includes('stage: test'));
            assert.ok(result.includes('image:'));
            assert.ok(result.includes('script:'));
        });
        it('should use Flutter Docker image', () => {
            const result = (0, ci_generator_1.generateGitLabCi)(defaultThresholds);
            assert.ok(result.includes('cirrusci/flutter:stable'));
        });
        it('should include pubspec file triggers', () => {
            const result = (0, ci_generator_1.generateGitLabCi)(defaultThresholds);
            assert.ok(result.includes('pubspec.yaml'));
            assert.ok(result.includes('pubspec.lock'));
        });
        it('should include threshold values', () => {
            const result = (0, ci_generator_1.generateGitLabCi)(defaultThresholds);
            assert.ok(result.includes('Max EOL: 2'));
            assert.ok(result.includes('Max Legacy: 5'));
            assert.ok(result.includes('Min Avg Vibrancy: 60'));
        });
        it('should include artifact configuration', () => {
            const result = (0, ci_generator_1.generateGitLabCi)(defaultThresholds);
            assert.ok(result.includes('artifacts:'));
            assert.ok(result.includes('paths:'));
            assert.ok(result.includes('outdated.json'));
        });
    });
    describe('generateShellScript', () => {
        it('should start with shebang', () => {
            const result = (0, ci_generator_1.generateShellScript)(defaultThresholds);
            assert.ok(result.startsWith('#!/bin/bash'));
        });
        it('should include threshold variables', () => {
            const result = (0, ci_generator_1.generateShellScript)(defaultThresholds);
            assert.ok(result.includes('MAX_EOL=2'));
            assert.ok(result.includes('MAX_LEGACY=5'));
            assert.ok(result.includes('MIN_AVG_VIBRANCY=60'));
            assert.ok(result.includes('FAIL_ON_VULN=true'));
        });
        it('should check for Flutter availability', () => {
            const result = (0, ci_generator_1.generateShellScript)(defaultThresholds);
            assert.ok(result.includes('command -v flutter'));
            assert.ok(result.includes('Flutter not found'));
        });
        it('should run flutter pub get', () => {
            const result = (0, ci_generator_1.generateShellScript)(defaultThresholds);
            assert.ok(result.includes('flutter pub get'));
        });
        it('should run flutter pub outdated', () => {
            const result = (0, ci_generator_1.generateShellScript)(defaultThresholds);
            assert.ok(result.includes('flutter pub outdated --json'));
        });
        it('should mention CLI alternative', () => {
            const result = (0, ci_generator_1.generateShellScript)(defaultThresholds);
            assert.ok(result.includes('saropa_vibrancy_cli'));
        });
    });
    describe('getDefaultOutputPath', () => {
        it('should return GitHub Actions path', () => {
            const path = (0, ci_generator_1.getDefaultOutputPath)('github-actions');
            assert.strictEqual(path, '.github/workflows/vibrancy-check.yml');
        });
        it('should return GitLab CI path', () => {
            const path = (0, ci_generator_1.getDefaultOutputPath)('gitlab-ci');
            assert.strictEqual(path, '.gitlab-ci-vibrancy.yml');
        });
        it('should return shell script path', () => {
            const path = (0, ci_generator_1.getDefaultOutputPath)('shell-script');
            assert.strictEqual(path, 'scripts/vibrancy-check.sh');
        });
    });
    describe('getPlatformDisplayName', () => {
        it('should return GitHub Actions display name', () => {
            assert.strictEqual((0, ci_generator_1.getPlatformDisplayName)('github-actions'), 'GitHub Actions');
        });
        it('should return GitLab CI display name', () => {
            assert.strictEqual((0, ci_generator_1.getPlatformDisplayName)('gitlab-ci'), 'GitLab CI');
        });
        it('should return shell script display name', () => {
            assert.strictEqual((0, ci_generator_1.getPlatformDisplayName)('shell-script'), 'Shell Script (portable)');
        });
    });
    describe('getAvailablePlatforms', () => {
        it('should return all three platforms', () => {
            const platforms = (0, ci_generator_1.getAvailablePlatforms)();
            assert.strictEqual(platforms.length, 3);
        });
        it('should include GitHub Actions', () => {
            const platforms = (0, ci_generator_1.getAvailablePlatforms)();
            const gh = platforms.find(p => p.id === 'github-actions');
            assert.ok(gh);
            assert.ok(gh.label.includes('GitHub'));
            assert.ok(gh.description.includes('.github'));
        });
        it('should include GitLab CI', () => {
            const platforms = (0, ci_generator_1.getAvailablePlatforms)();
            const gl = platforms.find(p => p.id === 'gitlab-ci');
            assert.ok(gl);
            assert.ok(gl.label.includes('GitLab'));
        });
        it('should include shell script', () => {
            const platforms = (0, ci_generator_1.getAvailablePlatforms)();
            const sh = platforms.find(p => p.id === 'shell-script');
            assert.ok(sh);
            assert.ok(sh.label.includes('Shell'));
            assert.ok(sh.description.includes('portable'));
        });
        it('should have unique ids', () => {
            const platforms = (0, ci_generator_1.getAvailablePlatforms)();
            const ids = platforms.map(p => p.id);
            const uniqueIds = new Set(ids);
            assert.strictEqual(ids.length, uniqueIds.size);
        });
    });
    describe('threshold interpolation edge cases', () => {
        it('should handle large threshold values', () => {
            const thresholds = {
                maxStale: 50,
                maxEndOfLife: 100,
                maxLegacyLocked: 200,
                minAverageVibrancy: 95,
                failOnVulnerability: true,
            };
            const github = (0, ci_generator_1.generateGitHubActions)(thresholds);
            const gitlab = (0, ci_generator_1.generateGitLabCi)(thresholds);
            const shell = (0, ci_generator_1.generateShellScript)(thresholds);
            assert.ok(github.includes('100'));
            assert.ok(gitlab.includes('100'));
            assert.ok(shell.includes('100'));
        });
        it('should handle all-zero thresholds', () => {
            const thresholds = {
                maxStale: 0,
                maxEndOfLife: 0,
                maxLegacyLocked: 0,
                minAverageVibrancy: 0,
                failOnVulnerability: false,
            };
            const github = (0, ci_generator_1.generateGitHubActions)(thresholds);
            const shell = (0, ci_generator_1.generateShellScript)(thresholds);
            assert.ok(github.includes('const maxEol = 0'));
            assert.ok(shell.includes('FAIL_ON_VULN=false'));
        });
    });
});
//# sourceMappingURL=ci-generator.test.js.map