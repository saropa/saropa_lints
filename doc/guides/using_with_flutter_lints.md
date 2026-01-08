# Using saropa_lints with flutter_lints

This guide explains how `flutter_lints` and `saropa_lints` work together.

## Understanding the Difference

| Aspect | flutter_lints | saropa_lints |
|--------|--------------|--------------|
| **Type** | Standard Dart analyzer rules | Custom lint rules (custom_lint) |
| **Rule count** | ~30 rules | 766+ rules |
| **Analysis depth** | Syntax and style | Behavior and semantics |
| **Provided by** | Flutter team (official) | Saropa (community) |

**Key insight**: These packages are *complementary*, not competing. They analyze code differently and catch different issues.

## What Each Package Catches

### flutter_lints catches

```dart
// Style issues
var x = 1;  // prefer_const_declarations
print('debug');  // avoid_print

// Syntax issues
if (condition)  // missing braces (optional)
  doSomething();
```

### saropa_lints catches

```dart
// Memory leaks - controller never disposed
final _controller = TextEditingController();

// Runtime crash - setState after widget disposed
await api.fetchData();
setState(() => _data = data);

// Security - hardcoded credentials
final apiKey = 'sk-1234567890';

// Accessibility - missing semantics
IconButton(icon: Icon(Icons.menu), onPressed: _open);  // no tooltip
```

## Recommended Setup

Use both packages together for comprehensive coverage:

### 1. Update pubspec.yaml

```yaml
dev_dependencies:
  flutter_lints: ^5.0.0    # Standard rules (or comes with Flutter SDK)
  custom_lint: ^0.8.0       # Custom lint framework
  saropa_lints: ^1.3.0      # Deep analysis rules
```

### 2. Update analysis_options.yaml

```yaml
# Include flutter_lints standard rules
include: package:flutter_lints/flutter.yaml

# Enable custom_lint for saropa_lints
analyzer:
  plugins:
    - custom_lint

# Configure saropa_lints tier
custom_lint:
  saropa_lints:
    tier: recommended  # essential | recommended | professional | comprehensive | insanity
```

### 3. Run both analyzers

```bash
# Standard analyzer (includes flutter_lints)
flutter analyze

# Custom lint rules (saropa_lints)
dart run custom_lint
```

## Why Use Both?

### Coverage comparison

| Category | flutter_lints | saropa_lints |
|----------|--------------|--------------|
| Code style | Yes | Limited |
| Memory leaks | No | Yes |
| Security issues | No | Yes |
| Accessibility | No | Yes |
| State management | No | Yes |
| Performance patterns | Limited | Yes |
| Lifecycle bugs | No | Yes |

### Example: What gets caught

```dart
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();  // saropa: require_dispose

  @override
  Widget build(BuildContext context) {
    var data = fetchData();  // flutter_lints: prefer_final_locals
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: 'Email',  // saropa: avoid_hardcoded_strings_in_ui (professional tier)
      ),
    );
  }

  // saropa: Missing dispose() method!
}
```

## Tier Recommendations

| Project Type | flutter_lints | saropa_lints Tier |
|--------------|--------------|-------------------|
| Learning/demos | Yes | essential |
| Side projects | Yes | recommended |
| Production apps | Yes | professional |
| Enterprise/regulated | Yes | comprehensive |

## Common Questions

### Do I need flutter_lints if I have saropa_lints?

**Yes.** They serve different purposes:
- `flutter_lints` enforces Dart style guidelines and catches common syntax issues
- `saropa_lints` catches behavioral bugs, security issues, and Flutter-specific anti-patterns

### Will they conflict?

**No.** They use different analysis systems:
- `flutter_lints` uses the standard Dart analyzer
- `saropa_lints` uses the custom_lint framework

Both can run simultaneously without interference.

### Can I use a stricter base than flutter_lints?

Yes! You can use `very_good_analysis` or other packages as your base:

```yaml
# Use VGA instead of flutter_lints
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  plugins:
    - custom_lint

custom_lint:
  saropa_lints:
    tier: professional
```

See our [VGA migration guide](migration_from_vga.md) for details.

## CI Integration

Run both checks in your CI pipeline:

```yaml
# GitHub Actions example
- name: Analyze (standard)
  run: flutter analyze

- name: Analyze (custom rules)
  run: dart run custom_lint
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about using both packages? Open an issue - we're happy to help.
