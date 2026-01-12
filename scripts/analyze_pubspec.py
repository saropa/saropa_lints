#!/usr/bin/env python3
"""
Analyze a pubspec.yaml to suggest NEW LINT RULES for saropa_lints.

This script examines the packages used in a Flutter/Dart project and identifies
which packages are NOT YET covered by saropa_lints rules. It then suggests
specific rules that should be IMPLEMENTED in saropa_lints to provide coverage.

Version:   1.6
Author:    Saropa
Copyright: (c) 2025-2026 Saropa

Usage:
    python scripts/analyze_pubspec.py
    python scripts/analyze_pubspec.py <path_to_pubspec.yaml>

Output:
    - Colored console report
    - JSON file saved with datetime prefix (e.g., 2025-01-10_143052_saropa_analysis.json)
"""

from __future__ import annotations

import os
import sys
import json
from datetime import datetime
from enum import Enum
from pathlib import Path
from dataclasses import dataclass, field
from typing import Optional, NoReturn

# Try to import yaml, provide helpful error if not available
try:
    import yaml
except ImportError:
    print("Error: PyYAML is required. Install with: pip install pyyaml")
    sys.exit(1)


SCRIPT_VERSION = "2.5"


# =============================================================================
# EXIT CODES
# =============================================================================

class ExitCode(Enum):
    """Standard exit codes."""
    SUCCESS = 0
    FILE_NOT_FOUND = 1
    PARSE_ERROR = 2
    NO_DEPENDENCIES = 3
    USER_CANCELLED = 4


# =============================================================================
# COLOR AND PRINTING
# =============================================================================

class Color(Enum):
    """ANSI color codes."""
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RED = "\033[91m"
    CYAN = "\033[96m"
    MAGENTA = "\033[95m"
    WHITE = "\033[97m"
    RESET = "\033[0m"
    DIM = "\033[2m"
    BOLD = "\033[1m"


def enable_ansi_support() -> None:
    """Enable ANSI escape sequence support on Windows (CMD and PowerShell)."""
    if sys.platform == "win32":
        # Method 1: Enable VT processing via Windows API
        try:
            import ctypes
            from ctypes import wintypes

            kernel32 = ctypes.windll.kernel32

            # Enable for stdout
            STD_OUTPUT_HANDLE = -11
            handle = kernel32.GetStdHandle(STD_OUTPUT_HANDLE)
            if handle != -1:
                mode = wintypes.DWORD()
                if kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
                    ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
                    kernel32.SetConsoleMode(handle, mode.value | ENABLE_VIRTUAL_TERMINAL_PROCESSING)

            # Enable for stderr
            STD_ERROR_HANDLE = -12
            handle = kernel32.GetStdHandle(STD_ERROR_HANDLE)
            if handle != -1:
                mode = wintypes.DWORD()
                if kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
                    ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
                    kernel32.SetConsoleMode(handle, mode.value | ENABLE_VIRTUAL_TERMINAL_PROCESSING)
        except Exception:
            pass

        # Method 2: Set TERM environment variable (helps some terminals)
        if "TERM" not in os.environ:
            os.environ["TERM"] = "xterm-256color"


# cspell: disable
def show_saropa_logo() -> None:
    """Display the Saropa 'S' logo in ASCII art."""
    logo = """
\033[38;5;208m                               ....\033[0m
\033[38;5;208m                       `-+shdmNMMMMNmdhs+-\033[0m
\033[38;5;209m                    -odMMMNyo/-..````.++:+o+/-\033[0m
\033[38;5;215m                 `/dMMMMMM/`          ``````````\033[0m
\033[38;5;220m                `dMMMMMMMMNdhhhdddmmmNmmddhs+-\033[0m
\033[38;5;226m                /MMMMMMMMMMMMMMMMMMMMMMMMMMMMMNh/\033[0m
\033[38;5;190m              . :sdmNNNNMMMMMNNNMMMMMMMMMMMMMMMMm+\033[0m
\033[38;5;154m              o     `..~~~::~+==+~:/+sdNMMMMMMMMMMMo\033[0m
\033[38;5;118m              m                        .+NMMMMMMMMMN\033[0m
\033[38;5;123m              m+                         :MMMMMMMMMm\033[0m
\033[38;5;87m              /N:                        :MMMMMMMMM/\033[0m
\033[38;5;51m               oNs.                    `+NMMMMMMMMo\033[0m
\033[38;5;45m                :dNy/.              ./smMMMMMMMMm:\033[0m
\033[38;5;39m                 `/dMNmhyso+++oosydNNMMMMMMMMMd/\033[0m
\033[38;5;33m                    .odMMMMMMMMMMMMMMMMMMMMdo-\033[0m
\033[38;5;57m                       `-+shdNNMMMMNNdhs+-\033[0m
\033[38;5;57m                               ````\033[0m
"""
    print(logo)
    current_year = datetime.now().year
    copyright_year = f"2024-{current_year}" if current_year > 2024 else "2024"
    print(f"\033[38;5;195m(c) {copyright_year} Saropa. All rights reserved.\033[0m")
    print("\033[38;5;117mhttps://saropa.com\033[0m")
    print()
# cspell: enable


def print_colored(message: str, color: Color) -> None:
    """Print a message with ANSI color codes."""
    print(f"{color.value}{message}{Color.RESET.value}")


def print_header(text: str) -> None:
    """Print a section header."""
    print()
    print_colored("=" * 70, Color.CYAN)
    print_colored(f"  {text}", Color.CYAN)
    print_colored("=" * 70, Color.CYAN)
    print()


def print_subheader(text: str) -> None:
    """Print a subsection header."""
    print()
    print_colored("-" * 70, Color.MAGENTA)
    print_colored(f"  {text}", Color.MAGENTA)
    print_colored("-" * 70, Color.MAGENTA)
    print()


def print_success(text: str) -> None:
    """Print success message."""
    print_colored(f"  [OK] {text}", Color.GREEN)


def print_warning(text: str) -> None:
    """Print warning message."""
    print_colored(f"  [!] {text}", Color.YELLOW)


def print_error(text: str) -> None:
    """Print error message."""
    print_colored(f"  [X] {text}", Color.RED)


