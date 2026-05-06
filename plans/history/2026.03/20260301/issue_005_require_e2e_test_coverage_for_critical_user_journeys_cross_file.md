# Require E2E Test Coverage for Critical User Journeys (Cross-File)

**GitHub:** [https://github.com/saropa/saropa_lints/issues/5](https://github.com/saropa/saropa_lints/issues/5)

**Opened:** 2026-01-23T13:34:18Z

**Resolved in:** N/A — Deferred (ROADMAP.md Part 2: Cross-file; critical path identification requires config/heuristics). Issue closed.

---

## Detail

### Problem  
Integration (end-to-end) tests are expensive to run, so they should focus on critical user journeys (e.g., signup, purchase, core features) rather than duplicating unit test coverage. Ensuring that all essential flows are covered by E2E tests is vital for app quality.

### Why This Is Complex  
- **Cross-file analysis:** User journeys may span multiple files, screens, and features.
- **Test mapping:** The tool must identify which flows are covered by E2E tests and which are not.
- **Critical path identification:** Determining what constitutes a "critical" journey may require configuration or heuristics.
- **Duplication detection:** Avoiding overlap with unit test coverage is non-trivial.

### Desired Outcome  
- Analyze E2E tests to ensure all critical user journeys are covered.
- Report missing coverage for any essential flow.
- Provide diagnostics and suggestions for adding necessary E2E tests.

### References  
- See ROADMAP.md section: "require_e2e_coverage"
