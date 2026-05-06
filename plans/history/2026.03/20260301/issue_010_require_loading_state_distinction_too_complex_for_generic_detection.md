# Require Loading State Distinction (Too Complex for Generic Detection)

**GitHub:** [https://github.com/saropa/saropa_lints/issues/10](https://github.com/saropa/saropa_lints/issues/10)

**Opened:** 2026-01-23T13:44:41Z

**Resolved in:** N/A — Not viable for generic detection (ROADMAP.md Part 2: pattern ambiguity; package-specific rules may be considered). Issue closed.

---

## Detail

### Problem  
Distinguishing between "initial load" and "refresh" states in UI is important for user experience, but static analysis cannot reliably detect these patterns due to their abstract and varied implementations.

### Why This Is Complex  
- **Pattern ambiguity:** "Initial load" and "refresh" are not standardized in code.
- **State management diversity:** Many state management solutions and custom patterns exist.
- **UI logic:** The distinction is often made in runtime logic, not statically analyzable code.
- **False positives:** Attempting to detect this generically would result in many incorrect flags.

### Desired Outcome  
- Document the limitation: static analysis cannot reliably distinguish loading state types.
- Consider package-specific or pattern-based rules for common libraries.
- Encourage explicit state distinction in code and documentation.

### References  
- See ROADMAP.md section: "require_loading_state_distinction"