def print_info(text: str) -> None:
    """Print info message."""
    print_colored(f"  [>] {text}", Color.MAGENTA)


def exit_with_error(message: str, code: ExitCode) -> NoReturn:
    """Print error and exit."""
    print_error(message)
    sys.exit(code.value)


def prompt_for_file() -> str:
    """Prompt user for pubspec.yaml path."""
    print_colored("  Enter path to pubspec.yaml:", Color.CYAN)
    print_colored("  (or press Enter to cancel)", Color.DIM)
    print()

    try:
        user_input = input("  > ").strip()
    except (KeyboardInterrupt, EOFError):
        print()
        exit_with_error("Cancelled by user", ExitCode.USER_CANCELLED)

    if not user_input:
        exit_with_error("No file path provided", ExitCode.USER_CANCELLED)

    # Remove quotes if present
    user_input = user_input.strip('"').strip("'")

    return user_input


# =============================================================================
# DATA CLASSES
# =============================================================================

@dataclass
class RuleCoverage:
    """Represents saropa_lints coverage for a technology/package."""
    rule_file: str
    rule_count: int
    example_rules: list[str] = field(default_factory=list)
    description: str = ""


@dataclass
class PackageAnalysis:
    """Analysis result for a single package."""
    name: str
    category: str
    has_coverage: bool
    coverage: Optional[RuleCoverage] = None
    notes: str = ""


@dataclass
class SuggestedRule:
    """A rule that should be CREATED in saropa_lints."""
    name: str
    description: str
    severity: str = "warning"  # error, warning, info
    category: str = ""  # e.g., "security", "performance", "lifecycle"


@dataclass
class RelevantRule:
    """An EXISTING saropa_lints rule relevant to a package."""
    name: str
    tier: str  # essential, recommended, professional, comprehensive, insanity
    description: str


# =============================================================================
# TIERS - Order matters (lowest to highest)
# =============================================================================

TIER_ORDER = ["essential", "recommended", "professional", "comprehensive", "insanity"]

TIER_DESCRIPTIONS = {
    "essential": "Critical safety (crashes, security, memory leaks)",
    "recommended": "Essential + performance, accessibility, common mistakes",
    "professional": "Recommended + architecture, testing, i18n",
    "comprehensive": "Professional + thorough code quality",
    "insanity": "Everything (noisy, for greenfield projects)",
}


def count_tier_rules() -> tuple[dict[str, int], int]:
    """
    Count rules in each tier by reading the YAML files.
    Returns (tier_counts, total_rules).
    """
    script_dir = Path(__file__).parent
    tiers_dir = script_dir.parent / "lib" / "tiers"

    # Fallback counts if files not found
    fallback_counts = {
        "essential": 45,
        "recommended": 150,
        "professional": 350,
        "comprehensive": 700,
        "insanity": 1025,
    }

    if not tiers_dir.exists():
        return fallback_counts, fallback_counts["insanity"]

    tier_counts: dict[str, int] = {}
    cumulative = 0

    for tier in TIER_ORDER:
        tier_file = tiers_dir / f"{tier}.yaml"
        if not tier_file.exists():
            tier_counts[tier] = fallback_counts.get(tier, 0)
            continue

        try:
            with open(tier_file, 'r', encoding='utf-8') as f:
                tier_data = yaml.safe_load(f)

            # Count rules in this tier's custom_lint.rules section
            rules_in_tier = 0
            if tier_data and 'custom_lint' in tier_data:
                rules = tier_data['custom_lint'].get('rules', {})
                if isinstance(rules, dict):
                    rules_in_tier = len([k for k, v in rules.items() if v is True])

            cumulative += rules_in_tier
            tier_counts[tier] = cumulative

        except Exception:
            tier_counts[tier] = fallback_counts.get(tier, 0)

    total = tier_counts.get("insanity", fallback_counts["insanity"])
    return tier_counts, total


# Initialize tier counts
TIER_RULE_COUNTS, TOTAL_RULES = count_tier_rules()


# =============================================================================
# PACKAGE TO RELEVANT EXISTING RULES
# Maps packages to rules that ALREADY EXIST in saropa_lints
# =============================================================================

