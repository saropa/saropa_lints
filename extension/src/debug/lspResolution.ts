import * as fs from 'node:fs';
import * as path from 'node:path';

/**
 * True when `<projectRoot>/.dart_tool/package_config.json` lists a package
 * named `saropa_lints`. Missing/unreadable/malformed file => false. Spawning
 * `dart run saropa_lints:lsp_server` without it exits 255 ("Could not find
 * package saropa_lints") and the client restart loop stacks error toasts.
 */
export function isSaropaLintsResolved(projectRoot: string): boolean {
  try {
    const raw = fs.readFileSync(path.join(projectRoot, '.dart_tool', 'package_config.json'), 'utf8');
    const packages = (JSON.parse(raw) as { packages?: Array<{ name?: unknown }> }).packages;
    return Array.isArray(packages) && packages.some((p) => p?.name === 'saropa_lints');
  } catch {
    return false;
  }
}
