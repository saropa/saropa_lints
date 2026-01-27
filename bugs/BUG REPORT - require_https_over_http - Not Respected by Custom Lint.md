## Bug Report: `// ignore: require_https_over_http` Not Respected by Custom Lint

### Summary

The `require_https_over_http` lint rule is enabled in `analysis_options.yaml` and works as expected, but adding an inline ignore directive (`// ignore: require_https_over_http`) does not suppress the lint warning. This occurs even when the ignore is placed directly above the offending line.

### Environment

- **Project:** Flutter/Dart (Saropa Contacts App)
- **Linter:** custom_lint, saropa_lints
- **Rule:** `require_https_over_http`
- **Dart SDK:** (see project for version)
- **IDE:** VS Code (Windows)

### Steps to Reproduce

1. Enable `require_https_over_http` in `analysis_options.yaml`:

    ```yaml
    linter:
      rules:
        require_https_over_http: true
    ```

2. Add code that triggers the lint, e.g.:

    ```dart
    // ignore: require_https_over_http
    final url = 'http://example.com';
    ```

3. Run the linter or use "Dart: Run All Lint Checks" in VS Code.

### Expected Behavior

The linter should suppress the warning for the line with the ignore directive.

### Actual Behavior

The warning is still shown, and the ignore directive is not respected.

### Investigation

- The rule is present and active in `analysis_options.yaml`.
- The ignore directive is correctly formatted and placed.
- Searching the codebase shows no custom implementation of the rule.
- Other lints can be ignored as expected; only this rule is affected.
- No errors in the linter or build output related to configuration.

### Conclusion

This appears to be a bug in the linter or the rule implementation, not a configuration or usage error.

### Attachments

- Example code and config available on request.

---

**Please advise on a workaround or fix, or confirm if this is a known issue.**