PACKAGE_TO_RELEVANT_RULES: dict[str, list[RelevantRule]] = {
    # State Management - Bloc
    "flutter_bloc": [
        RelevantRule("avoid_bloc_event_in_constructor", "recommended", "Don't dispatch events in bloc constructor"),
        RelevantRule("require_notify_listeners", "recommended", "Ensure state changes notify listeners"),
    ],
    "bloc": [
        RelevantRule("avoid_bloc_event_in_constructor", "recommended", "Don't dispatch events in bloc constructor"),
    ],

    # State Management - Provider
    "provider": [
        RelevantRule("avoid_build_context_in_providers", "essential", "Don't use BuildContext in provider callbacks"),
        RelevantRule("require_update_should_notify", "professional", "Implement updateShouldNotify for ChangeNotifier"),
        RelevantRule("avoid_watch_in_callbacks", "professional", "Don't watch providers in callbacks"),
    ],

    # State Management - Riverpod
    "riverpod": [
        RelevantRule("avoid_global_riverpod_providers", "professional", "Avoid global provider declarations"),
    ],
    "flutter_riverpod": [
        RelevantRule("avoid_global_riverpod_providers", "professional", "Avoid global provider declarations"),
    ],

    # Networking - Dio
    "dio": [
        RelevantRule("require_http_status_check", "recommended", "Check HTTP status codes"),
        RelevantRule("require_api_timeout", "recommended", "Set timeout on API calls"),
        RelevantRule("require_retry_logic", "professional", "Implement retry for transient failures"),
        RelevantRule("require_connectivity_check", "professional", "Check connectivity before requests"),
        RelevantRule("require_certificate_pinning", "professional", "Pin SSL certificates for security"),
    ],

    # Networking - http
    "http": [
        RelevantRule("require_http_status_check", "recommended", "Check HTTP status codes"),
        RelevantRule("require_api_timeout", "recommended", "Set timeout on API calls"),
        RelevantRule("require_http_client_close", "professional", "Close HTTP client when done"),
    ],

    # Security
    "flutter_secure_storage": [
        RelevantRule("require_secure_storage", "professional", "Use secure storage for sensitive data"),
        RelevantRule("avoid_hardcoded_credentials", "essential", "Don't hardcode passwords/keys"),
    ],
    "local_auth": [
        RelevantRule("require_biometric_fallback", "professional", "Provide fallback for biometric auth"),
    ],
    "crypto": [
        RelevantRule("avoid_weak_cryptographic_algorithms", "essential", "Don't use MD5, SHA1 for security"),
    ],

    # Images
    "cached_network_image": [
        RelevantRule("prefer_cached_network_image", "recommended", "Use cached images for performance"),
        RelevantRule("require_image_cache_dimensions", "professional", "Set cache dimensions"),
    ],
    "image_picker": [
        RelevantRule("require_image_disposal", "professional", "Dispose image resources"),
    ],

    # Animation
    "flutter_animate": [
        RelevantRule("require_animation_disposal", "essential", "Dispose animation controllers"),
    ],
    "lottie": [
        RelevantRule("require_animation_disposal", "essential", "Dispose animation controllers"),
    ],
    "rive": [
        RelevantRule("require_animation_disposal", "essential", "Dispose animation controllers"),
    ],

    # Location
    "geolocator": [
        RelevantRule("avoid_synchronous_file_io", "professional", "Don't block UI on location"),
    ],

    # WebView
    "webview_flutter": [
        RelevantRule("avoid_webview_javascript_enabled", "professional", "Be cautious with JS in WebView"),
    ],

    # Testing
    "flutter_test": [
        RelevantRule("require_test_assertions", "recommended", "Tests must have assertions"),
        RelevantRule("avoid_real_network_calls_in_tests", "recommended", "Mock network in tests"),
        RelevantRule("avoid_hardcoded_test_delays", "recommended", "Don't use fixed delays in tests"),
        RelevantRule("require_pump_after_interaction", "professional", "Pump after widget interactions"),
        RelevantRule("prefer_correct_test_file_name", "professional", "Name test files correctly"),
    ],

    # Shared Preferences
    "shared_preferences": [
        RelevantRule("require_secure_storage", "professional", "Don't store sensitive data"),
    ],

    # Forms
    "flutter_form_builder": [
        RelevantRule("avoid_form_without_key", "recommended", "Forms need GlobalKey"),
        RelevantRule("avoid_uncontrolled_text_field", "recommended", "Use controllers for text fields"),
    ],

    # Equatable
    "equatable": [
        # No specific rules yet, but covered in coverage
    ],

    # Internationalization
    "intl": [
        RelevantRule("avoid_hardcoded_strings_in_ui", "professional", "Externalize strings"),
        RelevantRule("require_locale_aware_formatting", "professional", "Use locale-aware formatters"),
        RelevantRule("avoid_hardcoded_locale", "professional", "Don't hardcode locale"),
    ],
    "easy_localization": [
        RelevantRule("avoid_hardcoded_strings_in_ui", "professional", "Externalize strings"),
    ],

    # Connectivity
    "connectivity_plus": [
        RelevantRule("require_connectivity_check", "professional", "Check before network calls"),
    ],

    # Debug/Logging
    "logger": [
        RelevantRule("avoid_print_in_production", "professional", "Remove print in production"),
        RelevantRule("avoid_logging_sensitive_data", "essential", "Don't log PII or tokens"),
    ],
    "logging": [
        RelevantRule("avoid_print_in_production", "professional", "Remove print in production"),
        RelevantRule("avoid_logging_sensitive_data", "essential", "Don't log PII or tokens"),
    ],
}


# =============================================================================
# SAROPA_LINTS EXISTING COVERAGE
# Packages that ALREADY have rules in saropa_lints
# =============================================================================

