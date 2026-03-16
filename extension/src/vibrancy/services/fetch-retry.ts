import { ScanLogger } from './scan-logger';

const MAX_RETRIES = 3;
const BASE_DELAY_MS = 1000;

/** Status codes that warrant a retry. */
function isRetryable(status: number): boolean {
    return status === 429 || (status >= 500 && status < 600);
}

/** Parse Retry-After header (seconds) into milliseconds. */
function parseRetryAfter(resp: Response): number | null {
    const header = resp.headers.get('Retry-After');
    if (!header) { return null; }
    const seconds = parseInt(header, 10);
    return Number.isFinite(seconds) ? seconds * 1000 : null;
}

/**
 * Fetch with automatic retry on 429 and 5xx responses.
 * Returns the last Response regardless of success — callers check `.ok`.
 */
export async function fetchWithRetry(
    url: string,
    init?: RequestInit,
    logger?: ScanLogger,
): Promise<Response> {
    let lastResp!: Response;

    for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
        lastResp = await fetch(url, init);
        if (!isRetryable(lastResp.status)) { return lastResp; }
        if (attempt + 1 >= MAX_RETRIES) { break; }

        const delay = parseRetryAfter(lastResp)
            ?? BASE_DELAY_MS * Math.pow(2, attempt);
        logger?.info(
            `Retry ${attempt + 1}/${MAX_RETRIES - 1} for ${url} ` +
            `(${lastResp.status}, wait ${delay}ms)`,
        );
        await new Promise(r => setTimeout(r, delay));
    }

    return lastResp;
}
