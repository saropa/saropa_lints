/**
 * Unit tests for Drift Advisor API client (fetchIssues).
 * Uses Node http server to simulate /api/issues and legacy endpoints; no vscode.
 */

import * as assert from 'assert';
import * as http from 'http';
import { fetchIssues } from '../../driftAdvisor/client';
import type { DriftServerInfo } from '../../driftAdvisor/types';

function createIssuesServer(issuesPayload: { issues: unknown[] }): Promise<{ server: http.Server; port: number }> {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      if (req.url === '/api/health' && req.method === 'GET') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: true, capabilities: ['issues'] }));
      } else if (req.url === '/api/issues' && req.method === 'GET') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(issuesPayload));
      } else {
        res.writeHead(404);
        res.end();
      }
    });
    server.listen(0, '127.0.0.1', () => {
      const addr = server.address();
      const port = typeof addr === 'object' && addr?.port ? addr.port : 0;
      resolve({ server, port });
    });
  });
}

describe('Drift Advisor client', () => {
  it('fetchIssues returns issues when server has issues capability', async () => {
    const { server, port } = await createIssuesServer({
      issues: [
        {
          source: 'index-suggestion',
          severity: 'warning',
          table: 'users',
          column: null,
          message: 'Missing index on email',
        },
      ],
    });
    try {
      const serverInfo: DriftServerInfo = {
        baseUrl: `http://127.0.0.1:${port}`,
        port,
        capabilities: ['issues'],
      };
      const issues = await fetchIssues(serverInfo);
      assert.strictEqual(issues.length, 1);
      assert.strictEqual(issues[0].table, 'users');
      assert.strictEqual(issues[0].message, 'Missing index on email');
      assert.strictEqual(issues[0].source, 'index-suggestion');
    } finally {
      server.close();
    }
  });

  it('fetchIssues returns empty array when /api/issues returns empty', async () => {
    const { server, port } = await createIssuesServer({ issues: [] });
    try {
      const serverInfo: DriftServerInfo = {
        baseUrl: `http://127.0.0.1:${port}`,
        port,
        capabilities: ['issues'],
      };
      const issues = await fetchIssues(serverInfo);
      assert.strictEqual(issues.length, 0);
    } finally {
      server.close();
    }
  });

  it('fetchIssues filters out invalid issues (missing table or message)', async () => {
    const { server, port } = await createIssuesServer({
      issues: [
        { source: 'anomaly', severity: 'info', table: 'users', message: 'OK' },
        { source: 'anomaly', severity: 'info', message: 'No table' },
        { source: 'anomaly', severity: 'info', table: 'x' },
      ],
    });
    try {
      const serverInfo: DriftServerInfo = {
        baseUrl: `http://127.0.0.1:${port}`,
        port,
        capabilities: ['issues'],
      };
      const issues = await fetchIssues(serverInfo);
      assert.strictEqual(issues.length, 1);
      assert.strictEqual(issues[0].table, 'users');
    } finally {
      server.close();
    }
  });
});
