/**
 * Tests for the severity filter settings reader. Verifies that each
 * toggle maps to the correct DiagnosticSeverity and that defaults
 * are all-on when no settings are configured.
 */
import '../vibrancy/register-vscode-mock';

import * as assert from 'node:assert';
import * as vscode from 'vscode';
import { setTestConfig, clearTestConfig } from '../vibrancy/vscode-mock';
import {
  getEnabledSeverities,
  isSeverityEnabled,
  getEnabledSeverityStrings,
} from '../../config/severityConfig';

describe('severityConfig', () => {
  afterEach(() => clearTestConfig());

  describe('getEnabledSeverities', () => {
    it('returns all four severities when no settings are configured', () => {
      const enabled = getEnabledSeverities();
      assert.strictEqual(enabled.size, 4);
      assert.ok(enabled.has(vscode.DiagnosticSeverity.Error));
      assert.ok(enabled.has(vscode.DiagnosticSeverity.Warning));
      assert.ok(enabled.has(vscode.DiagnosticSeverity.Information));
      assert.ok(enabled.has(vscode.DiagnosticSeverity.Hint));
    });

    it('excludes hint when severity.hint is false', () => {
      // The config reader uses the bare key path — mock must match.
      setTestConfig('saropaLints', 'severity.hint', false);
      const enabled = getEnabledSeverities();
      assert.ok(!enabled.has(vscode.DiagnosticSeverity.Hint));
      // Other severities remain enabled.
      assert.ok(enabled.has(vscode.DiagnosticSeverity.Error));
      assert.ok(enabled.has(vscode.DiagnosticSeverity.Warning));
      assert.ok(enabled.has(vscode.DiagnosticSeverity.Information));
    });

    it('excludes error when severity.error is false', () => {
      setTestConfig('saropaLints', 'severity.error', false);
      const enabled = getEnabledSeverities();
      assert.ok(!enabled.has(vscode.DiagnosticSeverity.Error));
      assert.strictEqual(enabled.size, 3);
    });
  });

  describe('isSeverityEnabled', () => {
    it('returns true for all severities by default', () => {
      assert.ok(isSeverityEnabled(vscode.DiagnosticSeverity.Error));
      assert.ok(isSeverityEnabled(vscode.DiagnosticSeverity.Warning));
      assert.ok(isSeverityEnabled(vscode.DiagnosticSeverity.Information));
      assert.ok(isSeverityEnabled(vscode.DiagnosticSeverity.Hint));
    });

    it('returns false when the corresponding setting is off', () => {
      setTestConfig('saropaLints', 'severity.warning', false);
      assert.ok(!isSeverityEnabled(vscode.DiagnosticSeverity.Warning));
      // Unrelated severity stays on.
      assert.ok(isSeverityEnabled(vscode.DiagnosticSeverity.Error));
    });
  });

  describe('getEnabledSeverityStrings', () => {
    it('returns all three tree-vocabulary strings by default', () => {
      const enabled = getEnabledSeverityStrings();
      assert.ok(enabled.has('error'));
      assert.ok(enabled.has('warning'));
      assert.ok(enabled.has('info'));
      assert.strictEqual(enabled.size, 3);
    });

    it('excludes warning when severity.warning is false', () => {
      setTestConfig('saropaLints', 'severity.warning', false);
      const enabled = getEnabledSeverityStrings();
      assert.ok(!enabled.has('warning'));
      assert.ok(enabled.has('error'));
      assert.ok(enabled.has('info'));
    });
  });
});