# cspell:ignore require_sqflite_whereargs
SAROPA_LINTS_COVERAGE: dict[str, RuleCoverage] = {
    # Database
    "isar": RuleCoverage(
        rule_file="isar_rules.dart",
        rule_count=1,
        example_rules=["avoid_isar_enum_field"],
        description="Isar database safety rules"
    ),
    "hive": RuleCoverage(
        rule_file="hive_rules.dart",
        rule_count=7,
        example_rules=["require_hive_initialization", "require_hive_type_adapter", "require_hive_box_close"],
        description="Hive database initialization, type adapters, and resource management"
    ),
    "sqflite": RuleCoverage(
        rule_file="file_handling_rules.dart",
        rule_count=5,
        example_rules=["require_sqflite_whereargs", "prefer_sqflite_batch", "require_sqflite_transaction"],
        description="SQLite security and performance"
    ),
    "firebase_firestore": RuleCoverage(
        rule_file="firebase_rules.dart",
        rule_count=20,
        example_rules=["avoid_firestore_unbounded_query", "avoid_firestore_in_widget_build"],
        description="Firestore query optimization and security"
    ),

    # Firebase
    "firebase_core": RuleCoverage(
        rule_file="firebase_rules.dart",
        rule_count=5,
        example_rules=["require_firebase_app_check"],
        description="Firebase core initialization"
    ),
    "firebase_analytics": RuleCoverage(
        rule_file="firebase_rules.dart",
        rule_count=4,
        example_rules=["incorrect_firebase_event_name", "incorrect_firebase_parameter_name"],
        description="Firebase Analytics validation"
    ),
    "firebase_crashlytics": RuleCoverage(
        rule_file="firebase_rules.dart",
        rule_count=2,
        example_rules=["require_crashlytics_user_id"],
        description="Crashlytics user identification"
    ),
    "firebase_messaging": RuleCoverage(
        rule_file="firebase_rules.dart",
        rule_count=3,
        example_rules=["require_fcm_token_refresh_handler", "require_background_message_handler"],
        description="FCM token management"
    ),

    # State Management
    "flutter_bloc": RuleCoverage(
        rule_file="state_management_rules.dart",
        rule_count=20,
        example_rules=["require_initial_state", "prefer_immutable_bloc_state", "avoid_bloc_state_mutation"],
        description="Bloc/Cubit state management"
    ),
    "provider": RuleCoverage(
        rule_file="state_management_rules.dart",
        rule_count=15,
        example_rules=["require_provider_dispose", "avoid_provider_of_in_build"],
        description="Provider disposal and usage"
    ),
    "riverpod": RuleCoverage(
        rule_file="riverpod_rules.dart",
        rule_count=13,
        example_rules=["avoid_ref_read_inside_build", "avoid_ref_watch_outside_build"],
        description="Riverpod ref usage"
    ),
    "get": RuleCoverage(
        rule_file="getx_rules.dart",
        rule_count=8,
        example_rules=["require_getx_controller_dispose", "avoid_obs_outside_controller"],
        description="GetX controller disposal"
    ),

    # Networking
    "dio": RuleCoverage(
        rule_file="api_network_rules.dart",
        rule_count=26,
        example_rules=["require_dio_timeout", "require_dio_error_handling", "require_dio_ssl_pinning"],
        description="Dio configuration and security"
    ),
    "http": RuleCoverage(
        rule_file="api_network_rules.dart",
        rule_count=10,
        example_rules=["require_http_status_check", "require_api_timeout"],
        description="HTTP patterns and retry logic"
    ),

    # Navigation
    "go_router": RuleCoverage(
        rule_file="navigation_rules.dart",
        rule_count=10,
        example_rules=["require_go_router_error_handler", "avoid_go_router_string_paths"],
        description="GoRouter error handling"
    ),

    # Images
    "cached_network_image": RuleCoverage(
        rule_file="image_rules.dart",
        rule_count=3,
        example_rules=["require_cached_image_dimensions", "require_cached_image_placeholder"],
        description="Cached image parameters"
    ),
    "image_picker": RuleCoverage(
        rule_file="image_rules.dart",
        rule_count=4,
        example_rules=["require_image_error_fallback", "require_exif_handling"],
        description="Image loading and errors"
    ),

    # Animation
    "flutter_animate": RuleCoverage(
        rule_file="animation_rules.dart",
        rule_count=14,
        example_rules=["require_vsync_mixin", "require_animation_controller_dispose"],
        description="Animation controller lifecycle"
    ),
    "lottie": RuleCoverage(
        rule_file="animation_rules.dart",
        rule_count=3,
        example_rules=["require_animation_controller_dispose"],
        description="Animation resource management"
    ),

    # Location
    "geolocator": RuleCoverage(
        rule_file="bluetooth_hardware_rules.dart",
        rule_count=4,
        example_rules=["require_geolocator_permission_check", "require_geolocator_stream_cancel"],
        description="Geolocator permission and streams"
    ),
    "location": RuleCoverage(
        rule_file="bluetooth_hardware_rules.dart",
        rule_count=4,
        example_rules=["require_geolocator_permission_check"],
        description="Location permission"
    ),

    # Security
    "flutter_secure_storage": RuleCoverage(
        rule_file="security_rules.dart",
        rule_count=25,
        example_rules=["require_secure_storage", "avoid_shared_prefs_sensitive_data"],
        description="Secure storage"
    ),
    "local_auth": RuleCoverage(
        rule_file="security_rules.dart",
        rule_count=5,
        example_rules=["require_auth_check", "require_logout_cleanup"],
        description="Local authentication"
    ),
    "crypto": RuleCoverage(
        rule_file="security_rules.dart",
        rule_count=3,
        example_rules=["prefer_secure_random_for_crypto"],
        description="Cryptography"
    ),

    # Notifications
    "awesome_notifications": RuleCoverage(
        rule_file="notification_rules.dart",
        rule_count=2,
        example_rules=["require_notification_channel_android"],
        description="Notification channels"
    ),

    # Maps
    "google_maps_flutter": RuleCoverage(
        rule_file="firebase_rules.dart",
        rule_count=2,
        example_rules=["avoid_map_markers_in_build"],
        description="Maps marker management"
    ),

    # Utilities
    "equatable": RuleCoverage(
        rule_file="equatable_rules.dart",
        rule_count=3,
        example_rules=["extend_equatable", "list_all_equatable_fields"],
        description="Equatable patterns"
    ),
    "shared_preferences": RuleCoverage(
        rule_file="firebase_rules.dart",
        rule_count=4,
        example_rules=["avoid_shared_prefs_sensitive_data"],
        description="SharedPreferences security"
    ),
}

# =============================================================================
# PACKAGE TO TECHNOLOGY MAPPING
# =============================================================================

PACKAGE_TO_TECHNOLOGY: dict[str, str] = {
    # Database - Isar
    "isar": "isar", "isar_flutter_libs": "isar", "isar_community": "isar",
    "isar_community_flutter_libs": "isar", "isar_generator": "isar", "isar_community_generator": "isar",
    # Database - Hive
    "hive": "hive", "hive_flutter": "hive", "hive_generator": "hive",
    # Database - SQLite
    "sqflite": "sqflite", "sqflite_common": "sqflite", "drift": "sqflite",
    # Firebase
    "cloud_firestore": "firebase_firestore", "firebase_database": "firebase_firestore",
    "firebase_core": "firebase_core", "firebase_analytics": "firebase_analytics",
    "firebase_crashlytics": "firebase_crashlytics", "firebase_messaging": "firebase_messaging",
    "firebase_auth": "firebase_core", "firebase_storage": "firebase_core",
    "firebase_app_check": "firebase_core",
    # State Management
    "flutter_bloc": "flutter_bloc", "bloc": "flutter_bloc",
    "provider": "provider", "riverpod": "riverpod", "flutter_riverpod": "riverpod",
    "get": "get", "get_it": "get",
    # Networking
    "dio": "dio", "http": "http", "chopper": "http", "retrofit": "http",
    "connectivity_plus": "http", "network_info_plus": "http",
    # Navigation
    "go_router": "go_router", "auto_route": "go_router",
    # Images
    "cached_network_image": "cached_network_image", "cached_network_svg_image": "cached_network_image",
    "image_picker": "image_picker", "image": "image_picker",
    # Animation
    "flutter_animate": "flutter_animate", "lottie": "lottie", "flutter_spinkit": "flutter_animate",
    # Location
    "geolocator": "geolocator", "location": "location", "geocoding": "geolocator", "latlong2": "geolocator",
    # Security
    "flutter_secure_storage": "flutter_secure_storage", "local_auth": "local_auth",
    "crypto": "crypto", "encrypter_plus": "crypto", "x25519": "crypto",
    # Notifications
    "awesome_notifications": "awesome_notifications", "awesome_notifications_core": "awesome_notifications",
    # Maps
    "google_maps_flutter": "google_maps_flutter", "flutter_map": "google_maps_flutter",
    # Utilities
    "equatable": "equatable", "shared_preferences": "shared_preferences",
    "path_provider": "shared_preferences", "permission_handler": "geolocator",
}

