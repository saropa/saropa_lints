/**
 * Locale parity: every locale must contain every English key and keep
 * placeholders ({name}, `code`, markdown/command links) identical to English.
 * Values still identical to English fail too, unless allowlisted in scripts/i18n/english_allowed.json.
 * Full audit lives in scripts/i18n/verify_locales.py.
 */
import * as assert from 'node:assert';
import * as fs from 'node:fs';
import * as path from 'node:path';

/** Fail on untranslated (identical-to-English) values that are not allowlisted. */
const FAIL_ON_IDENTICAL = true;

const ROOT = path.resolve(__dirname, '..', '..', '..');
const LOCALES_DIR = path.join(ROOT, 'src', 'i18n', 'locales');

type Flat = Record<string, unknown>;

interface Allow { values: Set<string>; words: Set<string>; keys: string[]; reviewedOk: Record<string, Set<string>> }

/** Same allowlist semantics as scripts/i18n/verify_locales.py (english_allowed.json). */
function loadAllow(): Allow {
  const d = JSON.parse(fs.readFileSync(path.join(ROOT, 'scripts', 'i18n', 'english_allowed.json'), 'utf8'));
  const reviewedOk: Record<string, Set<string>> = {};
  for (const [l, ks] of Object.entries<string[]>(d.reviewed_ok ?? {})) { reviewedOk[l] = new Set(ks); }
  return {
    values: new Set<string>((d.values ?? []).map((v: string) => v.toLowerCase())),
    words: new Set<string>((d.words ?? []).map((w: string) => w.toLowerCase())),
    keys: d.keys ?? [],
    reviewedOk,
  };
}

function keyAllowed(key: string, patterns: string[]): boolean {
  return patterns.some((p) => key === p || (p.endsWith('*') && key.startsWith(p.slice(0, -1))));
}

/** True when an English value has real (non-allowlisted) words, so staying English is a defect. */
function hasRealWords(ev: string, words: Set<string>): boolean {
  const stripped = ev
    .replace(/`[^`]*`/g, ' ')
    .replace(/(?:https?|command|file):\/\/\S+|command:[\w.\-?=%&/,]+/g, ' ')
    .replace(/\{[A-Za-z_][\w.]*\}/g, ' ')
    .replace(/\[[^\]]*\]\(([^)]*)\)/g, ' ');
  return (stripped.match(/[A-Za-z]{3,}/g) ?? []).some((w) => !words.has(w.toLowerCase()));
}

const ALLOW = loadAllow();

function flatten(o: Record<string, unknown>, prefix = '', out: Flat = {}): Flat {
  for (const [k, v] of Object.entries(o)) {
    if (v !== null && typeof v === 'object') {
      flatten(v as Record<string, unknown>, `${prefix}${k}.`, out);
    } else {
      out[`${prefix}${k}`] = v;
    }
  }
  return out;
}

function readFlat(p: string): Flat {
  return flatten(JSON.parse(fs.readFileSync(p, 'utf8')));
}

function multiset(s: string, re: RegExp, group = 0): string {
  const items: string[] = [];
  for (const m of s.matchAll(re)) { items.push(m[group]); }
  return items.sort().join('\u0001');
}

function placeholderProblems(en: string, loc: string): string[] {
  const checks: [string, RegExp, number][] = [
    ['placeholders', /\{[A-Za-z_][\w.]*\}/g, 0],
    ['code', /`[^`]*`/g, 0],
    ['links', /\[[^\]]*\]\(([^)]*)\)/g, 1],
    ['urls', /(?:https?|command|file):\/\/\S+|command:[\w.\-?=%&/,]+/g, 0],
  ];
  return checks
    .filter(([, re, g]) => multiset(en, re, g) !== multiset(loc, re, g))
    .map(([name]) => name);
}

const localeCodes = fs
  .readdirSync(LOCALES_DIR)
  .filter((f) => f.endsWith('.json') && f !== 'en.json')
  .map((f) => f.slice(0, -5))
  .sort();

const families: { name: string; en: string; file: (l: string) => string }[] = [
  { name: 'runtime', en: path.join(LOCALES_DIR, 'en.json'), file: (l) => path.join(LOCALES_DIR, `${l}.json`) },
  { name: 'manifest', en: path.join(ROOT, 'package.nls.json'), file: (l) => path.join(ROOT, `package.nls.${l}.json`) },
];

describe('locale parity', () => {
  it('discovers the expected locales', () => {
    assert.ok(localeCodes.length >= 24, `found ${localeCodes.length} locales`);
  });

  for (const fam of families) {
    const en = readFlat(fam.en);
    for (const l of localeCodes) {
      it(`${fam.name}/${l}: no missing keys, no placeholder mismatches`, () => {
        const p = fam.file(l);
        assert.ok(fs.existsSync(p), `missing file ${p}`);
        const loc = readFlat(p);
        const missing = Object.keys(en).filter((k) => !(k in loc));
        const bad: string[] = [];
        const identical: string[] = [];
        for (const k of Object.keys(en)) {
          const lv = loc[k];
          if (typeof lv !== 'string') { continue; }
          const ev = String(en[k]);
          const pp = placeholderProblems(ev, lv);
          if (pp.length) { bad.push(`${k} (${pp.join(',')})`); }
          if (
            lv === ev &&
            !ALLOW.reviewedOk[l]?.has(k) &&
            !keyAllowed(k, ALLOW.keys) &&
            !ALLOW.values.has(ev.trim().toLowerCase()) &&
            hasRealWords(ev, ALLOW.words)
          ) { identical.push(k); }
        }
        if (identical.length && !FAIL_ON_IDENTICAL) {
          console.warn(`  [warn] ${fam.name}/${l}: ${identical.length} values identical to English`);
        }
        const problems = [
          ...missing.map((k) => `missing ${k}`),
          ...bad.map((k) => `placeholder ${k}`),
          ...(FAIL_ON_IDENTICAL ? identical.map((k) => `identical ${k}`) : []),
        ];
        assert.strictEqual(problems.length, 0,
          `${problems.length} problem(s), first: ${problems.slice(0, 5).join('; ')}`);
      });
    }
  }
});
