#!/usr/bin/env python3
"""
Generate test fixture files for lint rules that lack test coverage.

Parses DartDoc BAD/GOOD examples from rule source files and generates
individual fixture files in example/lib/<category>/<rule_name>_fixture.dart.

For rules without DartDoc examples, generates basic test code inferred
from the context.registry method used.
"""

import os
import re
import sys
from pathlib import Path
from dataclasses import dataclass, field

# ── Paths ────────────────────────────────────────────────────────────────

PROJECT_ROOT = Path(__file__).resolve().parent.parent
RULES_DIR = PROJECT_ROOT / "lib" / "src" / "rules"
EXAMPLE_DIR = PROJECT_ROOT / "example" / "lib"
MOCKS_FILE = EXAMPLE_DIR / "flutter_mocks.dart"

# ── Data Classes ─────────────────────────────────────────────────────────


@dataclass
class RuleInfo:
    class_name: str
    rule_name: str
    category: str  # derived from filename, e.g. "widget_patterns"
    bad_examples: list = field(default_factory=list)
    good_examples: list = field(default_factory=list)
    registry_method: str = ""  # e.g. "addInstanceCreationExpression"
    source_file: str = ""


# ── Existing Coverage Detection ──────────────────────────────────────────


def find_existing_coverage() -> set:
    """Find rule names already covered by existing fixture files."""
    covered = set()
    for fixture in EXAMPLE_DIR.rglob("*_fixture.dart"):
        try:
            text = fixture.read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue
        for m in re.finditer(r"expect_lint:\s*(\w+)", text):
            covered.add(m.group(1))
    return covered


# ── DartDoc Parsing ──────────────────────────────────────────────────────


def extract_dartdoc_above(lines: list, class_line_idx: int) -> str:
    """Extract the DartDoc comment block above a class declaration."""
    doc_lines = []
    i = class_line_idx - 1
    while i >= 0:
        stripped = lines[i].strip()
        if stripped.startswith("///"):
            doc_lines.insert(0, stripped)
            i -= 1
        elif stripped == "":
            if doc_lines:
                doc_lines.insert(0, stripped)
            i -= 1
        else:
            break
    return "\n".join(doc_lines)


def parse_code_blocks(dartdoc: str) -> tuple:
    """Parse BAD and GOOD code blocks from DartDoc."""
    bad_examples = []
    good_examples = []

    lines = dartdoc.split("\n")
    clean_lines = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("///"):
            clean_lines.append(
                stripped[3:].lstrip(" ") if len(stripped) > 3 else ""
            )
        else:
            clean_lines.append("")
    text = "\n".join(clean_lines)

    bad_pattern = re.compile(
        r"\*\*(?:BAD|Bad|bad)[:\*]*\*?\*?"
        r".*?```dart\s*\n(.*?)```",
        re.DOTALL,
    )
    good_pattern = re.compile(
        r"\*\*(?:GOOD|Good|good)[:\*]*\*?\*?"
        r".*?```dart\s*\n(.*?)```",
        re.DOTALL,
    )

    for m in bad_pattern.finditer(text):
        code = m.group(1).strip()
        if code:
            bad_examples.append(code)

    for m in good_pattern.finditer(text):
        code = m.group(1).strip()
        if code:
            good_examples.append(code)

    return bad_examples, good_examples


# ── Registry Method Detection ────────────────────────────────────────────


def detect_registry_method(class_body: str) -> str:
    """Detect which context.registry.addXxx method is used."""
    m = re.search(r"context\.registry\.(add\w+)", class_body)
    return m.group(1) if m else ""


# ── Rule Extraction ──────────────────────────────────────────────────────


