#!/usr/bin/env node
/**
 * Validates that every `%key%` placeholder in extension/package.json
 * resolves to package.nls.json (English source).
 *
 * Run from repo root: node extension/scripts/verify-manifest-nls-keys.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const extRoot = path.resolve(__dirname, '..');
const pkgPath = path.join(extRoot, 'package.json');
const nlsPath = path.join(extRoot, 'package.nls.json');

function collectPercentKeys(val, found) {
  if (typeof val === 'string') {
    const re = /%([^%]+)%/g;
    let m;
    while ((m = re.exec(val)) !== null) {
      found.add(m[1]);
    }
    return;
  }
  if (Array.isArray(val)) {
    for (const item of val) collectPercentKeys(item, found);
    return;
  }
  if (val && typeof val === 'object') {
    for (const k of Object.keys(val)) collectPercentKeys(val[k], found);
  }
}

function main() {
  const nls = JSON.parse(fs.readFileSync(nlsPath, 'utf8'));
  const nlsKeys = new Set(Object.keys(nls));

  const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
  const needed = new Set();
  collectPercentKeys(pkg, needed);

  const missing = [...needed].filter((k) => !nlsKeys.has(k)).sort();

  if (missing.length === 0) {
    console.log(`verify-manifest-nls-keys: OK (${needed.size} keys).`);
    return;
  }

  console.error(
    `verify-manifest-nls-keys: missing package.nls.json entries: ${missing.join(', ')}`,
  );
  process.exitCode = 1;
}

main();
