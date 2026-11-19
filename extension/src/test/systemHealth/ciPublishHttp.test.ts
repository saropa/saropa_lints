import * as assert from 'assert';
import * as http from 'http';
import type { AddressInfo } from 'net';

import type { CiPublishPlan } from '../../systemHealth/ciPublish';
import { postJson, pullRequestCall } from '../../systemHealth/ciPublishHttp';

/**
 * Against a real local HTTP server: what matters is what reaches the wire and
 * how each kind of answer — or no answer — is mapped. Every failure must
 * resolve undefined, because the caller answers undefined with the compare
 * page, and a promise that never settles would leave the user with nothing.
 */

const plan: CiPublishPlan = {
  direction: 'enable',
  branch: 'saropa-lints-ci',
  baseBranch: 'main',
  paths: ['.github/workflows/saropa-lints.yml'],
  commitMessage: 'ci: run saropa_lints on pull requests',
  prTitle: 'Run saropa_lints on pull requests',
  prBody: 'body',
  slug: { owner: 'saropa', repo: 'saropa_lints' },
  commands: [],
};

type Handler = (req: http.IncomingMessage, body: string, res: http.ServerResponse) => void;

async function withServer(handler: Handler, run: (port: number) => Promise<void>): Promise<void> {
  const server = http.createServer((req, res) => {
    let body = '';
    req.on('data', (c) => (body += c));
    req.on('end', () => handler(req, body, res));
  });
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    await run((server.address() as AddressInfo).port);
  } finally {
    server.closeAllConnections();
    await new Promise((resolve) => server.close(resolve));
  }
}

const local = (port: number, timeoutMs?: number) => ({
  request: http.request,
  hostname: '127.0.0.1',
  port,
  timeoutMs,
});

describe('ciPublishHttp — the pull request call', () => {
  it('targets the plan\'s repository with its branches', () => {
    assert.deepStrictEqual(pullRequestCall(plan), {
      path: '/repos/saropa/saropa_lints/pulls',
      payload: { title: plan.prTitle, body: 'body', head: 'saropa-lints-ci', base: 'main' },
    });
  });

  it('has nothing to call without a GitHub remote', () => {
    assert.strictEqual(pullRequestCall({ ...plan, slug: undefined }), undefined);
  });

  it('sends the token, the API headers and the JSON body', async () => {
    let seen: { headers: http.IncomingHttpHeaders; body: string; url?: string; method?: string } | undefined;
    await withServer(
      (req, body, res) => {
        seen = { headers: req.headers, body, url: req.url, method: req.method };
        res.writeHead(201, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ html_url: 'https://github.com/saropa/saropa_lints/pull/1' }));
      },
      async (port) => {
        const call = pullRequestCall(plan)!;
        const result = await postJson(call.path, 'tok', call.payload, local(port));
        assert.strictEqual(result?.['html_url'], 'https://github.com/saropa/saropa_lints/pull/1');
      },
    );
    assert.strictEqual(seen?.method, 'POST');
    assert.strictEqual(seen?.url, '/repos/saropa/saropa_lints/pulls');
    assert.strictEqual(seen?.headers.authorization, 'Bearer tok');
    assert.strictEqual(seen?.headers['user-agent'], 'saropa-lints-vscode');
    assert.strictEqual(seen?.headers['x-github-api-version'], '2022-11-28');
    assert.deepStrictEqual(JSON.parse(seen!.body), pullRequestCall(plan)!.payload);
  });

  it('resolves undefined on a refusal (e.g. 422, a PR already exists)', async () => {
    await withServer(
      (_req, _body, res) => {
        res.writeHead(422);
        res.end('{"message":"Validation Failed"}');
      },
      async (port) => {
        assert.strictEqual(await postJson('/x', 't', {}, local(port)), undefined);
      },
    );
  });

  it('resolves undefined on a body that is not JSON', async () => {
    await withServer(
      (_req, _body, res) => {
        res.writeHead(200);
        res.end('<html>');
      },
      async (port) => {
        assert.strictEqual(await postJson('/x', 't', {}, local(port)), undefined);
      },
    );
  });

  it('resolves undefined when the connection never answers', async () => {
    await withServer(
      () => {
        /* never respond */
      },
      async (port) => {
        assert.strictEqual(await postJson('/x', 't', {}, local(port, 200)), undefined);
      },
    );
  });

  it('resolves undefined when nothing is listening', async () => {
    let port = 0;
    await withServer(
      () => undefined,
      async (p) => {
        port = p;
      },
    );
    assert.strictEqual(await postJson('/x', 't', {}, local(port)), undefined);
  });
});
