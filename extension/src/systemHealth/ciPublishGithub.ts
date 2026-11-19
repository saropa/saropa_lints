import * as vscode from 'vscode';

import type { CiPublishPlan } from './ciPublish';
import { postJson, pullRequestCall } from './ciPublishHttp';

/**
 * Opens the pull request for a pushed CI change.
 *
 * Split from `ciPublish.ts` because this is the one step that cannot be done
 * with the git binary: creating a pull request is a GitHub API call, and the
 * API needs a token. VS Code ships a GitHub authentication provider, so the
 * cost to the user is a single "Allow" prompt the first time and nothing at
 * all afterwards — no personal access token to mint, store, or paste into a
 * setting.
 *
 * Every failure here is non-fatal by construction. The branch is already
 * pushed by the time this runs, so the worst case is that the user opens the
 * pull request from the compare URL themselves — which is exactly what the
 * caller offers them. That is why `createPullRequest` returns undefined
 * rather than throwing: there is no error here worth interrupting someone
 * over.
 */

/** The GitHub scope needed to open a pull request. `repo` covers private repositories too. */
const GITHUB_SCOPES = ['repo'];

/**
 * Acquires a GitHub session.
 *
 * `createIfNone` is passed only when `interactive` is true, so the silent
 * probe used for rendering never pops a modal at a user who has not asked
 * for anything yet.
 */
export async function getGitHubSession(
  interactive: boolean,
): Promise<vscode.AuthenticationSession | undefined> {
  try {
    return await vscode.authentication.getSession('github', GITHUB_SCOPES, {
      createIfNone: interactive,
      silent: interactive ? undefined : true,
    });
  } catch {
    // Declining the sign-in prompt rejects. That is a choice, not a fault.
    return undefined;
  }
}

/**
 * Creates the pull request and returns its URL, or undefined if anything at
 * all went wrong — no session, no GitHub remote, API refusal, network error.
 *
 * The caller treats undefined as "hand them the compare URL", so each of
 * those cases lands the user one click from the same outcome.
 */
export async function createPullRequest(plan: CiPublishPlan): Promise<string | undefined> {
  const call = pullRequestCall(plan);
  if (!call) return undefined;

  const session = await getGitHubSession(true);
  if (!session) return undefined;

  const response = await postJson(call.path, session.accessToken, call.payload);

  const url = response?.['html_url'];
  return typeof url === 'string' ? url : undefined;
}
