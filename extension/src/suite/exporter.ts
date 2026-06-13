/**
 * Production glue between the live findings model and the Saropa Diagnostic
 * Envelope (plan requirement R1). Reads the same live VS Code diagnostics the
 * Findings Dashboard reads, builds the envelope, and writes the offline mirror
 * `<workspace>/.saropa/diagnostics/lints.json` so the two sibling extensions can
 * correlate against Lints' static findings without the analyzer being the active
 * tool.
 *
 * Kept thin and separate from `envelope.ts` (which is `vscode`-free and unit
 * tested) so the impure parts — reading live diagnostics and resolving the
 * localized fix label — live in one place. Called on the debounced
 * analysis-settle tick in `extension.ts`; failures are swallowed there.
 */

import { l10n } from '../i18n/runtime';
import { getRuleCatalog } from '../ruleCatalog';
import { readLiveViolations } from '../liveViolationsData';
import { buildLintsEnvelope, writeLintsEnvelope } from './envelope';

/**
 * Read the current live findings, build the `source: "lints"` envelope, and write
 * the mirror under `root`. `generatedAt` defaults to now but is injectable so a
 * test can assert deterministic output. Returns the path written.
 *
 * The fix-action label is resolved here (not in the pure builder) because §2.4
 * requires every string crossing the tool boundary to be already localized by the
 * producer — Lints owns its own i18n catalog.
 */
export function exportLintsEnvelope(
  root: string,
  producerVersion: string,
  generatedAt: string = new Date().toISOString(),
): string {
  const data = readLiveViolations(root);
  const envelope = buildLintsEnvelope(data, {
    producerVersion,
    generatedAt,
    fixTitle: l10n('suite.fix.explainRule'),
    catalog: getRuleCatalog(),
  });
  return writeLintsEnvelope(root, envelope);
}