# =============================================================================
# RULES TO CREATE IN SAROPA_LINTS
# These are suggestions for NEW rules that don't exist yet
# =============================================================================

RULES_TO_CREATE: dict[str, list[SuggestedRule]] = {
    # ==========================================================================
    # AUTHENTICATION - HIGH PRIORITY
    # ==========================================================================
    "google_sign_in": [
        SuggestedRule("require_google_signin_error_handling", "Ensure GoogleSignIn.signIn() has try-catch for PlatformException", "warning", "error_handling"),
        SuggestedRule("require_google_signin_disconnect_on_logout", "Call GoogleSignIn.disconnect() on logout", "warning", "lifecycle"),
        SuggestedRule("avoid_google_signin_silent_without_fallback", "signInSilently() should have fallback", "info", "ux"),
    ],
    "sign_in_with_apple": [
        SuggestedRule("require_apple_signin_nonce", "Use secure random nonce to prevent replay attacks", "error", "security"),
        SuggestedRule("require_apple_credential_state_check", "Check getCredentialState() before assuming signed in", "warning", "lifecycle"),
        SuggestedRule("avoid_storing_apple_identity_token", "Don't store identity tokens locally", "error", "security"),
    ],
    "supabase_flutter": [
        SuggestedRule("require_supabase_error_handling", "Wrap Supabase calls in try-catch", "warning", "error_handling"),
        SuggestedRule("avoid_supabase_anon_key_in_code", "Don't hardcode Supabase anon key", "error", "security"),
        SuggestedRule("require_supabase_auth_state_listener", "Listen to onAuthStateChange", "warning", "lifecycle"),
        SuggestedRule("require_supabase_realtime_unsubscribe", "Unsubscribe from realtime on dispose", "error", "lifecycle"),
    ],

    # ==========================================================================
    # WEBVIEW - HIGH PRIORITY (Security)
    # ==========================================================================
    "webview_flutter": [
        SuggestedRule("require_webview_navigation_delegate", "Set navigationDelegate to control URL loading", "warning", "security"),
        SuggestedRule("require_webview_ssl_error_handling", "Handle SSL errors explicitly", "error", "security"),
        SuggestedRule("require_webview_clear_on_logout", "Clear WebView cache/cookies on logout", "warning", "security"),
        SuggestedRule("avoid_webview_file_access", "Disable file:// access unless required", "warning", "security"),
    ],

    # ==========================================================================
    # BACKGROUND PROCESSING
    # ==========================================================================
    "workmanager": [
        SuggestedRule("require_workmanager_constraints", "Specify NetworkType/battery constraints", "warning", "performance"),
        SuggestedRule("require_workmanager_unique_name", "Use unique names to prevent duplicates", "warning", "correctness"),
        SuggestedRule("require_workmanager_error_handling", "Handle task failures with retry", "warning", "error_handling"),
        SuggestedRule("require_workmanager_result_return", "Always return Result.success/failure/retry", "error", "correctness"),
    ],

    # ==========================================================================
    # CONTACTS & CALENDAR
    # ==========================================================================
    "flutter_contacts": [
        SuggestedRule("require_contacts_permission_check", "Request permission before accessing", "error", "permission"),
        SuggestedRule("require_contacts_error_handling", "Handle permission denied gracefully", "warning", "error_handling"),
        SuggestedRule("avoid_contacts_full_fetch", "Use withProperties for needed fields only", "info", "performance"),
    ],
    "device_calendar": [
        SuggestedRule("require_calendar_permission_check", "Request permission before accessing", "error", "permission"),
        SuggestedRule("require_calendar_timezone_handling", "Handle timezone explicitly", "warning", "correctness"),
    ],

    # ==========================================================================
    # FILE HANDLING
    # ==========================================================================
    "file_picker": [
        SuggestedRule("require_file_picker_permission_check", "Check storage permission first", "warning", "permission"),
        SuggestedRule("require_file_picker_type_validation", "Validate file type after picking", "warning", "security"),
        SuggestedRule("require_file_picker_size_check", "Check file size to prevent OOM", "warning", "performance"),
    ],

    # ==========================================================================
    # SPEECH & INPUT
    # ==========================================================================
    "speech_to_text": [
        SuggestedRule("require_speech_permission_check", "Check microphone permission", "error", "permission"),
        SuggestedRule("require_speech_stop_on_dispose", "Call stop() in dispose", "error", "lifecycle"),
        SuggestedRule("require_speech_availability_check", "Check isAvailable first", "warning", "platform"),
    ],

    # ==========================================================================
    # URL & DEEP LINKS
    # ==========================================================================
    "url_launcher": [
        SuggestedRule("require_url_launcher_can_launch_check", "Call canLaunchUrl before launchUrl", "warning", "error_handling"),
        SuggestedRule("avoid_url_launcher_untrusted_urls", "Validate URLs before launching", "warning", "security"),
    ],
    "app_links": [
        SuggestedRule("require_app_links_validation", "Validate deep link parameters", "warning", "security"),
        SuggestedRule("avoid_app_links_sensitive_params", "Don't pass tokens in URLs", "error", "security"),
    ],

    # ==========================================================================
    # IN-APP FEATURES
    # ==========================================================================
    "in_app_purchase": [
        SuggestedRule("require_iap_error_handling", "Handle all PurchaseStatus cases", "error", "error_handling"),
        SuggestedRule("require_iap_verification", "Verify purchases server-side", "error", "security"),
        SuggestedRule("require_iap_restore_handling", "Implement purchase restoration", "error", "platform"),
    ],
    "in_app_review": [
        SuggestedRule("avoid_in_app_review_on_first_launch", "Don't request on first launch", "warning", "ux"),
        SuggestedRule("require_in_app_review_availability_check", "Check isAvailable first", "warning", "error_handling"),
    ],

    # ==========================================================================
    # ENVIRONMENT & SECRETS
    # ==========================================================================
    "envied": [
        SuggestedRule("avoid_envied_secrets_in_repo", "Ensure .env files are gitignored", "error", "security"),
        SuggestedRule("require_envied_obfuscation", "Use obfuscate: true for secrets", "warning", "security"),
    ],
    "chat_gpt_sdk": [
        SuggestedRule("avoid_openai_key_in_code", "Don't hardcode API key", "error", "security"),
        SuggestedRule("require_openai_error_handling", "Handle rate limits and errors", "warning", "error_handling"),
    ],

    # ==========================================================================
    # UI COMPONENTS
    # ==========================================================================
    "flutter_svg": [
        SuggestedRule("require_svg_error_handler", "Provide errorBuilder", "warning", "error_handling"),
    ],
    "google_fonts": [
        SuggestedRule("require_google_fonts_fallback", "Specify fontFamilyFallback", "warning", "ux"),
    ],
    "flutter_keyboard_visibility": [
        SuggestedRule("require_keyboard_visibility_dispose", "Dispose subscription", "warning", "lifecycle"),
    ],

    # ==========================================================================
    # DATE/TIME
    # ==========================================================================
    "intl": [
        SuggestedRule("require_intl_locale_initialization", "Initialize default locale on start", "warning", "i18n"),
    ],
    "timezone": [
        SuggestedRule("require_timezone_initialization", "Call initializeTimeZones() first", "error", "correctness"),
    ],

    # ==========================================================================
    # UTILITIES
    # ==========================================================================
    "uuid": [
        SuggestedRule("prefer_uuid_v4", "UUIDv4 for random IDs; v1 leaks MAC", "info", "security"),
    ],
    "zxcvbn": [
        SuggestedRule("require_password_strength_threshold", "Enforce minimum score 3+", "warning", "security"),
    ],
    "flutter_cache_manager": [
        SuggestedRule("require_cache_manager_clear_on_logout", "Clear cache on logout", "warning", "security"),
    ],
    "logging": [
        SuggestedRule("avoid_logging_sensitive_data", "Don't log PII or tokens", "error", "security"),
    ],
}

