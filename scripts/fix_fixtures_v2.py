"""Fix remaining broken fixture files - undo _topLevel wrapping and other issues."""
import os
import re
import subprocess

os.chdir(r'd:\src\saropa_lints')

def get_broken_files():
    """Get list of files that fail dart format."""
    result = subprocess.run(
        'D:/tools/flutter/bin/dart.bat format --output=none --set-exit-if-changed example/lib/',
        capture_output=True, text=True, shell=True
    )
    output = result.stdout + result.stderr
    files = set()
    for line in output.split('\n'):
        m = re.search(r'of (example[\\/][^\s:]+\.dart)', line)
        if m:
            files.add(m.group(1).replace('\\', '/'))
    return sorted(files)


def undo_toplevel_wrapping(content):
    """Remove void _topLevelXXX() { ... } wrappers that were incorrectly inserted."""
    lines = content.split('\n')
    new_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Detect _topLevel wrapper: "void _topLevelNNN() {"
        m = re.match(r'^(\s*)void _topLevel\d+\(\)\s*\{', line)
        if m:
            indent = m.group(1)
            # Collect the wrapped lines until we find the matching close brace
            inner_lines = []
            depth = 1
            j = i + 1
            while j < len(lines) and depth > 0:
                inner = lines[j]
                depth += inner.count('{') - inner.count('}')
                if depth > 0:
                    inner_lines.append(inner)
                elif depth == 0:
                    # This is the closing brace of the wrapper
                    # Check if there's content before the } on this line
                    close_stripped = inner.strip()
                    if close_stripped != '}':
                        # There's content before the }, keep it
                        inner_lines.append(inner.replace('}', '', 1).rstrip())
                j += 1

            # Dedent the inner lines by 2 spaces if they were indented
            for inner_line in inner_lines:
                if inner_line.startswith(indent + '  '):
                    new_lines.append(indent + inner_line[len(indent) + 2:])
                else:
                    new_lines.append(inner_line)
            i = j
            continue

        new_lines.append(line)
        i += 1

    return '\n'.join(new_lines)


def fix_missing_semicolons(content):
    """Add missing semicolons after expression statements in function bodies."""
    lines = content.split('\n')
    new_lines = []

    for i, line in enumerate(lines):
        stripped = line.strip()

        # Skip empty, comments, class/function declarations
        if not stripped or stripped.startswith('//') or stripped.startswith('/*'):
            new_lines.append(line)
            continue

        # Expression statements that need semicolons:
        # Pattern: line ends with ) but no ; and next non-empty line is } or another statement
        if (stripped.endswith(')') and
            not stripped.endswith(');') and
            not stripped.endswith(') {') and
            not stripped.endswith(') =>') and
            not stripped.endswith('),') and
            not re.match(r'^\s*(void|int|double|String|bool|dynamic|var|final|const|late|Future|Stream|Widget|class|abstract|if|else|for|while|switch|return|try|catch)\b', line) and
            not stripped.startswith('@') and
            not stripped.startswith('typedef ') and
            not re.match(r'^\s*\w+\s*\(', stripped)):  # Skip function declarations

            # Check if we're inside a function body (indented)
            if line.startswith('  ') or line.startswith('\t'):
                # Look at next non-empty line
                next_line = ''
                for k in range(i + 1, min(i + 3, len(lines))):
                    if lines[k].strip():
                        next_line = lines[k].strip()
                        break

                if next_line in ('}', '};') or next_line.startswith('//') or next_line.startswith('return') or next_line.startswith('}'):
                    new_lines.append(line.rstrip() + ';')
                    continue

        # Pattern: Text('xxx') // comment - missing semicolon before comment
        m = re.match(r'^(\s+\S+.*\))\s*(//.*)', line)
        if m and not m.group(1).strip().endswith(';') and not m.group(1).strip().endswith('{') and not m.group(1).strip().endswith(','):
            if line.startswith('  '):
                new_lines.append(m.group(1) + '; ' + m.group(2))
                continue

        new_lines.append(line)

    return '\n'.join(new_lines)


def fix_static_in_functions(content):
    """Remove 'static' from declarations inside function bodies (not in classes)."""
    lines = content.split('\n')
    new_lines = []
    brace_depth = 0
    in_class = False
    class_depth = 0

    for line in lines:
        stripped = line.strip()

        # Track class declarations
        if re.match(r'(abstract\s+)?(final\s+)?(base\s+)?(sealed\s+)?class\s+', stripped):
            if brace_depth == 0:
                in_class = True
                class_depth = brace_depth

        # Track brace depth
        opens = stripped.count('{')
        closes = stripped.count('}')
        brace_depth += opens - closes

        # If we're inside a function (not at class level), remove static
        if brace_depth > 0 and not in_class:
            if stripped.startswith('static const '):
                line = line.replace('static const ', 'const ', 1)
            elif stripped.startswith('static final '):
                line = line.replace('static final ', 'final ', 1)
            elif stripped.startswith('static ') and not stripped.startswith('static void') and not stripped.startswith('static Future'):
                line = line.replace('static ', '', 1)

        if brace_depth <= class_depth and in_class:
            in_class = False

        new_lines.append(line)

    return '\n'.join(new_lines)