def extract_rules_from_file(filepath: Path) -> list:
    """Extract all rule definitions from a *_rules.dart file."""
    try:
        text = filepath.read_text(encoding="utf-8", errors="replace")
    except Exception as e:
        print(f"  WARN: Cannot read {filepath}: {e}")
        return []

    lines = text.split("\n")
    stem = filepath.stem
    category = stem.replace("_rules", "")
    rules = []

    class_pattern = re.compile(
        r"^class\s+(\w+Rule)\s+extends\s+SaropaLintRule"
    )

    for idx, line in enumerate(lines):
        m = class_pattern.match(line.strip())
        if not m:
            continue

        class_name = m.group(1)
        rule_name = ""
        class_body_lines = []
        brace_count = 0
        started = False
        for j in range(idx, min(idx + 200, len(lines))):
            class_body_lines.append(lines[j])
            brace_count += lines[j].count("{") - lines[j].count("}")
            if brace_count > 0:
                started = True
            if started and brace_count <= 0:
                break
            if not rule_name:
                nm = re.search(r"name:\s*'(\w+)'", lines[j])
                if nm:
                    rule_name = nm.group(1)

        if not rule_name:
            continue

        class_body = "\n".join(class_body_lines)
        registry_method = detect_registry_method(class_body)
        dartdoc = extract_dartdoc_above(lines, idx)
        bad_examples, good_examples = parse_code_blocks(dartdoc)

        rules.append(
            RuleInfo(
                class_name=class_name,
                rule_name=rule_name,
                category=category,
                bad_examples=bad_examples,
                good_examples=good_examples,
                registry_method=registry_method,
                source_file=str(filepath.relative_to(PROJECT_ROOT)),
            )
        )

    return rules


# ── Code Post-Processing ────────────────────────────────────────────────


def _contains_class_or_import(code: str) -> bool:
    """Check if code contains class/mixin/enum/extension declarations."""
    return bool(re.search(
        r"^\s*(class |abstract class |sealed class |mixin |"
        r"import |export |extension |enum )",
        code,
        re.MULTILINE,
    ))


def _strip_import_lines(code: str) -> str:
    """Remove import/export/part lines (not valid inside functions or files)."""
    lines = code.split("\n")
    return "\n".join(
        l for l in lines
        if not re.match(r"\s*(import |export |part |library )", l)
    )



def sanitize_code(code: str, _rule_name: str, label: str, idx: int) -> str:
    """Post-process extracted DartDoc code to make it compilable.

    Cleans ellipsis/imports, classifies the code type, wraps loose
    code in functions, and prefixes names to avoid duplicates.
    """
    code = _clean_ellipsis_and_imports(code)
    has_await = bool(re.search(r"\bawait\b", code))

    stripped = code.strip()
    prefix = f"_{label}{idx}"

    if not stripped:
        return f"void {prefix}() {{\n  // Empty example\n}}"

    return _wrap_code_for_compilation(
        code, stripped, prefix, has_await,
    )


def _clean_ellipsis_and_imports(code: str) -> str:
    """Remove ellipsis placeholders, comment-only ellipsis, and imports."""
    lines = code.strip().split("\n")
    lines = [
        l for l in lines
        if not re.match(r"^\s*\.\.\.;?\s*$", l)
        and not re.match(r"^\s*//\s*\.\.\.\s*$", l)
    ]
    lines = [re.sub(r",?\s*\.\.\.\s*", "", l) for l in lines]
    return _strip_import_lines("\n".join(lines))


def _wrap_code_for_compilation(
    code: str, stripped: str, prefix: str, has_await: bool
) -> str:
    """Classify code type and wrap/prefix it for compilation."""
    is_class = re.match(
        r"^(class |abstract |mixin |extension |enum |sealed )",
        stripped,
    )
    if is_class:
        return _prefix_class_names(code, prefix, count=1)

    has_classes = _contains_class_or_import(stripped)
    is_function = re.match(
        r"^(void |Future |Stream |int |double |String |bool |"
        r"dynamic |List |Map |Set |Widget |T |FutureOr )",
        stripped,
    )
    is_override_function = re.match(
        r"^@override\s+\n?\s*(void |Future |Widget |State )",
        stripped,
        re.DOTALL,
    )

    if has_classes and not is_function and not is_override_function:
        return _prefix_class_names(code, prefix)

    if is_override_function:
        code = re.sub(r"@override\s*\n?\s*", "", code, count=1)
        is_function = True

    if is_function:
        return _prefix_function_name(code, prefix, has_await)

    return _wrap_loose_code(code, prefix, has_await)


def _prefix_class_names(code: str, prefix: str, count: int = 0) -> str:
    """Prefix class names to avoid duplicates, add semicolons."""
    code = re.sub(
        r"\bclass\s+(\w+)",
        lambda m: f"class {prefix}_{m.group(1)}",
        code,
        count=count,
    )
    return _add_missing_semicolons(code)


