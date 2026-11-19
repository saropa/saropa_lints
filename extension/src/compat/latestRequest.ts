/** Tracks the newest of several overlapping async requests so stale results can be dropped. */
export interface LatestRequest {
  /** Starts a request and returns its id. */
  begin(): number;
  /** True while `id` is still the newest request. */
  isCurrent(id: number): boolean;
}

export function createLatestRequest(): LatestRequest {
  let latest = 0;
  return {
    begin: () => ++latest,
    isCurrent: (id) => id === latest,
  };
}
