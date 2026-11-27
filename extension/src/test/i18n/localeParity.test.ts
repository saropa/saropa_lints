/**
 * Locale parity: every locale must contain every English key and keep
 * placeholders ({name}, `code`, markdown/command links) identical to English.
 * Values still identical to English fail too, unless allowlisted in scripts/i18n/english_allowed.json.
 * Leaked MT prompts, looped words (spaced or CJK), overlong values and known invented
 * phrases (scripts/i18n/invented_phrases.json) fail as "mt-echo" (see mtEchoProblems).
 * Sindhi-only letters in an ur value fail too (see SINDHI_ONLY).
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

/**
 * MT echo guard (mirrors _mt_echo_flags in scripts/i18n/bad_translations.py).
 * Qwen leaked its numbered prompt ("Strict rules:\n1. Return ONLY...") into values,
 * NLLB looped words ("Linea Linea Linea Linea"), and both produced values far longer
 * than English. Each check is excused when English has the same pattern.
 */
const PROMPT_LIST = /^\s*[1-4]\.\s|\b1\.\s[\s\S]*\b2\.\s[\s\S]*\b3\.\s/m;
// One to three words repeated 3+ times in a row. Combining marks (Devanagari and
// Bengali vowel signs) are stripped first, exactly as the Python check does, so
// both guards flag the same values.
const LOOP = /(?<![\p{L}\p{N}_])((?:[\p{L}\p{N}_]+[\s,]+){0,2}[\p{L}\p{N}_]+)(?:[\s,]+\1(?![\p{L}\p{N}_])){2,}/iu;
const MARKS = /\p{M}/gu;

function hasLoop(s: string): boolean {
  return LOOP.test(s.replace(MARKS, ''));
}
// Every 40+ character value above 2.5x English on 2026-11-27 was a leak or a loop;
// after the hand repairs the highest remaining ratio was 2.50.
const OVERLONG_MIN_EN = 40;
const OVERLONG_FACTOR = 2.5;

// CJK labels loop without spaces ("メニューメニューメヌー"), which LOOP cannot see.
// Same pattern as _CJK_LOOP_RE in bad_translations.py: a 3+ character run twice,
// a 2-character run three times, or one character four times. Thai is excluded
// because it legitimately doubles words.
const CJK = '[\\u3040-\\u30ff\\u3400-\\u9fff\\uac00-\\ud7af]';
const CJK_LOOP = new RegExp(`(${CJK}{3,})\\1|(${CJK}{2})\\2\\2|(${CJK})\\3\\3\\3`, 'u');

interface InventedPhrase { phrase: string; excuse: RegExp | null }

/**
 * NLLB-invented sentences ("Es el nombre de la persona que tiene", "là người có thể"),
 * shared with bad_translations.py through scripts/i18n/invented_phrases.json.
 * A phrase is excused only when the English matches its en_excuse regex.
 */
function loadInvented(): Record<string, InventedPhrase[]> {
  const d = JSON.parse(fs.readFileSync(path.join(ROOT, 'scripts', 'i18n', 'invented_phrases.json'), 'utf8'));
  const out: Record<string, InventedPhrase[]> = {};
  for (const [l, items] of Object.entries<{ phrase: string; en_excuse?: string }[]>(d.phrases ?? {})) {
    // An empty en_excuse means the phrase is never legitimate.
    out[l] = items.map((it) => ({ phrase: it.phrase.toLowerCase(), excuse: it.en_excuse ? new RegExp(it.en_excuse, 'i') : null }));
  }
  return out;
}

const INVENTED = loadInvented();

// Sindhi shares the Arabic script, and NLLB wrote it into ur values. None of these
// code points is in the Urdu alphabet. Same set as _SINDHI_ONLY_RE in
// bad_translations.py.
const SINDHI_ONLY = /[ٺٻٽٿڀڃڄڇڊڌڍڏڙڦڪڱڳڻ۽۾]/;

function mtEchoProblems(en: string, loc: string, locale: string): string[] {
  const out: string[] = [];
  if (PROMPT_LIST.test(loc) && !PROMPT_LIST.test(en)) { out.push('prompt-leak'); }
  if (hasLoop(loc) && !hasLoop(en)) { out.push('loop'); }
  // English never contains CJK, so the spaceless loop needs no excuse check.
  if (CJK_LOOP.test(loc)) { out.push('loop'); }
  // Whole-string lengths: a leaked prompt keeps the source's links and code spans.
  if (en.length >= OVERLONG_MIN_EN && loc.length > OVERLONG_FACTOR * en.length) { out.push('overlong'); }
  const low = loc.toLowerCase();
  const hit = (INVENTED[locale] ?? []).find((p) => low.includes(p.phrase) && !(p.excuse && p.excuse.test(en)));
  if (hit) { out.push(`invented:${hit.phrase.slice(0, 30)}`); }
  // Only ur: the check says "this is Sindhi, not Urdu", which means nothing elsewhere.
  if (locale === 'ur' && SINDHI_ONLY.test(loc)) { out.push('sindhi'); }
  return out;
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

  // The shipped catalogs are clean, so without this a broken pattern would pass unnoticed.
  it('flags Sindhi letters in ur only, and passes Urdu', () => {
    const sindhi = 'هٽايو';
    const urdu = 'ٹڈڑںھہے';
    assert.ok(mtEchoProblems('Remove', sindhi, 'ur').includes('sindhi'));
    assert.ok(!mtEchoProblems('Remove', urdu, 'ur').includes('sindhi'));
    assert.ok(!mtEchoProblems('Remove', sindhi, 'ar').includes('sindhi'));
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
        const echo: string[] = [];
        const identical: string[] = [];
        for (const k of Object.keys(en)) {
          const lv = loc[k];
          if (typeof lv !== 'string') { continue; }
          const ev = String(en[k]);
          const pp = placeholderProblems(ev, lv);
          if (pp.length) { bad.push(`${k} (${pp.join(',')})`); }
          const me = mtEchoProblems(ev, lv, l);
          if (me.length) { echo.push(`${k} (${me.join(',')})`); }
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
          ...echo.map((k) => `mt-echo ${k}`),
          ...(FAIL_ON_IDENTICAL ? identical.map((k) => `identical ${k}`) : []),
        ];
        assert.strictEqual(problems.length, 0,
          `${problems.length} problem(s), first: ${problems.slice(0, 5).join('; ')}`);
      });
    }
  }
});
