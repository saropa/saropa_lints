/** SPDX license risk tiers. */
export type LicenseTier = 'permissive' | 'copyleft' | 'unknown';

const PERMISSIVE = new Set([
    'MIT', 'BSD-2-Clause', 'BSD-3-Clause', 'Apache-2.0',
    'ISC', 'Zlib', 'Unlicense', 'BSL-1.0', '0BSD',
]);

const COPYLEFT = new Set([
    'GPL-2.0', 'GPL-2.0-only', 'GPL-2.0-or-later',
    'GPL-3.0', 'GPL-3.0-only', 'GPL-3.0-or-later',
    'LGPL-2.1', 'LGPL-2.1-only', 'LGPL-2.1-or-later',
    'LGPL-3.0', 'LGPL-3.0-only', 'LGPL-3.0-or-later',
    'MPL-2.0', 'AGPL-3.0', 'AGPL-3.0-only', 'AGPL-3.0-or-later',
]);

/** Classify an SPDX identifier into a risk tier. */
export function classifyLicense(spdx: string | null): LicenseTier {
    if (!spdx || !spdx.trim()) { return 'unknown'; }
    const isOr = /\s+OR\s+/i.test(spdx);
    const ids = spdx.split(/\s+(?:OR|AND)\s+/i).map(s => s.trim());
    const tiers = ids.map(classifySingle);
    if (isOr) { return leastRestrictive(tiers); }
    return mostRestrictive(tiers);
}

function leastRestrictive(tiers: LicenseTier[]): LicenseTier {
    if (tiers.includes('permissive')) { return 'permissive'; }
    if (tiers.includes('copyleft')) { return 'copyleft'; }
    return 'unknown';
}

function mostRestrictive(tiers: LicenseTier[]): LicenseTier {
    if (tiers.includes('copyleft')) { return 'copyleft'; }
    if (tiers.includes('permissive')) { return 'permissive'; }
    return 'unknown';
}

function classifySingle(id: string): LicenseTier {
    if (PERMISSIVE.has(id)) { return 'permissive'; }
    if (COPYLEFT.has(id)) { return 'copyleft'; }
    return 'unknown';
}

/** Emoji indicator for a license tier. */
export function licenseEmoji(tier: LicenseTier): string {
    switch (tier) {
        case 'permissive': return '🟢';
        case 'copyleft': return '🟡';
        case 'unknown': return '🔴';
    }
}
