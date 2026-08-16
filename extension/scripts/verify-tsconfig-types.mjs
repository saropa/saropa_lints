#!/usr/bin/env node
/**
 * Validates that tsconfig "types" arrays include every @types/* package
 * whose corresponding module is imported in the compiled source files.
 *
 * When "types" is set explicitly, TypeScript stops auto-discovering
 * @types/* packages — so a missing entry silently drops type coverage
 * and produces TS2591 errors in the IDE.
 *
 * Checks both tsconfig.json (runtime) and tsconfig.test.json (test) when
 * each has an explicit "types" field. Skips configs without one (auto-
 * discovery is active there, nothing to validate).
 *
 * Run from repo root: node extension/scripts/verify-tsconfig-types.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const extRoot = path.resolve(__dirname, '..');

// Patterns that capture the module specifier from static imports, re-exports,
// dynamic import(), and require() calls. Each returns the specifier in group 1.
const importPatterns = [
  /from\s+['"]([^./][^'"]*)['"]/g,        // import/export ... from 'mod'
  /import\(\s*['"]([^./][^'"]*)['"]\s*\)/g, // import('mod')
  /require\(\s*['"]([^./][^'"]*)['"]\s*\)/g, // require('mod')
];

/**
 * Find all @types/* package directories installed under node_modules.
 * Returns an empty array when the @types/ directory doesn't exist.
 */
function getInstalledTypes() {
  const typesDir = path.join(extRoot, 'node_modules', '@types');
  try {
    return fs.readdirSync(typesDir).filter(
      (d) => fs.statSync(path.join(typesDir, d)).isDirectory(),
    );
  } catch {
    return [];
  }
}

/**
 * Recursively walk a directory tree and collect external module names
 * imported from every .ts file. Skips directories listed in skipDirs
 * (matched by name at the given root level only).
 */
function collectImports(dir, rootDir, skipDirs) {
  const modules = new Set();
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      // Skip excluded directories at the root level of the scan.
      if (dir === rootDir && skipDirs.includes(entry.name)) continue;
      for (const mod of collectImports(full, rootDir, skipDirs)) {
        modules.add(mod);
      }
    } else if (entry.name.endsWith('.ts')) {
      const content = fs.readFileSync(full, 'utf-8');
      for (const pattern of importPatterns) {
        // Reset lastIndex — each regex is reused across files.
        pattern.lastIndex = 0;
        let m;
        while ((m = pattern.exec(content)) !== null) {
          // Strip node: protocol prefix and subpath (e.g. 'node:fs' → 'fs').
          const raw = m[1].replace(/^node:/, '').split('/')[0];
          modules.add(raw);
        }
      }
    }
  }
  return modules;
}

/**
 * Validate one tsconfig file. Returns true when the config is valid or
 * has no "types" field (nothing to check). Returns false when missing
 * types are found.
 */
function validateConfig(configName, skipDirs) {
  const configPath = path.join(extRoot, configName);
  if (!fs.existsSync(configPath)) return true;

  const config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));
  const declaredTypes = config.compilerOptions?.types;

  if (!declaredTypes) {
    // No explicit types field — auto-discovery is active.
    console.log(`✓ ${configName}: no explicit "types" field — auto-discovery active.`);
    return true;
  }

  const declaredSet = new Set(declaredTypes);
  const srcDir = path.join(extRoot, 'src');
  const importedModules = collectImports(srcDir, srcDir, skipDirs);
  const installedTypes = getInstalledTypes();

  // Every installed @types/* whose module is imported must be declared.
  const missing = [];
  for (const typePkg of installedTypes) {
    if (importedModules.has(typePkg) && !declaredSet.has(typePkg)) {
      missing.push(typePkg);
    }
  }

  if (missing.length > 0) {
    console.error(
      `✗ ${configName}: these @types/* packages are imported but missing from "types":\n` +
      missing.map((t) => `  - ${t}`).join('\n') +
      `\n\nAdd them to compilerOptions.types in ${configName}.`,
    );
    return false;
  }

  console.log(
    `✓ ${configName}: "types" covers all ${declaredSet.size} declared type packages.`,
  );
  return true;
}

// Main tsconfig: skip test/ (excluded from compilation).
const mainOk = validateConfig('tsconfig.json', ['test']);

// Test tsconfig: include all directories (tests compile everything).
const testOk = validateConfig('tsconfig.test.json', []);

if (!mainOk || !testOk) process.exit(1);
