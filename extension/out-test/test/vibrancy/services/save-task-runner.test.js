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
const sinon = __importStar(require("sinon"));
const vscode = __importStar(require("vscode"));
const vscode_mock_1 = require("../vscode-mock");
const save_task_runner_1 = require("../../../vibrancy/services/save-task-runner");
describe('save-task-runner', () => {
    let sandbox;
    beforeEach(() => {
        sandbox = sinon.createSandbox();
        (0, vscode_mock_1.resetMocks)();
        (0, vscode_mock_1.clearTestConfig)();
    });
    afterEach(() => {
        sandbox.restore();
        (0, vscode_mock_1.clearTestConfig)();
    });
    describe('SaveTaskRunner', () => {
        it('should create without errors', () => {
            const runner = new save_task_runner_1.SaveTaskRunner();
            assert.ok(runner);
            runner.dispose();
        });
        it('should dispose without errors', () => {
            const runner = new save_task_runner_1.SaveTaskRunner();
            runner.dispose();
        });
        it('should read config with empty command by default', () => {
            const runner = new save_task_runner_1.SaveTaskRunner();
            runner.dispose();
        });
        it('should respect onSaveChanges setting', () => {
            (0, vscode_mock_1.setTestConfig)('saropaLints.packageVibrancy', 'onSaveChanges', 'flutter pub get');
            const runner = new save_task_runner_1.SaveTaskRunner();
            runner.dispose();
        });
        it('should respect onSaveChangesDetection setting', () => {
            (0, vscode_mock_1.setTestConfig)('saropaLints.packageVibrancy', 'onSaveChangesDetection', 'any');
            const runner = new save_task_runner_1.SaveTaskRunner();
            runner.dispose();
        });
        it('should ignore non-pubspec files', () => {
            const runner = new save_task_runner_1.SaveTaskRunner();
            runner.dispose();
        });
        it('should recognize pubspec.yaml files', () => {
            const runner = new save_task_runner_1.SaveTaskRunner();
            runner.dispose();
        });
    });
    describe('configuration validation', () => {
        it('should accept shell command format', () => {
            (0, vscode_mock_1.setTestConfig)('saropaLints.packageVibrancy', 'onSaveChanges', 'flutter pub get');
            const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
            assert.strictEqual(config.get('onSaveChanges'), 'flutter pub get');
        });
        it('should accept task: prefix format', () => {
            (0, vscode_mock_1.setTestConfig)('saropaLints.packageVibrancy', 'onSaveChanges', 'task:Build');
            const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
            assert.strictEqual(config.get('onSaveChanges'), 'task:Build');
        });
        it('should accept empty string (disabled)', () => {
            (0, vscode_mock_1.setTestConfig)('saropaLints.packageVibrancy', 'onSaveChanges', '');
            const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
            assert.strictEqual(config.get('onSaveChanges'), '');
        });
        it('should default detection to dependencies mode', () => {
            const config = vscode.workspace.getConfiguration('saropaLints.packageVibrancy');
            assert.strictEqual(config.get('onSaveChangesDetection', 'dependencies'), 'dependencies');
        });
        it('should accept any detection mode', () => {
            (0, vscode_mock_1.setTestConfig)('saropaLints.packageVibrancy', 'onSaveChangesDetection', 'any');
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
            const runner = new save_task_runner_1.SaveTaskRunner();
            runner.dispose();
            runner.dispose();
        });
    });
});
//# sourceMappingURL=save-task-runner.test.js.map