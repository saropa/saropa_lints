import type { ClientRequest, IncomingMessage, RequestOptions } from 'http';
import * as https from 'https';

import type { CiPublishPlan } from './ciPublish';

/**
 * The GitHub REST call behind "open the pull request", with no `vscode`
 * import so it can be exercised against a real local HTTP server in a plain
 * Node test. `ciPublishGithub.ts` supplies the token.
 *
 * Every failure resolves to undefined rather than throwing: the branch is
 * already pushed when this runs, and the caller answers undefined with the
 * compare page. That includes a connection that never answers — without a
 * timeout the promise would hang and the user would never be offered it.
 */

/** Long enough for a slow network, short enough that nobody gives up waiting first. */
export const GITHUB_API_TIMEOUT_MS = 15_000;

/** `https.request`'s shape; injectable so a test can point it at `http`. */
export type RequestFn = (
  options: RequestOptions,
  callback: (res: IncomingMessage) => void,
) => ClientRequest;

export interface PostJsonOptions {
  request?: RequestFn;
  hostname?: string;
  port?: number;
  timeoutMs?: number;
}

/** The API path and body that open the plan's pull request, or undefined without a GitHub remote. */
export function pullRequestCall(
  plan: CiPublishPlan,
): { path: string; payload: { title: string; body: string; head: string; base: string } } | undefined {
  if (!plan.slug) return undefined;
  return {
    path: `/repos/${encodeURIComponent(plan.slug.owner)}/${encodeURIComponent(plan.slug.repo)}/pulls`,
    payload: { title: plan.prTitle, body: plan.prBody, head: plan.branch, base: plan.baseBranch },
  };
}

/** Minimal POST to the GitHub REST API. Resolves undefined on any non-2xx, transport error or timeout. */
export function postJson(
  path: string,
  token: string,
  payload: unknown,
  options: PostJsonOptions = {},
): Promise<Record<string, unknown> | undefined> {
  const request: RequestFn = options.request ?? https.request;
  return new Promise((resolve) => {
    let settled = false;
    const settle = (value: Record<string, unknown> | undefined): void => {
      if (settled) return;
      settled = true;
      resolve(value);
    };
    const body = JSON.stringify(payload);
    const req = request(
      {
        hostname: options.hostname ?? 'api.github.com',
        port: options.port,
        path,
        method: 'POST',
        headers: {
          Accept: 'application/vnd.github+json',
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(body),
          // GitHub rejects API requests without one.
          'User-Agent': 'saropa-lints-vscode',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      },
      (res) => {
        const chunks: Buffer[] = [];
        res.on('data', (c: Buffer) => chunks.push(c));
        res.on('end', () => {
          const status = res.statusCode ?? 0;
          if (status < 200 || status >= 300) {
            settle(undefined);
            return;
          }
          try {
            settle(JSON.parse(Buffer.concat(chunks).toString('utf8')) as Record<string, unknown>);
          } catch {
            settle(undefined);
          }
        });
        res.on('error', () => settle(undefined));
      },
    );
    req.setTimeout(options.timeoutMs ?? GITHUB_API_TIMEOUT_MS, () => {
      settle(undefined);
      req.destroy();
    });
    req.on('error', () => settle(undefined));
    req.write(body);
    req.end();
  });
}
