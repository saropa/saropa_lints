# Avoid Infinite Scroll Duplicate Requests

**GitHub:** [https://github.com/saropa/saropa_lints/issues/38](https://github.com/saropa/saropa_lints/issues/38)

**Opened:** 2026-01-23T14:01:35Z

**Resolved in:** v4.14.5 — rule `avoid_infinite_scroll_duplicate_requests` implemented; GitHub issue closed as completed.

---

## Detail

### Problem  
Multiple simultaneous page requests in infinite scroll can cause data duplication, wasted bandwidth, and race conditions. Proper loading guards should be implemented.

### Why This Is Complex  
- **Pattern detection:** Requires analyzing ScrollController listeners and loading state guards.
- **UI diversity:** Loading guards may be implemented in various ways.
- **False positives:** Some apps may intentionally allow concurrent requests.

### Desired Outcome  
- Detect scroll listener without loading guard.
- Warn about potential duplicate requests.
- Suggest best practices for guarding against duplicate page loads.

### References  
- See ROADMAP.md section: "avoid_infinite_scroll_duplicate_requests"