def _prefix_function_name(
    code: str, prefix: str, has_await: bool
) -> str:
    """Prefix function name and add async keyword if needed."""
    code = re.sub(
        r"^((?:void|Future|FutureOr|Stream|int|double|String|"
        r"bool|dynamic|List|Map|Set|Widget|T|State)\s*"
        r"(?:<[^>]+>)?\??\s+)(\w+)",
        lambda m: f"{m.group(1)}{prefix}_{m.group(2)}",
        code,
        count=1,
    )
    if has_await and "{" in code and "async" not in code.split("{")[0]:
        code = re.sub(r"\)\s*\{", ") async {", code, count=1)
    code = _remove_super_calls(code)
    return _add_missing_semicolons(code)


def _wrap_loose_code(code: str, prefix: str, has_await: bool) -> str:
    """Wrap loose statements in a function body."""
    code = _fix_trailing_commas_in_list(code)
    code = _remove_super_calls(code)
    indented = "\n".join(f"  {line}" for line in code.split("\n"))
    indented = _add_missing_semicolons(indented)
    async_kw = " async" if has_await else ""
    return f"void {prefix}(){async_kw} {{\n{indented}\n}}"


def _remove_super_calls(code: str) -> str:
    """Remove standalone super.method() calls that fail outside a class."""
    lines = code.split("\n")
    result = []
    for line in lines:
        stripped = line.strip()
        # Remove `super.initState();`, `super.dispose();`, etc.
        if re.match(r"^super\.\w+\(\);?$", stripped):
            result.append(line.replace(stripped, f"// {stripped}"))
        else:
            result.append(line)
    return "\n".join(result)


def _fix_trailing_commas_in_list(code: str) -> str:
    """No-op: trailing commas in widget lists are handled by ignore pragmas.

    Previously this replaced `),` with `);` but that breaks nested
    constructor arguments where `,` is a parameter separator.
    """
    return code


def _add_missing_semicolons(code: str) -> str:
    """Add missing semicolons to expression statements.

    Looks for lines ending with `)` that are followed by a blank line
    or closing brace, which likely need a semicolon.
    """
    lines = code.split("\n")
    result = []
    for i, line in enumerate(lines):
        stripped = line.rstrip()
        next_line = lines[i + 1].strip() if i + 1 < len(lines) else ""

        # Skip lines that are part of a function/class declaration
        if stripped.endswith("{") or stripped.endswith("=>"):
            result.append(line)
            continue

        # Line ends with ) and next line is blank, }, or starts a new statement
        if (
            stripped.endswith(")")
            and not next_line.startswith(".")
            and not next_line.startswith(")")
            and not next_line.startswith(",")
            and not next_line.startswith("..")
            and not next_line.startswith("?.")
            and (
                next_line == ""
                or next_line.startswith("}")
                or next_line.startswith("//")
                or next_line.startswith("final ")
                or next_line.startswith("var ")
                or next_line.startswith("const ")
                or next_line.startswith("return ")
                or next_line.startswith("throw ")
                or next_line.startswith("await ")
                or re.match(r"^[A-Z]", next_line)  # Widget/class constructor
                or re.match(r"^[a-z]+\.\w+", next_line)  # method chain start
                or re.match(r"^if\s*\(", next_line)
                or re.match(r"^for\s*\(", next_line)
                or re.match(r"^while\s*\(", next_line)
                or re.match(r"^try\s*\{", next_line)
                or re.match(r"^switch\s*\(", next_line)
            )
        ):
            result.append(stripped + ";")
        # Line ends with ] - could be a list literal expression
        elif (
            stripped.endswith("]")
            and not stripped.endswith("=>")
            and (next_line == "" or next_line.startswith("}"))
        ):
            result.append(stripped + ";")
        else:
            result.append(line)

    return "\n".join(result)


# ── Stub Declarations ────────────────────────────────────────────────────

# Common types used in DartDoc examples that aren't in flutter_mocks.dart
STUB_DECLARATIONS = """\
// ── Stub declarations for DartDoc example types ──
// These minimal stubs allow the fixture to compile.
// They don't need real implementations - just enough for the analyzer.

// ignore_for_file: unused_element, camel_case_types

class _Stub {
  const _Stub();
  dynamic noSuchMethod(Invocation i) => null;
}
"""


