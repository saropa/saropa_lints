import * as fs from 'node:fs';

/** Temp file then rename, so a crash never leaves a truncated file. */
export function atomicWrite(file: string, text: string): void {
  const tmp = `${file}.${process.pid}.tmp`;
  try {
    fs.writeFileSync(tmp, text, 'utf8');
    fs.renameSync(tmp, file);
  } catch (err) {
    try {
      fs.rmSync(tmp, { force: true });
    } catch {
      // best effort
    }
    throw err;
  }
}
