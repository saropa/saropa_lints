# Require Temp File Cleanup Across Files

**GitHub:** [https://github.com/saropa/saropa_lints/issues/6](https://github.com/saropa/saropa_lints/issues/6)

**Opened:** 2026-01-23T13:34:26Z

---

## Detail

### Problem  
Temporary files created during app execution can accumulate if not properly deleted, leading to wasted storage and potential privacy issues. Detecting temp file creation without corresponding cleanup is especially challenging when creation and deletion occur in different files.

### Why This Is Complex  
- **Cross-file analysis:** Temp file creation and deletion may be separated across files, classes, or even packages.
- **Dynamic file handling:** Files may be created and deleted via various APIs or custom wrappers.
- **Lifecycle tracking:** The tool must track the lifecycle of temp files from creation to deletion.
- **False positives:** Some temp files are intentionally persistent; distinguishing intent is difficult.

### Desired Outcome  
- Analyze codebase to detect temp file creation without corresponding deletion.
- Report diagnostics for any temp files that are not cleaned up.
- Suggest best practices for managing temp files.

### References  
- See ROADMAP.md section: "require_temp_file_cleanup"