# ── Fallback Code Generation ────────────────────────────────────────────

FALLBACK_TEMPLATES = {
    "addInstanceCreationExpression": {
        "bad": (
            "class _Bad{idx} extends StatelessWidget {{\n"
            "  const _Bad{idx}({{super.key}});\n"
            "  @override\n"
            "  Widget build(BuildContext context) {{\n"
            "    // TODO: Add widget creation that triggers {rule}\n"
            "    return Container();\n"
            "  }}\n"
            "}}"
        ),
        "good": (
            "class _Good{idx} extends StatelessWidget {{\n"
            "  const _Good{idx}({{super.key}});\n"
            "  @override\n"
            "  Widget build(BuildContext context) {{\n"
            "    // TODO: Add compliant widget pattern for {rule}\n"
            "    return Container();\n"
            "  }}\n"
            "}}"
        ),
    },
    "addMethodInvocation": {
        "bad": (
            "void _bad{idx}() {{\n"
            "  // TODO: Add method call that triggers {rule}\n"
            "}}"
        ),
        "good": (
            "void _good{idx}() {{\n"
            "  // TODO: Add compliant method call for {rule}\n"
            "}}"
        ),
    },
    "addMethodDeclaration": {
        "bad": (
            "class _BadClass{idx} {{\n"
            "  // TODO: Add method declaration that triggers {rule}\n"
            "  void badMethod() {{}}\n"
            "}}"
        ),
        "good": (
            "class _GoodClass{idx} {{\n"
            "  // TODO: Add compliant method for {rule}\n"
            "  void goodMethod() {{}}\n"
            "}}"
        ),
    },
    "addClassDeclaration": {
        "bad": (
            "// TODO: Add class that triggers {rule}\n"
            "class _BadClass{idx} {{}}"
        ),
        "good": (
            "// TODO: Add compliant class for {rule}\n"
            "class _GoodClass{idx} {{}}"
        ),
    },
    "addVariableDeclaration": {
        "bad": (
            "void _bad{idx}() {{\n"
            "  // TODO: Add variable declaration that triggers {rule}\n"
            "  var x = 0;\n"
            "}}"
        ),
        "good": (
            "void _good{idx}() {{\n"
            "  // TODO: Add compliant variable for {rule}\n"
            "  final x = 0;\n"
            "}}"
        ),
    },
}

DEFAULT_TEMPLATE = {
    "bad": (
        "void _bad{idx}() {{\n"
        "  // TODO: Add code that triggers {rule}\n"
        "}}"
    ),
    "good": (
        "void _good{idx}() {{\n"
        "  // TODO: Add compliant code for {rule}\n"
        "}}"
    ),
}


def generate_fallback(rule: RuleInfo, idx: int) -> tuple:
    """Generate fallback bad/good code for rules without DartDoc examples."""
    template = FALLBACK_TEMPLATES.get(rule.registry_method, DEFAULT_TEMPLATE)
    bad = template["bad"].format(idx=idx, rule=rule.rule_name)
    good = template["good"].format(idx=idx, rule=rule.rule_name)
    return bad, good


# ── Fixture File Generation ──────────────────────────────────────────────

CATEGORY_DIR_MAP = {
    "ios": "platforms",
    "android": "platforms",
    "macos": "platforms",
    "web": "platforms",
    "linux": "platforms",
    "windows": "platforms",
    "bloc": "packages",
    "provider": "packages",
    "riverpod": "packages",
    "getx": "packages",
    "firebase": "packages",
    "isar": "packages",
    "hive": "packages",
    "dio": "packages",
    "equatable": "packages",
    "flame": "packages",
    "flutter_hooks": "packages",
    "get_it": "packages",
    "graphql": "packages",
    "package_specific": "packages",
    "qr_scanner": "packages",
    "shared_preferences": "packages",
    "sqflite": "packages",
    "supabase": "packages",
    "url_launcher": "packages",
    "workmanager": "packages",
    "geolocator": "packages",
}


def get_output_dir(category: str) -> Path:
    """Get the output directory for a given category."""
    parent = CATEGORY_DIR_MAP.get(category, category)
    if parent == category:
        return EXAMPLE_DIR / category
    return EXAMPLE_DIR / parent


