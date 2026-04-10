# Require Infinite Scroll End Indicator (Too Complex for Generic Detection)

**GitHub:** [https://github.com/saropa/saropa_lints/issues/12](https://github.com/saropa/saropa_lints/issues/12)

**Opened:** 2026-01-23T13:44:56Z

**Resolved in:** N/A — Not viable for generic detection (ROADMAP.md Part 2: complex pattern; package-specific rules may be considered). Issue closed.

---

## Detail

### Problem  
Infinite scroll UIs should indicate when all items are loaded, but detecting this pattern requires understanding scroll listeners, flags, and end indicatorsâ€”too many variables for reliable static analysis.

### Why This Is Complex  
- **Complex pattern:** Requires correlating scroll listeners, data flags, and UI indicators.
- **Implementation diversity:** Many ways to implement infinite scroll and end indicators.
- **State tracking:** Static analysis cannot reliably determine when all items are loaded.
- **False positives:** Overly broad detection would flag many valid infinite scroll implementations.

### Desired Outcome  
- Document the limitation: static analysis cannot reliably detect infinite scroll end indicators.
- Encourage explicit end-of-list indicators in UI code.
- Consider rules for specific libraries or patterns.

### References  
- See ROADMAP.md section: "require_infinite_scroll_end_indicator"