def fix_extension_type(content):
    """Comment out extension type declarations (needs inline-class feature)."""
    lines = content.split('\n')
    new_lines = []
    in_extension_type = False
    ext_depth = 0

    for line in lines:
        stripped = line.strip()

        if re.match(r'extension\s+type\s+', stripped):
            in_extension_type = True
            ext_depth = 0

        if in_extension_type:
            ext_depth += stripped.count('{') - stripped.count('}')
            new_lines.append('// ' + line if not line.startswith('//') else line)
            if ext_depth <= 0 and '{' in stripped:
                in_extension_type = False
            continue

        new_lines.append(line)

    return '\n'.join(new_lines)


def fix_dot_shorthand(content):
    """Comment out lines using .xxx dot shorthand syntax (Dart 3.7+)."""
    # Pattern: assignment/parameter with .enumValue
    content = re.sub(
        r'(\s+\w+\s+\w+\s*=\s*)(\.\w+)',
        r'\1/* \2 */ null',
        content
    )
    return content


def fix_null_aware_elements(content):
    """Comment out ?item syntax (null-aware-elements feature)."""
    content = re.sub(
        r'(\s+)\?(\w+)',
        r'\1/* ?\2 */ \2',
        content
    )
    return content


def fix_interface_class_in_function(content):
    """Comment out interface class inside function bodies."""
    lines = content.split('\n')
    new_lines = []
    brace_depth = 0
    in_interface_class = False
    ic_start_depth = 0

    for line in lines:
        stripped = line.strip()

        if brace_depth > 0 and re.match(r'interface\s+class\s+', stripped):
            in_interface_class = True
            ic_start_depth = brace_depth

        brace_depth += stripped.count('{') - stripped.count('}')

        if in_interface_class:
            new_lines.append('  // ' + stripped)
            if brace_depth <= ic_start_depth:
                in_interface_class = False
            continue

        new_lines.append(line)

    return '\n'.join(new_lines)


def fix_typedef_before_import(content):
    """Move typedef declarations that appear before import statements."""
    lines = content.split('\n')

    # Find typedefs before imports
    typedefs = []
    import_start = None
    for i, line in enumerate(lines):
        if line.startswith('typedef '):
            typedefs.append((i, line))
        if line.startswith('import ') and import_start is None:
            import_start = i

    if typedefs and import_start is not None:
        # Check if any typedef is before the import
        for idx, td in typedefs:
            if idx < import_start:
                # Move this typedef after the last import
                lines[idx] = ''  # Remove from original position
                # Find last import
                last_import = import_start
                for j in range(import_start, len(lines)):
                    if lines[j].startswith('import '):
                        last_import = j
                lines.insert(last_import + 1, td)

    return '\n'.join(lines)


def fix_class_inside_class(content):
    """Comment out nested class declarations that aren't valid Dart."""
    lines = content.split('\n')
    new_lines = []
    class_depth = 0
    in_top_class = False
    in_nested_class = False
    nested_start_depth = 0

    for line in lines:
        stripped = line.strip()

        if re.match(r'(abstract\s+)?(final\s+)?(base\s+)?(sealed\s+)?class\s+', stripped):
            if class_depth == 0:
                in_top_class = True
            elif in_top_class and not in_nested_class:
                in_nested_class = True
                nested_start_depth = class_depth

        class_depth += stripped.count('{') - stripped.count('}')

        if in_nested_class:
            new_lines.append('  // ' + stripped)
            if class_depth <= nested_start_depth:
                in_nested_class = False
            continue

        if class_depth <= 0:
            in_top_class = False

        new_lines.append(line)

    return '\n'.join(new_lines)


def fix_const_getter(content):
    """Fix 'const ClassName()' at top level that looks like a getter declaration."""
    # Pattern: const _ClassName({ ... }) at indent level 0 inside a class
    # These are actually constructor declarations
    return content


def fix_pragma_semicolon(content):
    """Fix @pragma('...'); - annotations shouldn't end with semicolon."""
    content = re.sub(r"(@pragma\('[^']+'\));", r'\1', content)
    return content


def fix_arrow_missing_body(content):
    """Fix => followed by ) - arrow function missing body."""
    content = re.sub(r'=>\s*\)', '=> Container())', content)
    content = re.sub(r'=>\s*;', '=> null;', content)
    return content


def fix_file(filepath):
    """Apply comprehensive fixes to a fixture file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content

    # Step 1: Undo _topLevel wrapping (most impactful fix)
    content = undo_toplevel_wrapping(content)

    # Step 2: Fix typedef before import
    content = fix_typedef_before_import(content)

    # Step 3: Fix extension type
    content = fix_extension_type(content)

    # Step 4: Fix interface class in function
    content = fix_interface_class_in_function(content)

    # Step 5: Fix static in function bodies
    content = fix_static_in_functions(content)

    # Step 6: Fix pragma semicolon
    content = fix_pragma_semicolon(content)

    # Step 7: Fix arrow missing body
    content = fix_arrow_missing_body(content)

    # Step 8: Fix class inside class
    content = fix_class_inside_class(content)

    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    return False


def main():
    broken = get_broken_files()
    print(f'Found {len(broken)} broken files')

    fixed = 0
    for filepath in broken:
        full_path = os.path.join(r'd:\src\saropa_lints', filepath)
        if os.path.exists(full_path):
            if fix_file(full_path):
                fixed += 1
                print(f'  Fixed: {filepath}')
            else:
                print(f'  No changes: {filepath}')

    print(f'\nFixed {fixed} of {len(broken)} files')

    # Check remaining
    remaining = get_broken_files()
    print(f'\nStill broken: {len(remaining)} files')
    for f in remaining:
        print(f'  {f}')


if __name__ == '__main__':
    main()
