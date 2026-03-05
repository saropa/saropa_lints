# Require Bloc Test Coverage for All State Transitions (Cross-File)

**GitHub:** [https://github.com/saropa/saropa_lints/issues/4](https://github.com/saropa/saropa_lints/issues/4)

**Opened:** 2026-01-23T13:34:08Z

**Resolved in:** N/A — Deferred (ROADMAP.md Part 2: Cross-file analysis; Bloc/events/tests in separate files). Issue closed.

---

## Detail

### Problem  
Bloc and Cubit state management patterns can have complex state transitions. If all transitions are not covered by tests, bugs may go undetected, especially in edge cases. Ensuring every event and state transition is tested is critical for reliability.

### Why This Is Complex  
- **Cross-file analysis:** Blocs, events, and tests are often in separate files, requiring mapping between them.
- **State transition mapping:** The tool must understand the full state machine and which transitions are exercised by tests.
- **Dynamic event handling:** Events may be handled in various ways, including via mixins or abstract classes.
- **Test coverage analysis:** Requires correlating test cases to state transitions, which may not be explicit.

### Desired Outcome  
- Analyze Bloc/Cubit classes and their associated tests to ensure all state transitions are covered.
- Report missing test coverage for any event or transition.
- Provide diagnostics to help developers add missing tests.

### References  
- See ROADMAP.md section: "require_bloc_test_coverage"
