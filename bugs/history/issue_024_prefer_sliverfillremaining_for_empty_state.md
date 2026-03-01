# Prefer SliverFillRemaining for Empty State

**GitHub:** [https://github.com/saropa/saropa_lints/issues/24](https://github.com/saropa/saropa_lints/issues/24)

**Opened:** 2026-01-23T13:50:20Z

**Resolved in:** v4.14.5 — rule `prefer_sliverfillremaining_for_empty` implemented; GitHub issue closed as completed.

---

## Detail

### Problem  
In a CustomScrollView, the empty state should use SliverFillRemaining to fill available space. Using a regular sliver for empty state can result in poor layout and user experience.

### Why This Is Complex  
- **Pattern detection:** Requires analyzing CustomScrollView and its children.
- **UI diversity:** Empty states may be implemented in various ways.
- **False positives:** Some layouts may intentionally not fill remaining space.

### Desired Outcome  
- Detect empty state widget as a regular sliver in CustomScrollView.
- Warn about potential layout issues.
- Suggest using SliverFillRemaining for empty states.

### References  
- See ROADMAP.md section: "prefer_sliverfillremaining_for_empty"
