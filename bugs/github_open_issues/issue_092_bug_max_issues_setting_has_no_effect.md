# Bug: max_issues setting has no effect

**GitHub:** [https://github.com/saropa/saropa_lints/issues/92](https://github.com/saropa/saropa_lints/issues/92)

**Opened:** 2026-02-06T13:11:25Z

---

## Detail

**Bug: `max_issues` setting in analysis_options_custom.yaml has no effect**                                                                                  
                                                                                                                               
  [`_loadMaxIssuesConfig()`](https://github.com/saropa/saropa_lints/blob/9b639a1b525cf2e2273852f624cd8b8906ef4539/lib/saropa_lints.dart#L2746-L2764) uses a relative path:                                                                                  
                                                                                                                               

  ```dart                                                                                                                     
  final customConfigFile = File('analysis_options_custom.yaml');
  if (!customConfigFile.existsSync()) return;
  ```


  The custom_lint plugin runs in a temporary directory, not the project root.
  The file is never found, so `setMaxIssues()` is never called and the
  default (1000) is always used regardless of what the user configures.