# Category-based fallback rules
DEFAULT_RULES_BY_CATEGORY: dict[str, list[SuggestedRule]] = {
    "Authentication": [
        SuggestedRule("require_{pkg}_error_handling", "Handle auth errors", "warning", "error_handling"),
        SuggestedRule("require_{pkg}_logout_cleanup", "Cleanup on logout", "warning", "security"),
    ],
    "Database": [
        SuggestedRule("require_{pkg}_error_handling", "Handle database errors", "warning", "error_handling"),
        SuggestedRule("require_{pkg}_close", "Close connections", "warning", "lifecycle"),
    ],
    "Device & Platform": [
        SuggestedRule("require_{pkg}_permission_check", "Check permissions", "warning", "permission"),
        SuggestedRule("require_{pkg}_error_handling", "Handle errors", "warning", "error_handling"),
    ],
    "Contacts & Calendar": [
        SuggestedRule("require_{pkg}_permission_check", "Check permission", "error", "permission"),
        SuggestedRule("require_{pkg}_error_handling", "Handle errors", "warning", "error_handling"),
    ],
    "Location & Maps": [
        SuggestedRule("require_{pkg}_permission_check", "Check location permission", "error", "permission"),
    ],
}

# =============================================================================
# CATEGORIES
# =============================================================================
# cspell:ignore beamer
CATEGORIES: dict[str, list[str]] = {
    "Database": ["isar", "hive", "sqflite", "drift", "objectbox"],
    "Firebase": ["firebase_core", "firebase_analytics", "firebase_crashlytics", "firebase_messaging",
                 "firebase_auth", "firebase_storage", "cloud_firestore"],
    "State Management": ["flutter_bloc", "bloc", "provider", "riverpod", "get", "get_it"],
    "Networking": ["dio", "http", "chopper", "connectivity_plus", "network_info_plus"],
    "Navigation": ["go_router", "auto_route", "beamer"],
    "Authentication": ["google_sign_in", "sign_in_with_apple", "firebase_auth", "supabase_flutter"],
    "Images & Media": ["cached_network_image", "image_picker", "flutter_svg", "video_player", "audioplayers"],
    "Animation": ["flutter_animate", "lottie", "rive", "flutter_spinkit"],
    "Location & Maps": ["geolocator", "location", "geocoding", "google_maps_flutter", "flutter_map"],
    "Forms & Input": ["flutter_form_builder", "flutter_keyboard_visibility", "speech_to_text"],
    "Notifications": ["awesome_notifications", "flutter_local_notifications"],
    "Security & Storage": ["flutter_secure_storage", "shared_preferences", "crypto"],
    "Device & Platform": ["device_info_plus", "package_info_plus", "permission_handler", "url_launcher"],
    "Background Processing": ["workmanager", "background_fetch"],
    "In-App Features": ["in_app_purchase", "in_app_review", "webview_flutter"],
    "Contacts & Calendar": ["flutter_contacts", "device_calendar"],
    "Utilities": ["intl", "uuid", "path", "equatable"],
}


def get_category(package_name: str) -> str:
    """Determine the category for a package."""
    for category, packages in CATEGORIES.items():
        if package_name in packages:
            return category

    name_lower = package_name.lower()
    if "firebase" in name_lower:
        return "Firebase"
    if "bloc" in name_lower or "provider" in name_lower:
        return "State Management"
    if "image" in name_lower or "video" in name_lower or "audio" in name_lower:
        return "Images & Media"
    if "auth" in name_lower or "sign" in name_lower:
        return "Authentication"
    if "map" in name_lower or "geo" in name_lower or "location" in name_lower:
        return "Location & Maps"

    return "Other"


