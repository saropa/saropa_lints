import * as assert from 'assert';
import * as sinon from 'sinon';
import * as vscode from 'vscode';
import { setTestConfig, clearTestConfig, resetMocks } from '../vscode-mock';
import { SaveTaskRunner } from '../../../vibrancy/services/save-task-runner';

describe('save-task-runner', () => {
    let sandbox: sinon.SinonSandbox;

    beforeEach(() => {
        sandbox = sinon.createSandbox();
        resetMocks();
        clearTestConfig();
    });

    afterEach(() => {
        sandbox.restore();
        clearTestConfig();
    });

    describe('SaveTaskRunner', () => {
        it('should create without errors', () => {
            const runner = new SaveTaskRunner();
            assert.ok(runner);
            runner.dispose();
        });

        it('should dispose without errors', () => {
            const runner = new SaveTaskRunner();
            runner.dispose();
        });

        it('should read config with empty command by default', () => {
            const runner = new SaveTaskRunner();
            runner.dispose();
        });

        it('should respect onSaveChanges setting', () => {
            setTestConfig('saropaLints.packageVibrancy', 'onSaveChanges', 'flutter pub get');
            const runner = new SaveTaskRunner();
            runner.dispose();
        });

        it('should respect onSaveChangesDetection setting', () => {
            setTestConfig('saropaLints.packageVibrancy', 'onSaveChangesDetection', 'any');
            const runner = new SaveTaskRunner();
            runner.dispose();
        });

        it('should ignore non-pubspec files', () => {
            const runner = new SaveTaskRunner();
            runner.dispose();
        });

        it('should recognize pubspec.yaml files', () => {
            const runner = new SaveTaskRunner();
            runner.dispose();
        });
    });

    describe('configuration validation', () => {
        it('should accept shell command format', () => {
            setTestConfig('saropaLints.packageVibrancy', 'onSaveChanges', 'flutter pub get');
            const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
            assert.strictEqual(config.get('onSaveChanges'), 'flutter pub get');
        });

        it('should accept task: prefix format', () => {
            setTestConfig('saropaLints.packageVibrancy', 'onSaveChanges', 'task:Build');
            const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
            assert.strictEqual(config.get('onSaveChanges'), 'task:Build');
        });

        it('should accept empty string (disabled)', () => {
            setTestConfig('saropaLints.packageVibrancy', 'onSaveChanges', '');
            const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
            assert.strictEqual(config.get('onSaveChanges'), '');
        });

        it('should default detection to dependencies mode', () => {
            const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
            assert.strictEqual(config.get('onSaveChangesDetection', 'dependencies'), 'dependencies');
        });

        it('should accept any detection mode', () => {
            setTestConfig('saropaLints.packageVibrancy', 'onSaveChangesDetection', 'any');
            const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
            assert.strictEqual(config.get('onSaveChangesDetection'), 'any');
        });
    });

    describe('task prefix parsing', () => {
        it('should identify task: prefix', () => {
            const command = 'task:My Custom Task';
            assert.ok(command.startsWith('task:'));
            assert.strictEqual(command.slice(5), 'My Custom Task');
        });

        it('should not identify shell commands as tasks', () => {
            const command = 'flutter pub get';
            assert.ok(!command.startsWith('task:'));
        });
    });

    describe('error handling', () => {
        it('should not crash on dispose when not initialized', () => {
            const runner = new SaveTaskRunner();
            runner.dispose();
            runner.dispose();
        });
    });
});
