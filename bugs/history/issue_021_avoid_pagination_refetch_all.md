# Avoid Pagination Refetch All

**GitHub:** [https://github.com/saropa/saropa_lints/issues/21](https://github.com/saropa/saropa_lints/issues/21)

**Opened:** 2026-01-23T13:50:02Z

**Resolved in:** N/A — Not viable (ROADMAP.md § Rules reviewed and not viable: detection surface too narrow; near-zero real-world detections). Issue closed.

---

## Detail

### Problem  
Refetching all pages on refresh wastes bandwidth and can slow down the app. Pagination logic should only fetch new or changed data, not reset and reload all pages.

### Why This Is Complex  
- **Pattern detection:** Requires understanding how pagination and refresh logic are implemented.
- **API diversity:** Different APIs and state management solutions handle pagination differently.
- **False positives:** Some use cases may require a full refresh.

### Desired Outcome  
- Detect refresh logic that resets all paginated data.
- Warn about unnecessary refetching.
- Suggest incremental or delta refresh strategies.

### References  
- See ROADMAP.md section: "avoid_pagination_refetch_all"
