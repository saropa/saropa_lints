"""List all fixture files that fail dart format."""
import subprocess
import os
import re

os.chdir(r'd:\src\saropa_lints')
r = subprocess.run(
    'D:/tools/flutter/bin/dart.bat format --output=none --set-exit-if-changed example/lib/',
    capture_output=True, text=True, shell=True
)
out = r.stdout + r.stderr
files = set()
for line in out.split('\n'):
    m = re.search(r'of (example[\\/][^\s:]+\.dart)', line)
    if m:
        files.add(m.group(1).replace('\\', '/'))
print(f'Total broken: {len(files)}')
for f in sorted(files):
    print(f)