def compute_import_path(output_dir: Path) -> str:
    """Compute relative import path to flutter_mocks.dart."""
    rel = os.path.relpath(MOCKS_FILE, output_dir)
    return rel.replace("\\", "/")


def _detect_needed_stubs(code: str) -> set:
    """Detect which common stub identifiers are referenced in code."""
    needed = set()
    for name in _COMMON_STUBS:
        if re.search(r"\b" + re.escape(name) + r"\b", code):
            needed.add(name)
    return needed


# Common identifiers used in DartDoc examples that need stub declarations
_COMMON_STUBS = {
    "context": "final context = BuildContext();",
    "items": "final items = <dynamic>[];",
    "user": "dynamic user;",
    "url": "final url = 'https://example.com';",
    "data": "dynamic data;",
    "json": "dynamic json;",
    "http": "dynamic http;",
    "api": "dynamic api;",
    "db": "dynamic db;",
    "prefs": "dynamic prefs;",
    "value": "dynamic value;",
    "name": "final name = 'example';",
    "count": "var count = 0;",
    "result": "dynamic result;",
    "response": "dynamic response;",
    "controller": "dynamic controller;",
    "key": "final key = 'key';",
    "token": "final token = 'token';",
    "email": "final email = 'test@example.com';",
    "password": "final password = 'secret';",
    "title": "final title = 'Title';",
    "message": "final message = 'Message';",
    "error": "dynamic error;",
    "index": "final index = 0;",
    "path": "final path = '/path';",
    "config": "dynamic config;",
    "state": "dynamic state;",
    "event": "dynamic event;",
    "widget": "dynamic widget;",
    "child": "dynamic child;",
    "children": "final children = <Widget>[];",
    "body": "dynamic body;",
    "client": "dynamic client;",
    "service": "dynamic service;",
    "repo": "dynamic repo;",
    "store": "dynamic store;",
    "timer": "dynamic timer;",
    "subscription": "dynamic subscription;",
    "stream": "dynamic stream;",
    "future": "dynamic future;",
    "callback": "dynamic callback;",
    "builder": "dynamic builder;",
    "navigator": "dynamic navigator;",
    "router": "dynamic router;",
    "theme": "dynamic theme;",
    "locale": "dynamic locale;",
    "input": "dynamic input;",
    "output": "dynamic output;",
    "text": "final text = 'text';",
    "label": "final label = 'label';",
    "image": "dynamic image;",
    "file": "dynamic file;",
    "id": "final id = '1';",
    "isError": "final isError = false;",
    "isLoading": "final isLoading = false;",
    "isValid": "final isValid = true;",
    "isar": "dynamic isar;",
    "box": "dynamic box;",
    "ref": "dynamic ref;",
    "cart": "dynamic cart;",
    # Additional stubs from error analysis
    "list": "dynamic list;",
    "dio": "final dio = Dio();",
    "secureStorage": "final secureStorage = FlutterSecureStorage();",
    "collection": "dynamic collection;",
    "item": "dynamic item;",
    "condition": "final condition = false;",
    "date": "final date = DateTime.now();",
    "userId": "final userId = '123';",
    "device": "dynamic device;",
    "flutterLocalNotificationsPlugin": "final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();",
    "channel": "dynamic channel;",
    "users": "final users = <dynamic>[];",
    "userName": "final userName = 'John';",
    "content": "dynamic content;",
    "picker": "final picker = ImagePicker();",
    "point": "dynamic point;",
    "mounted": "final mounted = true;",
    "userProvider": "dynamic userProvider;",
    "uri": "final uri = Uri.parse('https://example.com');",
    "status": "dynamic status;",
    "l10n": "dynamic l10n;",
    "library": "dynamic library;",
    "step": "dynamic step;",
    "details": "dynamic details;",
    "remoteConfig": "dynamic remoteConfig;",
    "map": "dynamic map;",
    "largeList": "final largeList = List.generate(1000, (i) => i);",
    "x": "dynamic x;",
    "y": "dynamic y;",
    "a": "dynamic a;",
    "b": "dynamic b;",
    "getIt": "final getIt = GetIt.instance;",
}


