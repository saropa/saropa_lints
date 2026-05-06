/**
 * Stamps `views.help.name` in every `package.nls*.json` with the extension
 * version from `package.json`, preserving each locale's base label.
 *
 * Invoked from `copy-codicons.js` so `npm run precompile` always stays in sync.
 */

const fs = require('fs');
const path = require('path');

const rootDir = path.resolve(__dirname, '..');
const packageJsonPath = path.join(rootDir, 'package.json');
const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
const version = packageJson.version;

if (!version || typeof version !== 'string') {
  throw new Error('Expected extension package.json to contain a string "version".');
}

const nlsFiles = fs
  .readdirSync(rootDir)
  .filter((fileName) => /^package\.nls(\.[^.]+)?\.json$/.test(fileName))
  .map((fileName) => path.join(rootDir, fileName));

for (const nlsPath of nlsFiles) {
  const raw = fs.readFileSync(nlsPath, 'utf8');
  const json = JSON.parse(raw);
  const current = json['views.help.name'];
  if (typeof current !== 'string') {
    continue;
  }

  const baseLabel = current.replace(/\s*\(v[^\)]*\)\s*$/u, '').trim();
  json['views.help.name'] = `${baseLabel} (v${version})`;
  fs.writeFileSync(nlsPath, `${JSON.stringify(json, null, 2)}\n`, 'utf8');
}
