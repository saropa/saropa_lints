# Require Pagination for Large Lists

**GitHub:** [https://github.com/saropa/saropa_lints/issues/20](https://github.com/saropa/saropa_lints/issues/20)

**Opened:** 2026-01-23T13:49:53Z

**Resolved in:** v6.0.7 — rule `require_pagination_for_large_lists` implemented; GitHub issue closed as completed.

---

## Detail

### Problem  
Loading all items at once in a ListView or GridView can cause out-of-memory errors and slow UI performance. Large lists should implement pagination to load data in chunks.

### Why This Is Complex  
- **Pattern detection:** Identifying large lists and their data sources requires static and possibly runtime analysis.
- **Thresholds:** What counts as "large" may vary by context or configuration.
- **False positives:** Some lists are intentionally small or static.

### Desired Outcome  
- Detect ListView/GridView with large itemCount without pagination.
- Warn about potential performance and memory issues.
- Suggest implementing pagination for large lists.

### References  
- See ROADMAP.md section: "require_pagination_for_large_lists"
