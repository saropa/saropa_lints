# Require RTL Layout Support

**GitHub:** [https://github.com/saropa/saropa_lints/issues/25](https://github.com/saropa/saropa_lints/issues/25)

**Opened:** 2026-01-23T13:50:26Z

**Resolved in:** v4.15.1 — rule `require_rtl_layout_support` implemented; GitHub issue closed as completed.

---

## Detail

### Problem  
Right-to-left (RTL) languages need directional awareness in layouts. Hardcoded left/right values can break RTL support and cause poor user experience for RTL users.

### Why This Is Complex  
- **Pattern detection:** Requires analyzing layout code for hardcoded left/right values.
- **UI diversity:** Directionality may be handled at various levels.
- **False positives:** Some left/right values are intentional for LTR-only apps.

### Desired Outcome  
- Detect hardcoded left/right in layouts without Directionality check.
- Warn about missing RTL support.
- Suggest best practices for RTL-aware layouts.

### References  
- See ROADMAP.md section: "require_rtl_layout_support"