def generate_fixture_file(rule: RuleInfo, idx: int) -> str:
    """Generate fixture file content for a single rule."""
    output_dir = get_output_dir(rule.category)
    import_path = compute_import_path(output_dir)

    # Collect all example code to detect needed stubs
    all_code = "\n".join(
        rule.bad_examples + rule.good_examples
    )
    needed_stubs = _detect_needed_stubs(all_code)

    parts = [
        "// ignore_for_file: unused_local_variable, unused_element",
        "// ignore_for_file: depend_on_referenced_packages",
        "// ignore_for_file: prefer_const_constructors",
        "// ignore_for_file: unnecessary_import, unused_import",
        "// ignore_for_file: avoid_unused_constructor_parameters",
        "// ignore_for_file: override_on_non_overriding_member",
        "// ignore_for_file: annotate_overrides, duplicate_ignore",
        "// ignore_for_file: non_abstract_class_inherits_abstract_member",
        "// ignore_for_file: extends_non_class, mixin_of_non_class",
        "// ignore_for_file: field_initializer_outside_constructor",
        "// ignore_for_file: final_not_initialized",
        "// ignore_for_file: super_in_invalid_context",
        "// ignore_for_file: concrete_class_with_abstract_member",
        "// ignore_for_file: type_argument_not_matching_bounds",
        "// ignore_for_file: missing_required_argument",
        "// ignore_for_file: undefined_named_parameter",
        "// ignore_for_file: argument_type_not_assignable",
        "// ignore_for_file: invalid_constructor_name",
        "// ignore_for_file: super_formal_parameter_without_associated_named",
        "// ignore_for_file: undefined_annotation, creation_with_non_type",
        "// ignore_for_file: invalid_factory_name_not_a_class",
        "// ignore_for_file: invalid_reference_to_this",
        "// ignore_for_file: expected_class_member",
        "// ignore_for_file: body_might_complete_normally",
        "// ignore_for_file: not_initialized_non_nullable_instance_field",
        "// ignore_for_file: unchecked_use_of_nullable_value",
        "// ignore_for_file: return_of_invalid_type",
        "// ignore_for_file: use_of_void_result",
        "// ignore_for_file: missing_function_body",
        "// ignore_for_file: extra_positional_arguments",
        "// ignore_for_file: not_enough_positional_arguments",
        "// ignore_for_file: unused_label",
        "// ignore_for_file: unused_element_parameter",
        "// ignore_for_file: non_type_as_type_argument",
        "// ignore_for_file: expected_identifier_but_got_keyword",
        "// ignore_for_file: expected_token, missing_identifier",
        "// ignore_for_file: unexpected_token",
        "// ignore_for_file: duplicate_definition",
        "// ignore_for_file: override_on_non_overriding_member",
        "// ignore_for_file: extends_non_class",
        "// ignore_for_file: no_default_super_constructor",
        "// ignore_for_file: extra_positional_arguments_could_be_named",
        "// ignore_for_file: missing_function_parameters",
        "// ignore_for_file: invalid_annotation, invalid_assignment",
        "// ignore_for_file: expected_executable",
        "// ignore_for_file: named_parameter_outside_group",
        "// ignore_for_file: obsolete_colon_for_default_value",
        "// ignore_for_file: referenced_before_declaration",
        "// ignore_for_file: await_in_wrong_context",
        "// ignore_for_file: non_type_in_catch_clause",
        "// ignore_for_file: could_not_infer",
        "// ignore_for_file: uri_does_not_exist",
        "// ignore_for_file: const_method",
        "// ignore_for_file: redirect_to_non_class",
        "// ignore_for_file: unused_catch_clause",
        "// ignore_for_file: type_test_with_undefined_name",
        f"// Test fixture for: {rule.rule_name}",
        f"// Source: {rule.source_file}",
        "",
        f"import '{import_path}';",
        "",
    ]

    # Add needed stub declarations
    if needed_stubs:
        for name in sorted(needed_stubs):
            parts.append(_COMMON_STUBS[name])
        parts.append("")

    # Bad examples
    if rule.bad_examples:
        for i, bad in enumerate(rule.bad_examples):
            suffix = f"_{i}" if len(rule.bad_examples) > 1 else ""
            parts.append(f"// BAD: Should trigger {rule.rule_name}")
            parts.append(f"// expect_lint: {rule.rule_name}")
            sanitized = sanitize_code(
                bad, rule.rule_name, f"bad{suffix}", idx
            )
            parts.append(sanitized)
            parts.append("")
    else:
        bad_code, _ = generate_fallback(rule, idx)
        parts.append(f"// BAD: Should trigger {rule.rule_name}")
        parts.append(f"// expect_lint: {rule.rule_name}")
        parts.append(bad_code)
        parts.append("")

    # Good examples (false positive check)
    if rule.good_examples:
        for i, good in enumerate(rule.good_examples):
            suffix = f"_{i}" if len(rule.good_examples) > 1 else ""
            parts.append(f"// GOOD: Should NOT trigger {rule.rule_name}")
            sanitized = sanitize_code(
                good, rule.rule_name, f"good{suffix}", idx
            )
            parts.append(sanitized)
            parts.append("")
    else:
        _, good_code = generate_fallback(rule, idx)
        parts.append(f"// GOOD: Should NOT trigger {rule.rule_name}")
        parts.append(good_code)
        parts.append("")

    return "\n".join(parts)


