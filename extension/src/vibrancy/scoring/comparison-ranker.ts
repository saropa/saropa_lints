import { ComparisonData, DimensionWinner, RankedComparison } from '../types';
import { formatSizeMB } from './bloat-calculator';

type DimensionExtractor = (pkg: ComparisonData) => number | null;
type DimensionFormatter = (value: number | null) => string;

interface DimensionDef {
    readonly name: string;
    readonly extract: DimensionExtractor;
    readonly format: DimensionFormatter;
    readonly higherIsBetter: boolean;
}

const DIMENSIONS: readonly DimensionDef[] = [
    {
        name: 'Vibrancy Score',
        extract: p => p.vibrancyScore,
        format: v => v !== null ? `${v}/100` : '—',
        higherIsBetter: true,
    },
    {
        name: 'Pub Points',
        extract: p => p.pubPoints,
        format: v => v !== null ? String(v) : '—',
        higherIsBetter: true,
    },
    {
        name: 'GitHub Stars',
        extract: p => p.stars,
        format: v => v !== null ? v.toLocaleString() : '—',
        higherIsBetter: true,
    },
    {
        name: 'Archive Size',
        extract: p => p.archiveSizeBytes,
        format: v => v !== null ? formatSizeMB(v) : '—',
        higherIsBetter: false,
    },
    {
        name: 'Bloat Rating',
        extract: p => p.bloatRating,
        format: v => v !== null ? `${v}/10` : '—',
        higherIsBetter: false,
    },
    {
        name: 'Open Issues',
        extract: p => p.openIssues,
        format: v => v !== null ? String(v) : '—',
        higherIsBetter: false,
    },
];

function findDimensionWinner(
    packages: readonly ComparisonData[],
    def: DimensionDef,
): DimensionWinner | null {
    const values = packages.map(pkg => ({
        name: pkg.name,
        numValue: def.extract(pkg),
    }));

    const validValues = values.filter(v => v.numValue !== null);
    if (validValues.length === 0) {
        return null;
    }

    const sorted = [...validValues].sort((a, b) => {
        const aVal = a.numValue!;
        const bVal = b.numValue!;
        return def.higherIsBetter ? bVal - aVal : aVal - bVal;
    });

    const winnerValue = sorted[0].numValue;
    const winners = sorted.filter(v => v.numValue === winnerValue);

    if (winners.length === validValues.length) {
        return null;
    }

    const winnerName = winners.length === 1
        ? winners[0].name
        : winners.map(w => w.name).join(', ');

    return {
        dimension: def.name,
        winnerName,
        value: def.format(winnerValue),
        allValues: values.map(v => ({
            name: v.name,
            value: def.format(v.numValue),
            isWinner: winners.some(w => w.name === v.name),
        })),
    };
}

function buildRecommendation(
    packages: readonly ComparisonData[],
    winners: readonly DimensionWinner[],
): string {
    if (packages.length === 0) {
        return 'No packages to compare.';
    }

    const winCounts = new Map<string, number>();
    for (const pkg of packages) {
        winCounts.set(pkg.name, 0);
    }
    for (const w of winners) {
        const names = w.winnerName.split(', ');
        for (const name of names) {
            winCounts.set(name, (winCounts.get(name) ?? 0) + 1);
        }
    }

    const sorted = [...winCounts.entries()].sort((a, b) => b[1] - a[1]);
    const [topName, topWins] = sorted[0];

    if (topWins === 0) {
        return 'No clear winner — packages are comparable across dimensions.';
    }

    const verifiedPkg = packages.find(p => p.publisher !== null);
    const topPkg = packages.find(p => p.name === topName);
    const hasVerifiedPublisher = topPkg?.publisher !== null;

    let rec = `**${topName}** leads in ${topWins} dimension${topWins > 1 ? 's' : ''}.`;

    if (hasVerifiedPublisher) {
        rec += ` Has verified publisher (${topPkg!.publisher}).`;
    } else if (verifiedPkg && verifiedPkg.name !== topName) {
        rec += ` Note: **${verifiedPkg.name}** has a verified publisher.`;
    }

    const starsWinner = winners.find(w => w.dimension === 'GitHub Stars');
    if (starsWinner && starsWinner.winnerName !== topName) {
        rec += ` **${starsWinner.winnerName}** has more community traction (stars).`;
    }

    const inProjectPkgs = packages.filter(p => p.inProject);
    if (inProjectPkgs.length > 0 && !inProjectPkgs.some(p => p.name === topName)) {
        rec += ` ${inProjectPkgs.map(p => `**${p.name}**`).join(', ')} already in project.`;
    }

    return rec;
}

/** Rank packages across comparison dimensions. Pure function. */
export function rankPackages(
    packages: readonly ComparisonData[],
): RankedComparison {
    if (packages.length === 0) {
        return {
            packages: [],
            winners: [],
            recommendation: 'No packages to compare.',
        };
    }

    const winners: DimensionWinner[] = [];
    for (const def of DIMENSIONS) {
        const winner = findDimensionWinner(packages, def);
        if (winner) {
            winners.push(winner);
        }
    }

    return {
        packages,
        winners,
        recommendation: buildRecommendation(packages, winners),
    };
}

/** Convert a VibrancyResult to ComparisonData. */
export function resultToComparisonData(
    result: {
        readonly package: { readonly name: string };
        readonly score: number;
        readonly category: import('../types').VibrancyCategory;
        readonly pubDev?: {
            readonly publishedDate: string;
            readonly publisher?: string | null;
            readonly pubPoints?: number;
        } | null;
        readonly github?: { readonly stars: number; readonly openIssues: number } | null;
        readonly archiveSizeBytes: number | null;
        readonly bloatRating: number | null;
        readonly license: string | null;
        readonly platforms: readonly string[] | null;
        readonly updateInfo?: { readonly latestVersion: string } | null;
    },
    inProject: boolean,
): ComparisonData {
    return {
        name: result.package.name,
        vibrancyScore: result.score,
        category: result.category,
        latestVersion: result.updateInfo?.latestVersion ?? result.pubDev?.publishedDate?.split('T')[0] ?? '',
        publishedDate: result.pubDev?.publishedDate?.split('T')[0] ?? null,
        publisher: result.pubDev?.publisher ?? null,
        pubPoints: result.pubDev?.pubPoints ?? 0,
        stars: result.github?.stars ?? null,
        openIssues: result.github?.openIssues ?? null,
        archiveSizeBytes: result.archiveSizeBytes,
        bloatRating: result.bloatRating,
        license: result.license,
        platforms: result.platforms ?? [],
        inProject,
    };
}

/** Check if a package is the winner for a dimension. */
export function isWinnerForDimension(
    packageName: string,
    dimensionName: string,
    winners: readonly DimensionWinner[],
): boolean {
    const winner = winners.find(w => w.dimension === dimensionName);
    if (!winner) { return false; }
    return winner.winnerName.split(', ').includes(packageName);
}
