import re
import sys

with open('lib/src/rules/flutter_widget_rules.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Find all LintCode blocks
pattern = r'static const LintCode (_code\w*) = LintCode\((.*?)\);'
matches = list(re.finditer(pattern, content, re.DOTALL))

print(f"Found {len(matches)} LintCode definitions\n")

issues_found = 0

for m in matches:
    var_name = m.group(1)
    block = m.group(2)

    # Extract name
    name_match = re.search(r"name:\s*'([^']+)'", block)
    name = name_match.group(1) if name_match else 'UNKNOWN'

    # Extract problemMessage - handle multiline strings with + concatenation
    # First try single-line
    pm_match = re.search(r"problemMessage:\s*'((?:[^'\\]|\\.)*)'", block)
    if pm_match:
        pm = pm_match.group(1)
    else:
        pm = 'NOT_FOUND'

    # Extract correctionMessage
    cm_match = re.search(r"correctionMessage:\s*'((?:[^'\\]|\\.)*)'", block)
    if cm_match:
        cm = cm_match.group(1)
    else:
        cm = 'NONE'

    # Calculate prefix
    prefix = f'[{name}] '

    # Get message after prefix
    if pm.startswith(prefix):
        pm_after = pm[len(prefix):]
    else:
        pm_after = pm

    pm_len = len(pm_after)
    cm_len = len(cm) if cm != 'NONE' else 0

    # Check issues
    issues = []
    if pm_len < 150:
        issues.append(f'PM_SHORT({pm_len})')
    if cm_len > 0 and cm_len < 80:
        issues.append(f'CM_SHORT({cm_len})')

    # Check vague words
    combined = pm.lower() + ' ' + (cm.lower() if cm != 'NONE' else '')
    for vague in ['should be', 'should have', 'consider ', 'best practice', 'not ideal']:
        if vague in combined:
            issues.append(f'VAGUE({vague})')

    # Check starts with Avoid after prefix
    if pm_after.startswith('Avoid'):
        issues.append('STARTS_AVOID')

    # Check passive voice
    for passive in ['is required', 'needs to be', 'must be used']:
        if passive in combined:
            issues.append(f'PASSIVE({passive})')

    if issues:
        issues_found += 1
        line_num = content[:m.start()].count('\n') + 1
        print(f'LINE {line_num} | {name} | ISSUES: {" | ".join(issues)}')
        print(f'  PM({pm_len}): {pm_after[:200]}')
        if cm != 'NONE':
            print(f'  CM({cm_len}): {cm[:200]}')
        print()

print(f"\nTotal rules with issues: {issues_found}/{len(matches)}")