def get_rules_to_create(package_name: str, category: str) -> list[SuggestedRule]:
    """Get rules that should be CREATED in saropa_lints for this package."""
    if package_name in RULES_TO_CREATE:
        return RULES_TO_CREATE[package_name]

    if category in DEFAULT_RULES_BY_CATEGORY:
        pkg_short = package_name.replace("flutter_", "").replace("_plus", "")
        return [
            SuggestedRule(
                name=r.name.replace("{pkg}", pkg_short),
                description=r.description,
                severity=r.severity,
                category=r.category
            )
            for r in DEFAULT_RULES_BY_CATEGORY[category]
        ]

    return []


def get_relevant_rules(packages: list[str]) -> dict[str, list[RelevantRule]]:
    """Get existing saropa_lints rules relevant to the given packages."""
    result: dict[str, list[RelevantRule]] = {}
    for pkg in packages:
        if pkg in PACKAGE_TO_RELEVANT_RULES:
            rules = PACKAGE_TO_RELEVANT_RULES[pkg]
            if rules:  # Skip empty lists
                result[pkg] = rules
    return result


def recommend_tier(packages: list[str]) -> tuple[str, list[RelevantRule]]:
    """
    Recommend a tier and list rules that require upgrading beyond that tier.

    Returns:
        tuple: (recommended_tier, rules_requiring_override)
    """
    all_rules: list[RelevantRule] = []
    for pkg in packages:
        if pkg in PACKAGE_TO_RELEVANT_RULES:
            all_rules.extend(PACKAGE_TO_RELEVANT_RULES[pkg])

    if not all_rules:
        # No package-specific rules found, recommend recommended tier as default
        return "recommended", []

    # Find the minimum tier that covers most rules
    tier_rule_counts = {tier: 0 for tier in TIER_ORDER}
    for rule in all_rules:
        tier_idx = TIER_ORDER.index(rule.tier)
        # Rules in lower tiers are included in higher tiers
        for i in range(tier_idx, len(TIER_ORDER)):
            tier_rule_counts[TIER_ORDER[i]] += 1

    # Find the tier with the best coverage that isn't too high
    # Prefer "recommended" as baseline unless essential has everything needed
    best_tier = "recommended"

    # Check if essential covers all package-specific rules
    essential_rules = [r for r in all_rules if r.tier == "essential"]
    recommended_rules = [r for r in all_rules if r.tier in ["essential", "recommended"]]

    if len(essential_rules) == len(all_rules):
        best_tier = "essential"
    elif len(recommended_rules) == len(all_rules):
        best_tier = "recommended"
    else:
        # Some rules need professional or higher - recommend professional
        professional_rules = [r for r in all_rules if r.tier in ["essential", "recommended", "professional"]]
        if len(professional_rules) == len(all_rules):
            best_tier = "professional"
        else:
            best_tier = "comprehensive"

    # Find rules that are above the recommended tier (need individual override)
    tier_idx = TIER_ORDER.index(best_tier)
    rules_requiring_override = [
        r for r in all_rules
        if TIER_ORDER.index(r.tier) > tier_idx
    ]

    # Remove duplicates
    seen = set()
    unique_overrides = []
    for r in rules_requiring_override:
        if r.name not in seen:
            seen.add(r.name)
            unique_overrides.append(r)

    return best_tier, unique_overrides


# =============================================================================
# ANALYSIS
# =============================================================================

def parse_pubspec(file_path: str) -> dict:
    """Parse a pubspec.yaml file."""
    path = Path(file_path)
    if not path.exists():
        exit_with_error(f"File not found: {file_path}", ExitCode.FILE_NOT_FOUND)

    try:
        with open(path, 'r', encoding='utf-8') as f:
            return yaml.safe_load(f)
    except yaml.YAMLError as e:
        exit_with_error(f"YAML parse error: {e}", ExitCode.PARSE_ERROR)


def extract_dependencies(pubspec: dict) -> tuple[list[str], list[str], list[str]]:
    """Extract dependencies from pubspec."""
    dependencies = []
    dev_dependencies = []
    overrides = []

    if 'dependencies' in pubspec and pubspec['dependencies']:
        for dep in pubspec['dependencies'].keys():
            if dep not in ['flutter', 'flutter_localizations']:
                dependencies.append(dep)

    if 'dev_dependencies' in pubspec and pubspec['dev_dependencies']:
        for dep in pubspec['dev_dependencies'].keys():
            if dep not in ['flutter_test']:
                dev_dependencies.append(dep)

    if 'dependency_overrides' in pubspec and pubspec['dependency_overrides']:
        for dep in pubspec['dependency_overrides'].keys():
            overrides.append(dep)

    return dependencies, dev_dependencies, overrides


def analyze_package(package_name: str) -> PackageAnalysis:
    """Analyze a single package for saropa_lints coverage."""
    category = get_category(package_name)
    technology = PACKAGE_TO_TECHNOLOGY.get(package_name)

    if technology and technology in SAROPA_LINTS_COVERAGE:
        coverage = SAROPA_LINTS_COVERAGE[technology]
        return PackageAnalysis(
            name=package_name,
            category=category,
            has_coverage=True,
            coverage=coverage,
            notes=f"Covered by {coverage.rule_file}"
        )

    return PackageAnalysis(
        name=package_name,
        category=category,
        has_coverage=False,
        notes="Needs rules in saropa_lints"
    )


# =============================================================================
# REPORT GENERATION
# =============================================================================

