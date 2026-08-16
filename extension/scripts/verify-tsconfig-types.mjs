#!/usr/bin/env node
/**
 * Validates that tsconfig.json's "types" array includes every @types/*
 * package whose corresponding module is imported in non-test source files.
 *
 * When "types" is set explicitly, TypeScript stops auto-discovering
 * @types/* packages — so a missing entry silently drops type coverage
 * and produces TS2591 errors in the IDE.
 *
 * Run from repo root: node extension/scripts/verify-tsconfig-types.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const extRoot = path.resolve(__dirname, '..');
const tsconfigPath = path.join(extRoot, 'tsconfig.json');

// Read the types array from tsconfig.json.
const tsconfig = JSON.parse(fs.readFileSync(tsconfigPath, 'utf-8'));
const declaredTypes = tsconfig.compilerOptions?.types;

if (!declaredTypes) {
  // No explicit types field — auto-discovery is active, nothing to validate.
  console.log('✓ No explicit "types" field — auto-discovery active, nothing to check.');
  process.exit(0);
}

const declaredSet = new Set(declaredTypes);

// Find all @types/* packages installed in node_modules.
const typesDir = path.join(extRoot, 'node_modules', '@types');
let installedTypes;
try {
  installedTypes = fs.readdirSync(typesDir).filter(
    (d) => fs.statSync(path.join(typesDir, d)).isDirectory(),
  );
} catch {
  console.log('✓ No @types/ directory found — nothing to check.');
  process.exit(0);
}

// Scan src/ for import statements, skipping the test directory (which is
// excluded from tsconfig compilation and uses test-only types like mocha).
const srcDir = path.join(extRoot, 'src');
const importPattern = /from\s+['"]([^./][^'"]*)['"]/g;
const importedModules = new Set();

/**
 * Recursively walk a directory tree and collect imported module names
 * from every .ts file, skipping the test subdirectory.
 */
function walkAndCollectImports(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      // Skip the test directory — its types are not compiled by the main tsconfig.
      if (entry.name === 'test' && dir === srcDir) continue;
      walkAndCollectImports(full);
    } else if (entry.name.endsWith('.ts')) {
      const content = fs.readFileSync(full, 'utf-8');
      let m;
      while ((m = importPattern.exec(content)) !== null) {
        // Strip node: protocol prefix and subpath (e.g. 'node:fs' → 'fs').
        const raw = m[1].replace(/^node:/, '').split('/')[0];
        importedModules.add(raw);
      }
    }
  }
}
walkAndCollectImports(srcDir);

// Check: every installed @types/* whose base module is imported in src/
// must appear in tsconfig's "types" array.
const missing = [];
for (const typePkg of installedTypes) {
  if (importedModules.has(typePkg) && !declaredSet.has(typePkg)) {
    missing.push(typePkg);
  }
}

if (missing.length > 0) {
  console.error(
    `✗ These @types/* packages are imported in src/ but missing from tsconfig "types":\n` +
    missing.map((t) => `  - ${t}`).join('\n') +
    `\n\nAdd them to compilerOptions.types in tsconfig.json.`,
  );
  process.exit(1);
}

console.log(`✓ tsconfig "types" covers all ${declaredSet.size} runtime @types/* packages.`);
