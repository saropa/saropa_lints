/**
 * Full-history opportunity scan.
 *
 * Unlike the upgrade-delta path (`buildUpdateInfo`, which only looks at the
 * versions between your current and latest and short-circuits up-to-date
 * packages entirely), this mines a package's ENTIRE changelog for adoptable
 * features. The reason: "up-to-date" means your version constraint is
 * satisfied, not that you have adopted everything the package added across the
 * releases a caret constraint silently carried you through. Those unadopted
 * features are the needles that the delta-only view can never surface.
 *
 * The fetch reuses `fetchChangelogWithFallback`, which is cached per
 * repo/package in the persistent `CacheService` — so running this for every
 * package (not just outdated ones) costs at most one fetch per package per
 * 24h TTL window, shared with the upgrade-delta path.
 */

import { CacheService } from './cache-service';
import {
    fetchChangelogWithFallback,
    parseAllEntries,
} from './changelog-service';
import {
    mineOpportunities,
    PackageOpportunities,
} from './changelog-opportunities';

/**
 * Fetch a package's full changelog and mine every adoptable feature from it.
 *
 * Returns `null` when no changelog could be found or it yields no
 * opportunities, so callers can treat "nothing to adopt" uniformly.
 */
export async function scanPackageOpportunities(
    repoInfo: { owner: string; repo: string; subpath: string | null } | null,
    packageName: string,
    params?: { token?: string; cache?: CacheService },
): Promise<PackageOpportunities | null> {
    const content = await fetchChangelogWithFallback(
        repoInfo, packageName, params,
    );
    if (!content) { return null; }

    const opportunities = mineOpportunities(parseAllEntries(content));
    return opportunities.opportunityCount > 0 ? opportunities : null;
}
