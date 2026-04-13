/**
 * Copies Codicons into media/ so the packaged VSIX includes fonts/CSS
 * (node_modules is excluded by .vscodeignore).
 */

const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const src = path.join(root, 'node_modules', '@vscode', 'codicons', 'dist');
const dest = path.join(root, 'media', 'codicons');

if (!fs.existsSync(src)) {
  console.error('copy-codicons: missing', src, '(run npm install in extension/)');
  process.exit(1);
}

fs.rmSync(dest, { recursive: true, force: true });
fs.cpSync(src, dest, { recursive: true });
console.log('copy-codicons: ->', dest);
