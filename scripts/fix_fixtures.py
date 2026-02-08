"""Fix common syntax errors in generated fixture files."""
import os
import re
import subprocess
import sys


def get_broken_files():
    """Get list of files that fail dart format."""
    result = subprocess.run(
        [r'D:\tools\flutter\bin\dart.bat', 'format', '--set-exit-if-changed', 'example/lib/'],
        capture_output=True, text=True, cwd=r'd:\src\saropa_lints', shell=True
    )
    output = result.stdout + result.stderr
    files = set()
    for line in output.split('\n'):
        if ' of example' in line:
            match = re.search(r'of (example\\[^\s:]+\.dart)', line)
            if match:
                files.add(match.group(1))
    return sorted(files)


def fix_file(filepath):
    """Apply common fixes to a fixture file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content
    lines = content.split('\n')

    # Find where code starts (after ignore_for_file comments and imports)
    code_start = 0
    for i, line in enumerate(lines):
        if line.startswith('// ignore_for_file:') or line.startswith('// Test fixture') or line.startswith('// Source:'):
            code_start = i + 1
        elif line.startswith('import '):
            code_start = i + 1
        elif line.strip() == '' and i < code_start + 3:
            code_start = i + 1

    # Fix 1: child:, -> child: child,
    content = re.sub(r'\bchild:\s*,', 'child: child,', content)

    # Fix 2: child: followed by ) -> child: child)
    content = re.sub(r'\bchild:\s*\n\s*\)', 'child: child\n  )', content)

    # Fix 3: static const/final inside function bodies
    # Detect if static is inside a function
    lines = content.split('\n')
    new_lines = []
    brace_depth = 0
    in_class = False
    for line in lines:
        stripped = line.strip()

        # Track class context
        if re.match(r'(abstract\s+)?(final\s+)?class\s+', stripped):
            in_class = True

        # Track brace depth (rough)
        brace_depth += stripped.count('{') - stripped.count('}')

        # If we're inside braces (function body) and not in a class, remove static
        if brace_depth > 0 and not in_class:
            if stripped.startswith('static const '):
                line = line.replace('static const ', 'const ', 1)
            elif stripped.startswith('static final '):
                line = line.replace('static final ', 'final ', 1)

        if brace_depth == 0:
            in_class = False

        new_lines.append(line)
    content = '\n'.join(new_lines)

    # Fix 4: 'final class X { }' inside a function -> comment it out
    content = re.sub(
        r'(\s+)(final class \w+ \{[^}]*\}.*)',
        r'\1// \2',
        content
    )

    # Fix 5: Top-level statements that need to be in functions
    # Pattern: top-level function call like foo(args);
    lines = content.split('\n')
    new_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Check if this is a top-level expression statement (not in function/class)
        # These patterns at column 0 are problematic:
        # - function_call(args);
        # - list.method(args);
        # But only if they're not declarations, imports, comments, etc.
        if (i > code_start and
            not stripped.startswith('//') and
            not stripped.startswith('import') and
            not stripped.startswith('export') and
            not stripped.startswith('class ') and
            not stripped.startswith('abstract ') and
            not stripped.startswith('mixin ') and
            not stripped.startswith('enum ') and
            not stripped.startswith('typedef ') and
            not stripped.startswith('extension ') and
            not stripped.startswith('void ') and
            not stripped.startswith('int ') and
            not stripped.startswith('double ') and
            not stripped.startswith('String ') and
            not stripped.startswith('bool ') and
            not stripped.startswith('dynamic ') and
            not stripped.startswith('var ') and
            not stripped.startswith('final ') and
            not stripped.startswith('const ') and
            not stripped.startswith('late ') and
            not stripped.startswith('Future') and
            not stripped.startswith('Stream') and
            not stripped.startswith('List') and
            not stripped.startswith('Map') and
            not stripped.startswith('Set') and
            not stripped.startswith('Widget') and
            not stripped.startswith('@') and
            not stripped == '' and
            not stripped == '}' and
            not stripped == '{' and
            not stripped.startswith('//') and
            len(line) > 0 and line[0] != ' ' and line[0] != '\t'):

            # This might be a top-level statement - wrap in function
            # Collect consecutive non-declaration lines
            block = [line]
            j = i + 1
            while j < len(lines) and lines[j].strip() and not lines[j].strip().startswith('//'):
                block.append(lines[j])
                j += 1

            # Only wrap if it looks like an expression
            if any(c in stripped for c in ['(', '.', '=']) and not stripped.startswith('void ') and not 'class ' in stripped:
                # Wrap in a function
                func_name = f'_topLevel{i}'
                new_lines.append(f'void {func_name}() {{')
                for bline in block:
                    new_lines.append(f'  {bline}')
                new_lines.append('}')
                i = j
                continue

        new_lines.append(line)
        i += 1
    content = '\n'.join(new_lines)

    # Fix 6: Expression statements missing semicolons inside functions
    # Pattern: Constructor(args) followed by // comment on same line, without ;
    content = re.sub(
        r'(\)\s*)(//[^\n]*)\n(\s*\})',
        r');\2\n\3',
        content
    )

    # Fix 7: Constructor name mismatches - constructor name should match class
    # Pattern: class _bad123_Foo ... \n Foo( -> _bad123_Foo(
    lines = content.split('\n')
    new_lines = []
    current_class = None
    for line in lines:
        stripped = line.strip()

        # Detect class declaration
        class_match = re.match(r'(?:abstract\s+)?(?:final\s+)?class\s+(\w+)', stripped)
        if class_match:
            current_class = class_match.group(1)

        # Fix constructor that doesn't match class name
        if current_class and stripped and not stripped.startswith('//'):
            # Look for ClassName( pattern that doesn't match current_class
            base_name = re.sub(r'^_\w+\d+_', '', current_class)
            if base_name and stripped.startswith(base_name + '(') and not stripped.startswith(current_class + '('):
                line = line.replace(base_name + '(', current_class + '(', 1)

        if stripped == '}' and current_class:
            # End of class (rough heuristic)
            pass

        new_lines.append(line)
    content = '\n'.join(new_lines)

    # Fix 8: Closure bodies ending with } but missing ; (inside function bodies)
    # Pattern: label: () { ... } (missing ; after })
    # This is hard to fix generally, let's try a targeted approach
    lines = content.split('\n')
    new_lines = []
    for i, line in enumerate(lines):
        new_lines.append(line)
        # If this line is just "  }" and next line is "}" (function end),
        # and previous lines look like a closure, add ;
        if (line.strip() == '}' and
            i + 1 < len(lines) and lines[i + 1].strip() == '}' and
            i > 0):
            # Check if a few lines back we have label: () { or label: () async {
            for j in range(max(0, i - 10), i):
                if re.search(r'\w+:\s*\(.*\)\s*(async\s*)?\{', lines[j]):
                    # This closure needs a semicolon
                    new_lines[-1] = line.rstrip() + ';'  # add ; to the }
                    break
    content = '\n'.join(new_lines)

    # Fix 9: typedef inside function -> move outside
    lines = content.split('\n')
    new_lines = []
    typedefs_to_move = []
    brace_depth = 0
    for line in lines:
        stripped = line.strip()
        brace_depth += stripped.count('{') - stripped.count('}')
        if brace_depth > 0 and stripped.startswith('typedef '):
            typedefs_to_move.append(stripped)
            new_lines.append(line.replace(stripped, '// ' + stripped))
        else:
            new_lines.append(line)

    # Insert typedefs at top level (after imports)
    if typedefs_to_move:
        for i, line in enumerate(new_lines):
            if line.startswith('import ') or line.startswith('// ignore_for_file'):
                continue
            if line.strip() == '' and i > 10:
                for td in typedefs_to_move:
                    new_lines.insert(i + 1, td)
                break
    content = '\n'.join(new_lines)

    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        return True
    return False


def main():
    os.chdir(r'd:\src\saropa_lints')

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
    print(f'Still broken: {len(remaining)} files')
    for f in remaining:
        print(f'  {f}')


if __name__ == '__main__':
    main()
