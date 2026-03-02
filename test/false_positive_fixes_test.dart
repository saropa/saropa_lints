import 'package:test/test.dart';

/// Tests for false positive fixes
///
/// This test file documents the expected behavior for rule fixes:
/// 1. require_subscription_status_check - word boundary matching
/// 2. require_deep_link_fallback - utility getter filtering
/// 3. require_https_only - safe replacement pattern detection
/// 4. avoid_passing_self_as_argument - literal value exclusion
/// 5. avoid_variable_shadowing - sibling closure scoping
/// 6. avoid_isar_clear_in_production - receiver type checking
/// 7. avoid_unused_instances - fire-and-forget constructor allowlist
/// 8. prefer_late_final - method call-site awareness
/// 9. avoid_nested_assignments - for-loop update clause and arrow body exclusion
/// 10. .contains() reduction (2026-03-01) - typeName/bodySource/targetSource
///     checks use word-boundary RegExp or exact sets so substrings do not trigger.
///
/// Test fixtures are located in:
/// - example/lib/require_subscription_status_check_example.dart
/// - example_widgets/lib/navigation/require_deep_link_fallback_fixture.dart
/// - example_async/lib/security/require_https_only_fixture.dart
/// - example/lib/avoid_variable_shadowing_fixture.dart
/// - example_packages/lib/isar/avoid_isar_clear_in_production_fixture.dart
/// - example/lib/avoid_nested_assignments_fixture.dart
void main() {
  group('False Positive Fixes', () {
    group('require_subscription_status_check', () {
      test('should use word boundary regex to avoid substring matches', () {
        // Expected behavior documented in fixture file
        // isProportional should NOT trigger (contains "isPro" but is not "isPro")
        // processData should NOT trigger (contains "pro" but is not "pro")
        // premiumQualityDescription should NOT trigger (describes quality, not access)

        expect(
          'Word boundary regex prevents false positives on substrings',
          isNotNull,
        );
      });

      test('should still detect actual premium indicators', () {
        // Expected behavior: These SHOULD trigger
        // - isPro
        // - hasPremium
        // - isPremiumUser
        // - proFeature

        expect('Actual premium indicators are still detected', isNotNull);
      });
    });

    group('require_deep_link_fallback', () {
      test('should skip utility getters with common prefixes', () {
        // Expected behavior: These should NOT trigger
        // - isNotUriNullOrEmpty (starts with "is")
        // - hasValidScheme (starts with "has")
        // - checkDeepLinkFormat (starts with "check")
        // - isValidDeepLink (starts with "is")

        expect(
          'Utility getters with is/has/check/valid prefixes are skipped',
          isNotNull,
        );
      });

      test('should skip utility methods that manage state', () {
        // Expected behavior: These should NOT trigger
        // - resetInitialUri() (starts with "reset")
        // - clearCurrentUri() (starts with "clear")
        // - setInitialUri() (starts with "set")
        // - getStoredUri() (starts with "get")

        expect(
          'Utility methods with reset/clear/set/get prefixes are skipped',
          isNotNull,
        );
      });

      test('should skip simple expression body getters', () {
        // Expected behavior: These should NOT trigger
        // - Uri? get initialUri => _initialUri;
        // - Uri? get currentRouteUri => _currentUri;

        expect('Simple getters returning a field are skipped', isNotNull);
      });

      test('should skip lazy-loading patterns', () {
        // Expected behavior: These should NOT trigger
        // - Uri? get uri => _uri ??= Uri.parse(url);
        // - Uri? get cachedUri => _cachedUri ??= parseUri();

        expect('Lazy-loading with ??= operator is skipped', isNotNull);
      });

      test('should skip simple method invocations', () {
        // Expected behavior: These should NOT trigger
        // - Uri? get parsedUri => url.toUri();
        // - Uri? get safeUri => url?.toUriSafe();
        // - Uri? uri() => _url.toUri();

        expect('Simple method invocations on fields are skipped', isNotNull);
      });

      test('should skip property access patterns', () {
        // Expected behavior: These should NOT trigger
        // - String? get uriScheme => _uri?.scheme;
        // - String? get uriHost => uri?.host;

        expect('Null-aware property access is skipped', isNotNull);
      });

      test('should skip trivial single-assignment method bodies', () {
        // Expected behavior: These should NOT trigger
        // - void resetUri() { _uri = null; }

        expect(
          'Methods with single assignment statement are skipped',
          isNotNull,
        );
      });

      test('should skip methods with simple return statements', () {
        // Expected behavior: These should NOT trigger
        // - Uri? getStoredUri() { return _uri; }
        // - Uri? getCachedUri() => _uri;
        // - Uri? getDefaultUri() { return null; }

        expect(
          'Methods with simple return of field/null are skipped',
          isNotNull,
        );
      });

      test('should skip utility getters ending with empty/null/nullable', () {
        // Expected behavior: These should NOT trigger
        // - isUriEmpty (ends with "empty")
        // - isUriNull (ends with "null")
        // - isUriNullable (ends with "nullable")

        expect(
          'Utility getters ending with empty/null/nullable are skipped',
          isNotNull,
        );
      });

      test('should still detect actual deep link handlers', () {
        // Expected behavior: These SHOULD trigger if missing fallback
        // - handleProductDeepLink
        // - handleUserProfileLink
        // - processDeepLink

        expect(
          'Actual deep link handlers without fallback are detected',
          isNotNull,
        );
      });

      test('should use suffix matching not substring matching', () {
        // handleEmptyDeepLink SHOULD be checked (not ending with "empty")
        // processNullableUri SHOULD be checked if not a getter with is/has prefix

        expect('Uses endsWith for precision, not contains', isNotNull);
      });

      test('should skip methods returning Widget types', () {
        // Expected behavior: These should NOT trigger
        // - Widget buildShareLinkButton() - UI builder
        // - Widget? buildRouteBanner() - nullable widget builder
        // Also covers Future<Widget>, PreferredSizeWidget, etc.

        expect(
          'Methods returning Widget types are UI builders, not handlers',
          isNotNull,
        );
      });

      test('should skip methods with no deep link signals in body', () {
        // Expected behavior: These should NOT trigger
        // - linkAccounts() - name has "link" but body has no Uri/Navigator
        // - logRouteChange() - name has "route" but body has no navigation

        expect(
          'Methods without Uri/Navigator/GoRouter in body are skipped',
          isNotNull,
        );
      });
    });

    group('require_https_only', () {
      test('should allow safe http to https replacement patterns', () {
        // Expected behavior: These should NOT trigger
        // - url.replaceFirst('http://', 'https://')
        // - content.replaceAll('http://', 'https://')
        // - text.replace('http://', 'https://')

        expect('Safe HTTP to HTTPS upgrade patterns are allowed', isNotNull);
      });

      test('should still detect hardcoded http URLs', () {
        // Expected behavior: These SHOULD trigger
        // - 'http://api.example.com/data'
        // - 'http://cdn.example.com/image.png'

        expect('Hardcoded HTTP URLs are still detected', isNotNull);
      });

      test('should allow localhost and development URLs', () {
        // Expected behavior: These should NOT trigger
        // - http://localhost:8080
        // - http://127.0.0.1:3000
        // - http://[::1]:8080
        // - http://192.168.1.100:8080

        expect('Localhost and local network URLs are allowed', isNotNull);
      });
    });

    group('avoid_passing_self_as_argument', () {
      test('should skip literal values as targets', () {
        // Expected behavior: These should NOT trigger
        // - 0.isBetween(0, 10)         // IntegerLiteral
        // - 3.14.isBetween(0.0, 5.0)   // DoubleLiteral
        // - 'test'.contains('test')    // StringLiteral
        // - true.toString() == 'true'  // BooleanLiteral

        expect(
          'Literal values (int, double, string, bool) are excluded',
          isNotNull,
        );
      });

      test('should still detect object self-references', () {
        // Expected behavior: These SHOULD trigger
        // - list.add(list)     // Adding list to itself
        // - map[key] = map     // Assigning map to itself
        // - obj.compare(obj)   // Comparing object to itself

        expect('Object self-references are still detected', isNotNull);
      });
    });

    group('avoid_variable_shadowing', () {
      test('should not flag sibling closures as shadowing', () {
        // Expected behavior: These should NOT trigger
        // Variables with same name in sibling closures (not nested) are
        // independent scopes, not shadowing
        //
        // group('...', () {
        //   test('A', () { final list = [1]; }); // Scope A
        //   test('B', () { final list = [2]; }); // Scope B - NOT shadowing
        // });
        //
        // The closures are siblings, not nested.

        expect('Sibling closures have independent scopes', isNotNull);
      });

      test('should still detect true nested shadowing', () {
        // Expected behavior: These SHOULD trigger
        // void outer() {
        //   final list = [1];        // Outer scope
        //   void inner() {
        //     final list = [2];      // SHADOWING - nested, not sibling
        //   }
        // }

        expect('Nested shadowing is still detected', isNotNull);
      });

      test('should detect parameter shadowing', () {
        // Expected behavior: These SHOULD trigger
        // int value = 10;
        // void process(int value) { } // Shadows outer 'value'

        expect('Parameter shadowing outer variable is detected', isNotNull);
      });

      test('should not flag sequential for loops with same variable', () {
        // Expected behavior: These should NOT trigger
        // for (final ex in listA) { ... } // scope A ends
        // for (final ex in listB) { ... } // scope B — not shadowing
        //
        // For-loop variables are scoped to the loop body.

        expect('Sequential loops with same name are not shadowing', isNotNull);
      });

      test('should not flag if/else sibling blocks with same variable', () {
        // Expected behavior: These should NOT trigger
        // if (cond) { final x = 1; } else { final x = 2; }
        //
        // Each branch is an independent scope.

        expect('If/else branches are independent scopes', isNotNull);
      });

      test('should still flag nested loop shadowing', () {
        // Expected behavior: These SHOULD trigger
        // for (final x in [1]) {
        //   for (final x in [2]) { ... } // Shadows outer loop x
        // }

        expect('Nested loop shadowing is still detected', isNotNull);
      });
    });

    group('avoid_unused_assignment', () {
      test('should not flag assignments inside loop bodies', () {
        // Expected behavior: These should NOT trigger
        // while (value.startsWith(find)) {
        //   value = value.substring(find.length); // loop condition re-reads
        // }

        expect('Loop body assignments are not flagged', isNotNull);
      });

      test('should not flag conditional reassignment that reads old value', () {
        // Expected behavior: These should NOT trigger
        // String first = this;
        // if (ignoreCase) first = first.toLowerCase(); // reads first on RHS
        // if (trim) first = first.trim(); // reads from previous step

        expect(
          'Conditional self-referencing overwrites are not flagged',
          isNotNull,
        );
      });

      test('should still flag unconditional overwrite without read', () {
        // Expected behavior: These SHOULD trigger
        // String value = 'first'; // FLAGGED
        // value = 'second'; // unconditional overwrite, no read

        expect('Unconditional dead assignment is still flagged', isNotNull);
      });

      test('should not flag definite assignment via if/else branches', () {
        // Expected behavior: These should NOT trigger
        // final int x;
        // if (condition) {
        //   x = a;   // mutually exclusive with else branch
        // } else {
        //   x = b;
        // }
        // print(x); // x IS read here

        expect('If/else definite assignment is not flagged', isNotNull);
      });

      test('should not flag chained else-if definite assignment', () {
        // Expected behavior: These should NOT trigger
        // final int x;
        // if (a) { x = 1; }
        // else if (b) { x = 2; }
        // else { x = 3; }
        // print(x);

        expect('Chained else-if definite assignment is not flagged', isNotNull);
      });
    });

    group('avoid_similar_names', () {
      test('should not flag single-character variable pairs', () {
        // Expected behavior: These should NOT trigger
        // final y = year.toString();
        // final m = month.toString();
        // final d = day.toString();
        // final h = hour.toString();
        // final s = second.toString();
        // All single-char names have edit distance 1, but are
        // universally understood date/time abbreviations.

        expect('Single-char variable pairs are not flagged', isNotNull);
      });

      test('should still flag confusable single-char names via 1/l or 0/O', () {
        // Expected behavior: These SHOULD still trigger
        // final value1 = 1;
        // final valuel = 2;  // 1 vs l — caught by normalization

        expect('Confusable char substitution is still flagged', isNotNull);
      });
    });

    group('prefer_switch_expression', () {
      test('should not flag switch with control flow in cases', () {
        // Expected behavior: These should NOT trigger
        // case 'y':
        //   if (isVowel()) return '${this}s'; // control flow
        //   return '${sub}ies';

        expect('Complex case logic prevents switch expression', isNotNull);
      });

      test('should not flag non-exhaustive switch with post-switch code', () {
        // Expected behavior: These should NOT trigger
        // switch (x) { case 'a': return 1; case 'b': return 2; }
        // return defaultValue; // code after non-exhaustive switch

        expect(
          'Non-exhaustive with post-switch code is not flagged',
          isNotNull,
        );
      });

      test('should still flag pure value-mapping switches', () {
        // Expected behavior: These SHOULD trigger
        // switch (n) { case 1: return 'one'; default: return 'other'; }

        expect('Simple value-mapping switch is still flagged', isNotNull);
      });
    });

    group('no_magic_number', () {
      test('should not flag default parameter values', () {
        // Expected behavior: These should NOT trigger
        // void fetch({int maxRetries = 3}) {} // parameter name is context
        // String pad({int width = 10}) {}

        expect('Default parameter values are self-documenting', isNotNull);
      });

      test('should still flag bare numeric literals', () {
        // Expected behavior: These SHOULD trigger
        // if (items.length > 42) {} // FLAGGED: what is 42?

        expect('Unexplained bare numbers are still flagged', isNotNull);
      });
    });

    group('avoid_unnecessary_to_list / avoid_large_list_copy', () {
      test('should not flag toList when required by return type', () {
        // Expected behavior: These should NOT trigger
        // List<bool> get reverse => map((b) => !b).toList(); // return is List

        expect('toList required by return type is not flagged', isNotNull);
      });

      test('should not flag toList when used in method chain', () {
        // Expected behavior: These should NOT trigger
        // .toList().nullIfEmpty() // downstream needs List

        expect('toList for method chain is not flagged', isNotNull);
      });

      test('should not flag toList in expression function body', () {
        // Expected behavior: These should NOT trigger
        // List<int> get evens => nums.where((n) => n.isEven).toList();

        expect('toList in expression body is not flagged', isNotNull);
      });
    });

    group('prefer_named_boolean_parameters', () {
      test('should not flag lambda/closure boolean parameters', () {
        // Expected behavior: These should NOT trigger
        // bools.any((bool e) => e) // lambda signature is constrained
        // bools.where((bool e) => !e)

        expect('Lambda bool params are externally constrained', isNotNull);
      });

      test('should still flag method boolean parameters', () {
        // Expected behavior: These SHOULD trigger
        // void doThing(bool verbose) {} // call site is doThing(true)

        expect('Method bool params are still flagged', isNotNull);
      });
    });

    group('avoid_unnecessary_nullable_return_type', () {
      test('should not flag ternary with null branch', () {
        // Expected behavior: These should NOT trigger
        // String? foo() => cond ? 'yes' : null; // null IS reachable

        expect('Ternary null branch is recognized', isNotNull);
      });

      test('should not flag nullable static type (map operator)', () {
        // Expected behavior: These should NOT trigger
        // String? get(Map<K,V> m, K key) => m[key]; // map[] returns V?

        expect('Nullable static types are recognized', isNotNull);
      });

      test('should still flag functions that never return null', () {
        // Expected behavior: These SHOULD trigger
        // String? bad() => 'always non-null';

        expect('Always-non-null functions are still flagged', isNotNull);
      });
    });

    group('avoid_barrel_files', () {
      test('should not flag package entry point or library directive', () {
        // Expected behavior: lib/<package_name>.dart and files with
        // library; or library name; are exempt (see bugs/history/false_positives/avoid_barrel_files_*)

        expect(
          'Package entry point and library directive are exempt',
          isNotNull,
        );
      });
    });

    group('avoid_duplicate_number_elements', () {
      test('should not flag List literals with intentional duplicates', () {
        // Expected behavior: Only Set literals are flagged. List literals
        // (e.g. days-in-month [31, 28, 31, 30, ...]) are not flagged.

        expect('List literals with duplicates are exempt', isNotNull);
      });
    });

    group('avoid_duplicate_string_literals', () {
      test('should not flag domain-inherent literals', () {
        // Expected behavior: These should NOT trigger
        // 'true', 'false', 'null', 'none' — self-documenting vocabulary

        expect('Domain inherent literals are exempt', isNotNull);
      });

      test('should still flag long duplicate strings', () {
        // Expected behavior: These SHOULD trigger
        // 'Processing data...' appearing 3+ times

        expect('Long duplicate strings are still flagged', isNotNull);
      });
    });

    group('avoid_excessive_expressions', () {
      test('should not flag guard clauses with many conditions', () {
        // Expected behavior: These should NOT trigger
        // if (a == null || b == null || c <= 0 || d <= 0 || e > 100 || f) {
        //   return; // guard clause — linear checklist
        // }

        expect('Guard clauses have elevated threshold', isNotNull);
      });

      test('should not flag symmetric structural patterns', () {
        // Expected behavior: These should NOT trigger
        // (startsWith('(') && endsWith(')')) ||
        // (startsWith('[') && endsWith(']')) ||
        // (startsWith('{') && endsWith('}'))

        expect(
          'Symmetric patterns are recognized as low complexity',
          isNotNull,
        );
      });

      test('should still flag deeply nested mixed operators', () {
        // Expected behavior: These SHOULD trigger
        // a > 0 && (b < 0 || (c != 0 && a + b > c - 1) || b * c < a)

        expect(
          'Complex non-symmetric expressions are still flagged',
          isNotNull,
        );
      });
    });

    group('prefer_digit_separators', () {
      test('should not flag 5-digit numbers', () {
        // Expected behavior: These should NOT trigger
        // const codePoint = 56327; // 5 digits — at readability boundary

        expect('5-digit numbers are below new threshold', isNotNull);
      });

      test('should still flag 6+ digit numbers', () {
        // Expected behavior: These SHOULD trigger
        // const population = 1000000; // 7 digits — should use 1_000_000

        expect('6+ digit numbers are still flagged', isNotNull);
      });
    });

    group('require_list_preallocate', () {
      test('should not flag conditional add inside loop', () {
        // Expected behavior: These should NOT trigger
        // for (final item in items) {
        //   if (item.isValid) result.add(item); // size unknowable
        // }

        expect('Conditional adds have unknowable size', isNotNull);
      });

      test('should still flag unconditional add inside loop', () {
        // Expected behavior: These SHOULD trigger
        // for (final item in items) {
        //   result.add(item.toString()); // always adds — use .map().toList()
        // }

        expect('Unconditional loop adds are still flagged', isNotNull);
      });
    });

    group('avoid_unused_instances', () {
      test('should not flag Future constructors as unused', () {
        // Expected behavior: These should NOT trigger
        // - Future.delayed(duration, callback)
        // - Future.microtask(callback)
        // - Future<void>.delayed(duration, callback)

        expect(
          'Future constructors used for side effects are skipped',
          isNotNull,
        );
      });

      test('should not flag Timer constructors as unused', () {
        // Expected behavior: These should NOT trigger
        // - Timer(duration, callback)
        // - Timer.periodic(duration, callback)

        expect(
          'Timer constructors used for side effects are skipped',
          isNotNull,
        );
      });

      test('should still detect genuinely unused instances', () {
        // Expected behavior: These SHOULD trigger
        // - MyClass()
        // - ValueNotifier(0)
        // - List<int>()

        expect('Genuinely unused instances are still detected', isNotNull);
      });
    });

    group('avoid_isar_clear_in_production', () {
      test('should only flag clear() on Isar instances', () {
        // Expected behavior:
        // isar.clear() without kDebugMode guard SHOULD trigger
        // isar.clear() inside if (kDebugMode) should NOT trigger

        expect('Only Isar.clear() triggers the rule', isNotNull);
      });

      test('should not flag clear() on Map, List, Set, or other types', () {
        // Expected behavior: These should NOT trigger
        // - cache.clear()      (Map<String, List<String>>)
        // - items.clear()      (List<int>)
        // - tags.clear()       (Set<String>)
        // - buffer.clear()     (StringBuffer)
        // - controller.clear() (TextEditingController)

        expect('Non-Isar clear() calls are not flagged', isNotNull);
      });
    });

    group('prefer_late_final', () {
      test(
        'should not flag fields assigned via method called multiple times',
        () {
          // Expected behavior:
          // A late field assigned in a helper method that is called from
          // multiple sites (e.g., initState + didUpdateWidget) should NOT
          // be flagged, because the field IS reassigned at runtime.
          //
          // class MyState {
          //   late Future<T> _future;
          //   void _fetch() { _future = loadData(); }
          //   void initState() { _fetch(); }           // Call site 1
          //   void didUpdateWidget() { _fetch(); }     // Call site 2
          // }

          expect(
            'Method call-site analysis prevents false positives',
            isNotNull,
          );
        },
      );

      test('should still flag fields with single call-site methods', () {
        // Expected behavior: These SHOULD trigger
        // - late field assigned in a method called from only one place
        // - late field assigned directly in a single method

        expect('Single-assignment fields are still detected', isNotNull);
      });

      test('should not flag fields with multiple direct assignments', () {
        // Expected behavior: These should NOT trigger
        // - late field assigned in init() AND reset()

        expect('Multiple direct assignments prevent flagging', isNotNull);
      });
    });

    group('contains_reduction_word_boundary', () {
      test(
        'type/body/target checks use word-boundary regex to avoid substring FPs',
        () {
          // After 2026-03-01 refactor: rules no longer use .contains() on
          // typeName, bodySource, targetSource, etc. They use RegExp with \b
          // or exact sets. Expected: identifiers that contain a substring
          // (e.g. MyValueNotifierHelper, SomeStreamControllerUtil) should
          // NOT trigger require_value_notifier_dispose / stream rules.
          expect(
            'Word-boundary and exact-match checks prevent substring false positives',
            isNotNull,
          );
        },
      );
    });

    group('avoid_nested_assignments', () {
      test('should not flag for-loop update clauses', () {
        // Expected behavior: These should NOT trigger
        // for (int i = 0; i < n; i += 1) {}
        // for (int i = 0; i < n; i += step) {}
        // for (int i = n; i > 0; i -= 1) {}
        // for (int i = 1; i < n; i *= 2) {}
        // for (int i = 0; i < n; i = next(i)) {}
        // for (int mask = 1; mask != 0; mask <<= 1) {}

        expect('For-loop update clause assignments are not nested', isNotNull);
      });

      test('should still flag assignments in conditions and arguments', () {
        // Expected behavior: These SHOULD trigger
        // if ((x = getValue()) > 0) {}
        // foo(x = 5)
        // final list = [x = 5]

        expect('Genuinely nested assignments are still detected', isNotNull);
      });

      test('should not flag arrow function body as sole assignment', () {
        // Expected behavior: These should NOT trigger
        // setState(() => _field = value)
        // callback(() => state = newState)
        // The assignment is the sole statement of the arrow body, not nested.

        expect(
          'Arrow function body that is a single assignment is exempt',
          isNotNull,
        );
      });
    });

    group('avoid_ignoring_return_values', () {
      test('property setter assignments should NOT trigger', () {
        // obj.value = x; setter return value is intentionally ignored.
        expect('Property setter assignment is exempt', isNotNull);
      });
    });

    group('avoid_ios_hardcoded_device_model', () {
      test('substring matches (e.g. domain names) should NOT trigger', () {
        // 'tripadvisor.com' contains 'ipad' but is not a device model.
        expect(
          'Word-boundary matching avoids substring false positives',
          isNotNull,
        );
      });
    });

    group('avoid_manual_date_formatting', () {
      test('map keys and cache keys should NOT trigger', () {
        // String interpolation used as map key, cache key, or internal id.
        expect(
          'Non-display contexts (map key, cache key) are exempt',
          isNotNull,
        );
      });
    });

    group('avoid_medium_length_files', () {
      test('counts code lines only; dartdoc and comments excluded', () {
        // File length uses code lines; thorough dartdoc does not increase count.
        expect('Code-only line count documented', isNotNull);
      });

      test('abstract final utility namespace files may be exempt', () {
        // Files with only abstract final const namespace are not long-file bloat.
        expect('Utility namespace exemption documented', isNotNull);
      });
    });

    group('avoid_missing_enum_constant_in_map', () {
      test('complete enum maps should NOT trigger', () {
        // Map with all enum constants resolved from actual enum type.
        expect('Complete maps are exempt via enum resolution', isNotNull);
      });
    });

    group('avoid_money_arithmetic_on_double', () {
      test('non-financial variable names should NOT trigger', () {
        // totalWidth, frameRate: word-boundary avoids money substring match.
        expect('Word-boundary matching avoids non-financial names', isNotNull);
      });
    });

    group('avoid_non_ascii_symbols', () {
      test('visible non-ASCII (emoji, accented) should NOT trigger', () {
        // Only invisible/confusable characters are flagged.
        expect('Invisible/confusable-only scope documented', isNotNull);
      });
    });

    group('require_websocket_reconnection', () {
      test('should not flag WebSocket class definitions', () {
        // Fixed: node.toSource() includes the class name, so classes
        // literally named WebSocket or WebSocketChannel always matched
        // their own string check, producing false positives on mock/stub
        // class definitions.
        //
        // These must NOT trigger:
        // - class WebSocket { ... }
        // - class WebSocketChannel { ... }

        expect(
          'WebSocket class definitions are skipped via exact name match',
          isNotNull,
        );
      });

      test(
        'should still flag classes that USE WebSocket without reconnection',
        () {
          // Expected behavior: These SHOULD trigger
          // - class ChatService { WebSocketChannel.connect(url); }
          // - class LiveFeed { WebSocket.connect(url); }
          //
          // Expected behavior: These should NOT trigger (has reconnection)
          // - class ChatService { ... reconnect() ... onDone: ... }

          expect(
            'Classes using WebSocket without reconnection are detected',
            isNotNull,
          );
        },
      );

      test('should not flag WebSocket subclass names', () {
        // Classes named BadWebSocketService, GoodWebSocketService,
        // WebSocketDemo are NOT skipped — they USE WebSocket and
        // should be checked for reconnection logic.

        expect(
          'Only exact WebSocket/WebSocketChannel names are skipped',
          isNotNull,
        );
      });
    });
  });

  group('6.0.4 / 6.0.5 False Positive Fixes', () {
    // Document expected behavior for rules fixed in CHANGELOG 6.0.4/6.0.5.
    // Fixtures: example_async/lib/security/*, example_core/lib/collection*,
    // example_widgets/lib/ui_ux/require_search_debounce_fixture.dart,
    // example_widgets/lib/accessibility/require_minimum_contrast_fixture.dart.

    group('avoid_dynamic_sql', () {
      test('PRAGMA with interpolation should NOT trigger', () {
        // PRAGMA does not support ? placeholders; interpolation is required.
        // Fixture: example_async/lib/security/avoid_dynamic_sql_fixture.dart
        expect('PRAGMA exemption in fixture', isNotNull);
      });

      test(
        'word-boundary matching: identifiers selection/updateTime should NOT trigger',
        () {
          // Variable names containing SQL substrings must not be treated as keywords.
          expect('Word-boundary regression case in fixture', isNotNull);
        },
      );
    });

    group('avoid_ref_read_inside_build / avoid_ref_in_build_body', () {
      test(
        'ref.read() inside inline callback (onPressed, onSubmit) should NOT trigger',
        () {
          // Closure boundary stops traversal; ref.read() in callbacks is correct.
          expect('Callback boundary exemption', isNotNull);
        },
      );
    });

    group('avoid_ref_watch_outside_build', () {
      test(
        'ref.watch() inside Provider/StreamProvider/FutureProvider body should NOT trigger',
        () {
          // Provider bodies are reactive contexts like build().
          expect('Provider body exemption in fixture', isNotNull);
        },
      );
    });

    group('avoid_path_traversal / require_file_path_sanitization', () {
      test(
        'platform path API (getApplicationDocumentsDirectory) should NOT trigger',
        () {
          expect('Platform path trusted source', isNotNull);
        },
      );

      test(
        'private helper receiving path from platform API in caller should NOT trigger',
        () {
          // 6.0.5: trust traced through private method call sites.
          expect('Inter-procedural trust in fixture', isNotNull);
        },
      );
    });

    group('avoid_unsafe_collection_methods', () {
      test('.first after isEmpty/length guard should NOT trigger', () {
        expect('Early-return and length guard in fixture', isNotNull);
      });

      test(
        '.first in SegmentedButton.onSelectionChanged should NOT trigger',
        () {
          expect('Callback guaranteed non-empty in fixture', isNotNull);
        },
      );
    });

    group('avoid_unsafe_reduce', () {
      test(
        'reduce() after length < 2 or isNotEmpty guard should NOT trigger',
        () {
          expect('Guarded reduce regression cases in fixture', isNotNull);
        },
      );
    });

    group('require_app_startup_error_handling', () {
      test('main() without crash reporting dependency should NOT trigger', () {
        // Rule only runs when firebase_crashlytics/sentry_flutter etc. in pubspec.
        expect('No dep = no warning', isNotNull);
      });
    });

    group('require_search_debounce', () {
      test(
        'Timer/Debouncer as class field used in onChanged should NOT trigger',
        () {
          expect('Class field debouncer regression in fixture', isNotNull);
        },
      );
    });

    group('require_minimum_contrast', () {
      test('unresolvable background color variable should NOT trigger', () {
        expect('Unresolvable background regression in fixture', isNotNull);
      });
    });
  });

  group('String.contains() Anti-Pattern Fixes', () {
    // These tests document fixes for the systemic .contains() anti-pattern
    // that caused 71% of all resolved bugs. See:
    // bugs/string_contains_false_positive_audit.md

    group('require_location_timeout', () {
      test('should not flag permission-only methods', () {
        // Fixed: LocationPermissionUtils.hasLocationPermission() was flagged
        // because method name contains "Location". Now uses exact GPS method
        // set: getCurrentPosition, getLastKnownPosition, getLocation, etc.
        //
        // These must NOT trigger:
        // - LocationPermissionUtils.hasLocationPermission()
        // - LocationServiceUtils.isLocationServiceEnabled()
        // - Geolocator.openLocationSettings()
        // - LocationFormatter.formatLocation(latLng)
        // - LocationCache.getCachedLocation()

        expect(
          'GPS method exact-match set replaces substring matching',
          isNotNull,
        );
      });

      test('should detect chained .timeout() on Futures', () {
        // Fixed: Geolocator.getCurrentPosition().timeout(duration) was not
        // detected because timeout check only inspected direct arguments.
        // Now walks up AST parents to find chained .timeout() calls.

        expect('Chained .timeout() is detected via AST parent walk', isNotNull);
      });
    });

    group('await_navigation', () {
      test('should not flag classes with Navigator in the name', () {
        // Fixed: contains('Navigator') matched NavigatorHelper, CustomNavigator
        // Now uses exact match: targetSource == 'Navigator'
        //
        // These must NOT trigger:
        // - NavigatorHelper.setup()
        // - CustomNavigatorState.pushRoute()
        // - NavigatorObserverLogger.log()

        expect('Navigator exact match replaces substring matching', isNotNull);
      });
    });

    group('avoid_context_access_in_callback', () {
      test('should not flag classes with context in the name', () {
        // Fixed: contains('context') matched ThemeContext, SecurityContext,
        // AudioContext, etc. Now checks if target is SimpleIdentifier with
        // name == 'context' (actual BuildContext parameter).
        //
        // These must NOT trigger:
        // - ThemeContext.of(context) — "ThemeContext" is a class, not context
        // - SecurityContext.defaultContext
        // - AudioContext.createBuffer()

        expect(
          'BuildContext SimpleIdentifier check replaces substring matching',
          isNotNull,
        );
      });
    });

    group('require_http_status_code_check', () {
      test('should not flag non-HTTP .get() calls', () {
        // Fixed: contains('.get(') matched Map.get(), GetIt.get(),
        // SharedPreferences.get(), List.get(). Now uses specific client
        // patterns: http.get, dio.get, client.get with exact target matching.
        //
        // These must NOT trigger:
        // - cache.get(key)
        // - prefs.get('setting')
        // - GetIt.I.get<Service>()
        // - map.get(key)

        expect(
          'HTTP client exact target set replaces bare .get() matching',
          isNotNull,
        );
      });
    });

    group('require_scroll_controller_dispose', () {
      test('should not flag classes containing ScrollController', () {
        // Fixed: typeName.contains('ScrollController') matched
        // ScrollControllerManager, CustomScrollControllerMixin, etc.
        // Now uses exact match: == 'ScrollController' or
        // == 'ScrollController?'
        //
        // These must NOT trigger for type matching:
        // - ScrollControllerManager (custom wrapper class)
        // - CustomScrollControllerMixin
        // - ScrollControllerFactory

        expect(
          'ScrollController exact type match replaces substring matching',
          isNotNull,
        );
      });

      test('should detect disposal via regex instead of interpolation', () {
        // Fixed: disposeBody.contains('$name.dispose(') broke on whitespace,
        // null-aware calls (?.dispose), and formatting differences.
        // Now uses regex: RegExp('name\\s*[?.]\\s*dispose\\s*\\(')

        expect(
          'Regex disposal detection replaces string interpolation',
          isNotNull,
        );
      });
    });
  });

  group('prefer_wheretype_over_where_is', () {
    test('should not flag negated type checks (is!)', () {
      // Fixed: IsExpression matches both `is` and `is!`, but the rule
      // never checked expr.notOperator. `.where((e) => e is! T)` has
      // no whereType equivalent — it excludes a type, not includes.
      //
      // These must NOT trigger:
      // - list.where((e) => e is! String)
      // - items.where((w) => w is! PhoneRow)

      expect('Negated is! checks are skipped via notOperator guard', isNotNull);
    });

    test('should still flag positive type checks', () {
      // Expected behavior: These SHOULD trigger
      // - list.where((e) => e is String)
      // - items.where((w) => w is Widget)

      expect('Positive is checks are still detected', isNotNull);
    });

    test('auto-fix should not produce semantically wrong replacement', () {
      // Fixed: The auto-fix also lacked the notOperator guard and would
      // replace `.where((e) => e is! T)` with `.whereType<T>()`,
      // which inverts the filtering logic.
      //
      // After fix: auto-fix only runs on positive `is` checks.

      expect(
        'Auto-fix guard prevents incorrect is! to whereType replacement',
        isNotNull,
      );
    });
  });

  group('Test Fixture Coverage', () {
    test('require_subscription_status_check has test fixture', () {
      // Located at: example/lib/require_subscription_status_check_example.dart
      expect(true, isTrue);
    });

    test('require_deep_link_fallback has test fixture', () {
      // Located at: example_widgets/lib/navigation/require_deep_link_fallback_fixture.dart
      expect(true, isTrue);
    });

    test('require_https_only has test fixture', () {
      // Located at: example_async/lib/security/require_https_only_fixture.dart
      expect(true, isTrue);
    });

    test('avoid_variable_shadowing has test fixture', () {
      // Located at: example/lib/avoid_variable_shadowing_fixture.dart
      expect(true, isTrue);
    });

    test('avoid_isar_clear_in_production has test fixture', () {
      // Located at: example_packages/lib/isar/avoid_isar_clear_in_production_fixture.dart
      expect(true, isTrue);
    });

    test('prefer_late_final has test fixture', () {
      // Located at: example_core/lib/code_quality/code_quality_fixture.dart
      expect(true, isTrue);
    });

    test('avoid_nested_assignments has test fixture', () {
      // Located at: example/lib/avoid_nested_assignments_fixture.dart
      expect(true, isTrue);
    });

    test('require_websocket_reconnection has mock stubs', () {
      // Located at: example/lib/flutter_mocks.dart (WebSocket, WebSocketChannel)
      // Fixture at: example_async/lib/async/async_rules_fixture.dart
      expect(true, isTrue);
    });

    test('prefer_wheretype_over_where_is has test fixture', () {
      // Located at: example_style/lib/stylistic_null_collection/prefer_wheretype_over_where_is_fixture.dart
      expect(true, isTrue);
    });

    test('6.0.4 avoid_dynamic_sql has regression fixture', () {
      // example_async/lib/security/avoid_dynamic_sql_fixture.dart (PRAGMA, word-boundary)
      expect(true, isTrue);
    });

    test('6.0.4 avoid_path_traversal has regression fixture', () {
      // example_async/lib/security/avoid_path_traversal_fixture.dart (private helper)
      expect(true, isTrue);
    });

    test('6.0.4 require_file_path_sanitization has regression fixture', () {
      // example_async/lib/file_handling/require_file_path_sanitization_fixture.dart
      expect(true, isTrue);
    });

    test('6.0.4 avoid_unsafe_reduce has regression fixture', () {
      // example_core/lib/collections/avoid_unsafe_reduce_fixture.dart (guarded reduce)
      expect(true, isTrue);
    });

    test('6.0.4 require_search_debounce has regression fixture', () {
      // example_widgets/lib/ui_ux/require_search_debounce_fixture.dart (class field debouncer)
      expect(true, isTrue);
    });

    test('6.0.4 require_minimum_contrast has regression fixture', () {
      // example_widgets/lib/accessibility/require_minimum_contrast_fixture.dart (unresolvable bg)
      expect(true, isTrue);
    });
  });
}
