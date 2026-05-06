

NOTE:

PS D:\src\contacts> dart run saropa_lints:init --tier professional
Building package executable... (1.2s)
Built saropa_lints:init.

SAROPA LINTS v4.9.3
Source: local: ../../saropa_lints

Tier: professional (level 3)
Recommended + architecture, testing, documentation


Rules: 1423 enabled / 254 disabled (+19 custom)
Severity: 179 errors · 512 warnings · 732 info

✓ Written to: analysis_options.yaml

Log written to: reports/20260129_084713_saropa_lints_init.log
Run analysis now? [y/N]: y

🚀 Running: dart run custom_lint
────────────────────────────────────────────────────────────
[custom_lint client] [saropa_lints] createPlugin() called - version 4.8.0
[custom_lint client] [saropa_lints] Loaded 1405 rules (tier: essential, enableAll: false)
░░░░░░░░░░░░░░░░░░░░ 1% │ Files: 46/3119 │ Issues: 1000+ │ ETA: 42m 54s │ action_icon_native_view.dart


[saropa_lints] Reports written:
  Full log: D:/src/contacts\reports/20260129_084821_saropa_full.log
  Summary:  D:/src/contacts\reports/20260129_084821_saropa_summary.md


█░░░░░░░░░░░░░░░░░░░ 6% │ Files: 196/3119 │ Issues: 1000+ │ ETA: 15m 12s │ contact_header_subtitle_huge.dart^C^CTerminate batch job (Y/N)? Terminate batch job (Y/N)? y


... my custom.yaml

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                    CUSTOM RULE OVERRIDES                                  ║
# ║                                                                           ║
# ║  Rules in this file are ALWAYS applied, even when using --reset.         ║
# ║  Use this for project-specific customizations that should persist.       ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
# ─────────────────────────────────────────────────────────────────────────────
# ANALYSIS SETTINGS (added in v4.9.1)
# ─────────────────────────────────────────────────────────────────────────────
# max_issues: Maximum warnings/info to track in detail (errors always tracked)
#   - Default: 1000
#   - Set to 0 for unlimited
#   - Lower values = faster analysis on legacy codebases

max_issues: 1000


#
# FORMAT: Add rules with true/false values. All formats below are supported:
#
#   rule_name: false                    # Simple format
#   - rule_name: false                  # With hyphen (YAML list style)
#   - rule_name: false  # Comment here  # With trailing comment
#
# EXAMPLES:
#
#   # Disable specific rules for this project:
#   - avoid_print: false                # Allow print statements
#   - avoid_null_assertion: false       # Allow ! operator
#
#   # Force-enable rules regardless of tier:
#   - prefer_const_constructors: true   # Always require const
#
# ─────────────────────────────────────────────────────────────────────────────
# Add your custom rule overrides below:
# ─────────────────────────────────────────────────────────────────────────────

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ~~~~~  SAROPA Opinionated (off by default, enable manually)  ~~~~~~
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
- avoid_future_in_build: false # TODO!
- avoid_null_assertion: false # Avoid using the null assertion operator (!).
- avoid_parameter_mutation: false #
- avoid_unawaited_future: false # TODO!
- pass_existing_future_to_future_builder: false # Creating new Future in FutureBuilder restarts the async o...
- pass_existing_stream_to_stream_builder: false # FutureBuilder/StreamBuilder should handle error state.

  # REF: D:\src\contacts\docs\PLAN_DATABASE_MIGRATIONS.md
- require_database_migration: false # TODO!

- require_error_widget: false # FutureBuilder/StreamBuilder should handle error state.

- require_late_initialization_in_init_state: false #
- avoid_nullable_interpolation: false # [WARNING] Avoid interpolating nullable values.
- require_future_timeout: false # [WARNING] Executing a long-running Future (such as network or I/O o...

- avoid_catching_generic_exception: false # [INFO] Avoid catching generic exceptions.
- require_https_only_test: false
- format_comment_style: false # too noisy
- format_comment_style: false # too noisy
- avoid_large_list_copy: false # too noisy
- move_variable_closer_to_its_usage: false # too noisy
- require_button_semantics: false # note ready for accessibility yet
- avoid_expensive_build: false # performance - this is a good one to do
- prefer_clip_behavior: false # performance - this is a good one to do



...