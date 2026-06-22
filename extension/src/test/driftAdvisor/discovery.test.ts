/**
 * Unit tests for Drift Advisor server discovery (tryHealth, discoverServer).
 * Uses Node http server to simulate health endpoint; no vscode.
 */

import * as assert from 'assert';
import * as http from 'http';
import { tryHealth, discoverServer, parseHostPort, expandEndpoints } from '../../driftAdvisor/discovery';

function createHealthServer(json: object): Promise<{ server: http.Server; port: number }> {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      if (req.url === '/api/health' && req.method === 'GET') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(json));
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

describe('Drift Advisor discovery', () => {
  it('returns server info when health returns 200 and ok: true', async () => {
    const { server, port } = await createHealthServer({
      ok: true,
      version: '1.0.0',
      capabilities: ['issues'],
    });
    try {
      const info = await tryHealth(port, 3000);
      assert.ok(info);
      assert.strictEqual(info!.port, port);
      assert.strictEqual(info!.baseUrl, `http://127.0.0.1:${port}`);
      assert.strictEqual(info!.version, '1.0.0');
      assert.deepStrictEqual(info!.capabilities, ['issues']);
    } finally {
      server.close();
    }
  });

  it('returns server info when health returns 200 without ok field', async () => {
    const { server, port } = await createHealthServer({ version: '0.9' });
    try {
      const info = await tryHealth(port, 3000);
      assert.ok(info);
      assert.strictEqual(info!.port, port);
      assert.strictEqual(info!.version, '0.9');
      assert.deepStrictEqual(info!.capabilities, []);
    } finally {
      server.close();
    }
  });

  it('returns null when health returns ok: false', async () => {
    const { server, port } = await createHealthServer({ ok: false });
    try {
      const info = await tryHealth(port, 3000);
      assert.strictEqual(info, null);
    } finally {
      server.close();
    }
  });

  it('returns null when health returns 404', async () => {
    const server = http.createServer((_req, res) => {
      res.writeHead(404);
      res.end();
    });
    await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', () => resolve()));
    const port = (server.address() as { port: number }).port;
    try {
      const info = await tryHealth(port, 3000);
      assert.strictEqual(info, null);
    } finally {
      server.close();
    }
  });

  it('parseHostPort splits an explicit host:port and passes bare hosts through', () => {
    assert.deepStrictEqual(parseHostPort('192.168.1.151:9000'), { host: '192.168.1.151', port: 9000 });
    assert.strictEqual(parseHostPort('192.168.1.151'), null);
    assert.strictEqual(parseHostPort('localhost'), null);
    // Out-of-range / malformed ports are treated as a bare host, not a split.
    assert.strictEqual(parseHostPort('host:0'), null);
    assert.strictEqual(parseHostPort('host:70000'), null);
  });

  it('expandEndpoints scans bare hosts across the range and pins host:port entries', () => {
    const eps = expandEndpoints(['127.0.0.1', '192.168.1.151:9000', '  '], 8642, 8643);
    assert.deepStrictEqual(eps, [
      { host: '127.0.0.1', port: 8642 },
      { host: '127.0.0.1', port: 8643 },
      { host: '192.168.1.151', port: 9000 },
    ]);
  });

  it('expandEndpoints de-duplicates overlapping endpoints, keeping first-listed order', () => {
    const eps = expandEndpoints(['127.0.0.1:8642', '127.0.0.1'], 8642, 8643);
    assert.deepStrictEqual(eps, [
      { host: '127.0.0.1', port: 8642 },
      { host: '127.0.0.1', port: 8643 },
    ]);
  });

  it('discoverServer probes a list of hosts and returns the first match', async () => {
    const { server, port } = await createHealthServer({ ok: true, version: '2', capabilities: [] });
    try {
      const info = await discoverServer(port, port, 3000, ['127.0.0.1']);
      assert.ok(info);
      assert.strictEqual(info!.baseUrl, `http://127.0.0.1:${port}`);
    } finally {
      server.close();
    }
  });

  it('discoverServer returns first server in range', async () => {
    const { server, port } = await createHealthServer({
      ok: true,
      version: '1',
      capabilities: [],
    });
    try {
      const info = await discoverServer(port, port + 2, 3000);
      assert.ok(info);
      assert.strictEqual(info!.port, port);
    } finally {
      server.close();
    }
  });
});
