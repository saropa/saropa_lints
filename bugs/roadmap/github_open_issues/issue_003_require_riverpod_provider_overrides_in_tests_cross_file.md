# Require Riverpod Provider Overrides in Tests (Cross-File)

**GitHub:** [https://github.com/saropa/saropa_lints/issues/3](https://github.com/saropa/saropa_lints/issues/3)

**Opened:** 2026-01-23T13:31:03Z

---

## Detail

### Problem  
Tests that use real Riverpod providers can have hidden dependencies and unpredictable state, leading to flaky or non-deterministic tests. Best practice is to override providers with mocks or fakes for isolated, deterministic testing.

### Why This Is Complex  
- **Cross-file context:** Tests and providers are often in separate files, requiring analysis of test files and the providers they use.
- **Dynamic usage:** Providers may be injected or referenced in various ways, including through test setup, fixtures, or helper functions.
- **Type and usage resolution:** The tool must resolve which providers are used in a test and whether they are overridden.
- **False positives:** Some tests may intentionally use real providers; distinguishing intent is difficult.

### Desired Outcome  
- Analyze test files to detect usage of real providers without overrides.
- Report diagnostics when a test uses a real provider without an explicit override.
- Suggest or document best practices for overriding providers in tests.

### References  
- See ROADMAP.md section: "require_riverpod_override_in_tests"