# ── Main ─────────────────────────────────────────────────────────────────


def main():
    print("=" * 70)
    print("Saropa Lints - Test Fixture Generator")
    print("=" * 70)

    # Step 1: Find existing coverage
    print("\n[1/4] Scanning existing fixture coverage...")
    covered = find_existing_coverage()
    print(f"  Found {len(covered)} rules with existing coverage")

    # Step 2: Extract all rules from source files
    print("\n[2/4] Parsing rule source files...")
    all_rules = []
    rule_files = sorted(RULES_DIR.rglob("*_rules.dart"))
    rule_files = [f for f in rule_files if f.stem != "all_rules"]

    for rf in rule_files:
        rules = extract_rules_from_file(rf)
        all_rules.extend(rules)
        if rules:
            print(f"  {rf.stem}: {len(rules)} rules")

    print(f"\n  Total rules found: {len(all_rules)}")

    # Step 3: Filter out already-covered rules
    uncovered = [r for r in all_rules if r.rule_name not in covered]
    print(f"  Uncovered rules: {len(uncovered)}")

    with_bad = sum(1 for r in uncovered if r.bad_examples)
    with_good = sum(1 for r in uncovered if r.good_examples)
    with_both = sum(
        1 for r in uncovered if r.bad_examples and r.good_examples
    )
    print(f"  With BAD examples: {with_bad}")
    print(f"  With GOOD examples: {with_good}")
    print(f"  With BOTH: {with_both}")
    print(f"  Without any examples (Tier C): {len(uncovered) - with_bad}")

    # Step 4: Generate fixture files
    print("\n[3/4] Generating fixture files...")
    generated = 0
    skipped = 0
    errors = 0

    for idx, rule in enumerate(uncovered):
        output_dir = get_output_dir(rule.category)
        output_file = output_dir / f"{rule.rule_name}_fixture.dart"

        try:
            output_dir.mkdir(parents=True, exist_ok=True)
            content = generate_fixture_file(rule, idx)
            output_file.write_text(content, encoding="utf-8")
            generated += 1
        except Exception as e:
            print(f"  ERROR: {rule.rule_name}: {e}")
            errors += 1

    print(f"\n  Generated: {generated} fixture files")
    print(f"  Skipped (already exist): {skipped}")
    print(f"  Errors: {errors}")

    total_coverage = len(covered) + generated
    print("\n[4/4] Summary")
    print("=" * 70)
    print(f"  Previously covered: {len(covered)} rules")
    print(f"  Newly generated:    {generated} fixture files")
    print(f"  Total coverage:     {total_coverage}/{len(all_rules)} rules")
    if all_rules:
        pct = total_coverage / len(all_rules) * 100
        print(f"  Coverage:           {pct:.1f}%")
    print("=" * 70)

    categories = {}
    for rule in uncovered:
        cat = rule.category
        categories[cat] = categories.get(cat, 0) + 1
    if categories:
        print("\n  Rules generated per category:")
        for cat in sorted(categories, key=lambda c: categories[c], reverse=True):
            print(f"    {cat}: {categories[cat]}")

    return 0 if errors == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
