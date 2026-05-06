# Deferred: Unreliable Detection Rules

> **Last reviewed:** 2026-04-13

## Why these rules cannot be implemented

These rules describe real problems, but the detection criteria are **too subjective, too abstract, or too context-dependent** for reliable AST-based analysis. Implementing them would produce unacceptable false-positive rates.

The categories below explain the specific detection problem for each group.

### What would unblock these rules

Most of these have **no clear path forward**. The fundamental problem is that static analysis cannot determine intent, runtime state, or subjective quality thresholds. Possible future approaches:

- **Configurable thresholds** could make some rules viable if users accept tuning (e.g., "build method > N lines"). Risk: arbitrary defaults annoy more than they help.
- **ML-based heuristics** could reduce false positives for pattern-matching rules. No infrastructure for this exists.
- **Runtime analysis tools** (DevTools integration) could detect issues like "loading state too long" or "too much caching." This is a different product category.

---

## Heuristic: Subjective Criteria (14 rules)

The detection trigger depends on human judgment calls like "too many," "over-reliance," or "sparingly." No threshold would be correct for all projects.

| Rule | What makes it subjective |
|------|--------------------------|
| `require_snackbar_duration_consideration` | "Important content" in a snackbar is subjective. |
| `require_bloc_one_per_feature` | "Unrelated events" in a Bloc is subjective. |
| `avoid_getx_for_everything` | "Over-reliance on GetX" is subjective. |
| `avoid_notification_overload` | "High-frequency notifications" is subjective. |
| `prefer_feature_folders` | "Flat structure with many files" is heuristic. |
| `avoid_util_class` | Name matching "Util/Helper" produces false positives on legitimate utility classes. |
| `require_single_responsibility` | "Mixed concerns" in a class is subjective. |
| `avoid_excessive_logging` | "High-frequency log calls" threshold is arbitrary. |
| `avoid_service_locator_abuse` | "Business logic" detection is heuristic. |
| `avoid_insufficient_contrast` | Contrast calculation needs runtime color values, not AST. [#43](https://github.com/saropa/saropa_lints/issues/43) |
| `prefer_extract_widget` | "Build > 100 lines" is arbitrary; some large builds are fine. |
| `prefer_inline_comments_sparingly` | "Sparingly" is subjective; any threshold is arbitrary. |
| `require_cache_invalidation` | "Cache needs invalidation" is context-dependent. [#38](https://github.com/saropa/saropa_lints/issues/38) |
| `require_cache_ttl` | "Cache needs TTL" is context-dependent. [#39](https://github.com/saropa/saropa_lints/issues/39) |

## Heuristic: Package-Specific Patterns (13 rules)

These rules check for patterns in specific packages where the "correct" usage varies by context, making reliable detection impossible.

| Rule | Package | What makes it unreliable |
|------|---------|--------------------------|
| `require_google_signin_disconnect_on_logout` | google_sign_in | What constitutes "logout" is context-dependent. |
| `avoid_google_signin_silent_without_fallback` | google_sign_in | Interactive fallback flow varies by app. |
| `require_apple_credential_state_check` | sign_in_with_apple | Prior state check may happen elsewhere. |
| `avoid_storing_apple_identity_token` | sign_in_with_apple | Tracing token to storage calls requires data-flow analysis. |
| `require_google_sign_in_platform_interface_error_handling` | google_sign_in_platform_interface | "Error handling" patterns vary. |
| `require_google_sign_in_platform_interface_logout_cleanup` | google_sign_in_platform_interface | Logout cleanup is context-dependent. |
| `require_googleapis_auth_error_handling` | googleapis_auth | Auth error handling varies by app. |
| `require_googleapis_auth_logout_cleanup` | googleapis_auth | Logout cleanup is context-dependent. |
| `require_webview_clear_on_logout` | webview_flutter | Logout detection is context-dependent. |
| `require_cache_manager_clear_on_logout` | flutter_cache_manager | Logout detection is context-dependent. |
| `require_workmanager_error_handling` | workmanager | "Retry logic" definition is vague. |
| `avoid_over_caching` | — | "Excessive cache usage" is subjective. |
| `require_app_links_validation` | app_links | "Validation" definition is vague. |

## Heuristic: "Check Before Use" (10 rules)

These rules want to verify that a permission/availability check happens before an API call. The check may be in a separate method, a parent widget, a service layer, or a framework lifecycle hook — making single-file detection produce constant false positives.

| Rule | Package | What it wants to check |
|------|---------|------------------------|
| `require_calendar_permission_check` | device_calendar | Permission before calendar access. |
| `require_contacts_permission_check` | flutter_contacts | Permission before contacts access. |
| `require_contacts_error_handling` | flutter_contacts | Permission denied handling. |
| `avoid_contacts_full_fetch` | flutter_contacts | Use `withProperties` for needed fields only. |
| `require_device_info_permission_check` | device_info_plus | Permission before device info access. |
| `require_device_info_error_handling` | device_info_plus | Error handling for device info. |
| `require_package_info_permission_check` | package_info_plus | Permission before package info access. |
| `require_package_info_error_handling` | package_info_plus | Error handling for package info. |
| `require_speech_permission_check` | speech_to_text | Microphone permission before speech. |
| `require_speech_availability_check` | speech_to_text | `isAvailable` check before speech. |

## Too Complex: No Reliable AST Pattern (6 rules)

The concept these rules describe does not map to a detectable AST pattern. The "violation" is a design-level or runtime-level concern that cannot be identified from syntax.

| Rule | Why no AST pattern exists |
|------|---------------------------|
| `require_loading_timeout` | "Loading state" is too abstract to define in AST terms. |
| `require_loading_state_distinction` | Initial vs refresh loading is a runtime distinction. |
| `require_refresh_completion_feedback` | "Visible change" after refresh is a runtime concern. |
| `require_infinite_scroll_end_indicator` | Scroll + hasMore + indicator interaction is too complex. |
| `prefer_composition_over_inheritance` | "Composition vs inheritance" is a design principle, not a syntax pattern. |
| `prefer_automatic_dispose` | Automatic dispose detection needs lifecycle/context awareness. |

## Context-Dependent (1 rule)

| Rule | Why it needs context |
|------|---------------------|
| `avoid_cache_in_build` | Cache lookups in `build()` may or may not be expensive. Detecting `build()` context is possible, but determining if a call is "a cache lookup" vs "a simple getter" is not. |

## In-App Purchase / Review (5 rules)

| Rule | Package | What makes it unreliable |
|------|---------|--------------------------|
| `avoid_in_app_review_on_first_launch` | in_app_review | "First launch" detection requires app state tracking. |
| `require_in_app_review_availability_check` | in_app_review | Availability check may be elsewhere. |
| `require_iap_error_handling` | in_app_purchase | `PurchaseStatus` handling patterns vary. |
| `require_iap_verification` | in_app_purchase | "Server-side verification" cannot be detected in client code. |
| `require_geomag_permission_check` | geomag | Permission check may be in a separate method. |

## Other (5 rules)

| Rule | What makes it unreliable |
|------|--------------------------|
| `avoid_url_launcher_untrusted_urls` | Tracing URL source to determine "trusted" vs "untrusted" requires data-flow analysis. |
| `require_file_picker_permission_check` | Permission check may be in a separate method. |
| `require_file_picker_type_validation` | "Type validation" definition is vague. |
| `require_file_picker_size_check` | "Size check" definition is vague. |
| `require_password_strength_threshold` | Score threshold usage patterns vary by app. |

**Total: 54 rules**
