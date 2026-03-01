# Avoid Never Passed Parameters (Cross-File)

**GitHub:** [https://github.com/saropa/saropa_lints/issues/8](https://github.com/saropa/saropa_lints/issues/8)

**Opened:** 2026-01-23T13:34:46Z

---

## Detail

### Problem  
Function parameters that are never passed by any caller are dead code and can lead to confusion or maintenance issues. Detecting such parameters requires analyzing all call sites, which may be spread across many files.

### Why This Is Complex  
- **Cross-file analysis:** Functions and their call sites are often in different files.
- **Dynamic invocation:** Functions may be passed as callbacks or invoked via reflection.
- **Call graph construction:** The tool must build a call graph to track parameter usage.
- **False positives:** Some parameters are required by interface or for future extensibility.

### Desired Outcome  
- Analyze all function definitions and call sites to detect parameters that are never passed.
- Report diagnostics for any such parameters.
- Suggest removing unused parameters or documenting their necessity.

### References  
- See ROADMAP.md section: "avoid_never_passed_parameters"