def generate_report(
    pubspec: dict,
    dependencies: list[str],
    dev_dependencies: list[str],
    overrides: list[str]
) -> None:
    """Generate and print the analysis report."""
    project_name = pubspec.get('name', 'Unknown Project')

    # Analyze all packages (including overrides)
    all_packages = set(dependencies + dev_dependencies + overrides)
    analyses = [analyze_package(pkg) for pkg in sorted(all_packages)]

    covered = [a for a in analyses if a.has_coverage]
    uncovered = [a for a in analyses if not a.has_coverage]

    all_pkg_list = list(all_packages)
    recommended_tier, override_rules = recommend_tier(all_pkg_list)
    relevant_rules = get_relevant_rules(all_pkg_list)

    # Get tier info
    tier_desc = TIER_DESCRIPTIONS[recommended_tier]
    tier_count = TIER_RULE_COUNTS[recommended_tier]

    # ==========================================================================
    # COMPACT OUTPUT
    # ==========================================================================
    print()
    print(f"  Project: {project_name}")
    print(f"  Packages: {len(analyses)} total, {len(covered)} with lint rules, {len(uncovered)} without")
    print()

    # The key actionable item
    print(f"  Recommended: {recommended_tier} tier (~{tier_count} / {TOTAL_RULES} rules)")
    print_colored(f"  {tier_desc}", Color.DIM)
    print()
    print_colored(f"      include: package:saropa_lints/tiers/{recommended_tier}.yaml", Color.GREEN)
    print()

    # Show override rules if any (compact)
    if override_rules:
        override_names = ", ".join(r.name for r in override_rules)
        print_colored(f"  Optional overrides: {override_names}", Color.DIM)
        print()

    # Show covered packages with rules (compact - one line per package)
    if relevant_rules:
        print(f"  Package-specific rules ({len(relevant_rules)} packages):")
        for pkg, rules in sorted(relevant_rules.items()):
            included_rules = [r for r in rules if TIER_ORDER.index(r.tier) <= TIER_ORDER.index(recommended_tier)]
            if included_rules:
                rule_names = ", ".join(r.name for r in included_rules)
                print(f"      {pkg}: {Color.DIM.value}{rule_names}{Color.RESET.value}")
        print()

    # Uncovered packages (very compact)
    if uncovered:
        print_colored(f"  No rules yet: {len(uncovered)} packages (see JSON for details)", Color.DIM)
        print()


def generate_json_report(
    pubspec: dict,
    dependencies: list[str],
    dev_dependencies: list[str],
    overrides: list[str],
    pubspec_path: Path
) -> dict:
    """Generate JSON report."""
    project_name = pubspec.get('name', 'Unknown Project')
    all_packages = set(dependencies + dev_dependencies + overrides)
    analyses = [analyze_package(pkg) for pkg in sorted(all_packages)]

    covered = [a for a in analyses if a.has_coverage]
    uncovered = [a for a in analyses if not a.has_coverage]

    rules_to_create = {}
    for a in uncovered:
        rules = get_rules_to_create(a.name, a.category)
        if rules:
            rules_to_create[a.name] = {
                "category": a.category,
                "rules": [{"name": r.name, "description": r.description, "severity": r.severity, "type": r.category} for r in rules]
            }

    total = sum(len(v["rules"]) for v in rules_to_create.values())

    # Get tier recommendation
    all_pkg_list = list(all_packages)
    recommended_tier, override_rules = recommend_tier(all_pkg_list)
    relevant_rules = get_relevant_rules(all_pkg_list)

    return {
        "generated_at": datetime.now().isoformat(),
        "input_file": str(pubspec_path.resolve()),
        "project_name": project_name,
        "summary": {
            "total_packages": len(analyses),
            "covered_packages": len(covered),
            "packages_needing_rules": len(uncovered),
            "total_rules_to_create": total
        },
        "recommendation": {
            "tier": recommended_tier,
            "tier_description": TIER_DESCRIPTIONS[recommended_tier],
            "include_line": f"include: package:saropa_lints/tiers/{recommended_tier}.yaml",
            "override_rules": [{"name": r.name, "tier": r.tier, "description": r.description} for r in override_rules],
            "relevant_rules_by_package": {
                pkg: [{"name": r.name, "tier": r.tier, "description": r.description} for r in rules]
                for pkg, rules in relevant_rules.items()
            }
        },
        "covered_packages": [{"name": a.name, "category": a.category, "rule_file": a.coverage.rule_file if a.coverage else None} for a in covered],
        "rules_to_create": rules_to_create,
        "dependency_overrides": overrides
    }


def save_json_report(report: dict, pubspec_path: Path) -> Path:
    """Save JSON report with datetime-prefixed filename."""
    project_name = report.get("project_name", "unknown")
    # Sanitize project name for filename
    safe_name = "".join(c if c.isalnum() or c in "-_" else "_" for c in project_name)

    timestamp = datetime.now().strftime("%Y-%m-%d_%H%M%S")
    filename = f"{timestamp}_{safe_name}_analysis.json"

    output_path = pubspec_path.parent / filename

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(report, f, indent=2)

    return output_path


# =============================================================================
# MAIN
# =============================================================================

def main() -> int:
    """Main entry point."""
    enable_ansi_support()
    show_saropa_logo()
    print_colored(f"  Saropa Lints Pubspec Analyzer v{SCRIPT_VERSION}", Color.MAGENTA)
    print()

    # Get pubspec path - either from args or prompt
    if len(sys.argv) >= 2:
        pubspec_path = sys.argv[1]
    else:
        pubspec_path = prompt_for_file()

    # Validate file exists
    pubspec_file = Path(pubspec_path)
    if not pubspec_file.exists():
        exit_with_error(f"File not found: {pubspec_path}", ExitCode.FILE_NOT_FOUND)

    # Show full command for easy re-run
    script_path = Path(__file__).resolve()
    pubspec_file_resolved = pubspec_file.resolve()
    print_info(f"Analyzing: {pubspec_file_resolved}")
    print()
    print_colored("  Re-run command:", Color.DIM)
    print_colored(f"      python {script_path} {pubspec_file_resolved}", Color.DIM)
    print()

    pubspec = parse_pubspec(pubspec_path)
    dependencies, dev_dependencies, overrides = extract_dependencies(pubspec)

    if not dependencies and not dev_dependencies:
        exit_with_error("No dependencies found in pubspec", ExitCode.NO_DEPENDENCIES)

    # Generate and display colored report
    generate_report(pubspec, dependencies, dev_dependencies, overrides)

    # Generate and save JSON report
    json_report = generate_json_report(pubspec, dependencies, dev_dependencies, overrides, pubspec_file)
    output_path = save_json_report(json_report, pubspec_file)

    print(f"  JSON saved: {output_path}")
    print()

    return ExitCode.SUCCESS.value


if __name__ == "__main__":
    sys.exit(main())
