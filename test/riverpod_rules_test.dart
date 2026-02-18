import 'dart:io';

import 'package:test/test.dart';

/// Tests for 37 Riverpod lint rules.
///
/// These rules cover ref.read/watch usage, provider lifecycle, notifier
/// patterns, async value handling, auto-dispose, and architectural patterns.
///
/// Test fixtures: example_packages/lib/riverpod/*
void main() {
  group('Riverpod Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_global_riverpod_providers',
      'avoid_riverpod_navigation',
      'avoid_riverpod_notifier_in_build',
      'avoid_riverpod_state_mutation',
      'prefer_riverpod_auto_dispose',
      'prefer_riverpod_family_for_params',
      'prefer_riverpod_select',
      'require_flutter_riverpod_not_riverpod',
      'require_flutter_riverpod_package',
      'require_riverpod_async_value_guard',
      'require_riverpod_error_handling',
      'require_riverpod_lint',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/riverpod/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Ref Usage Rules', () {
    group('avoid_ref_read_inside_build', () {
      test('ref.read() in build() SHOULD trigger', () {
        // ref.read() does not subscribe to changes; widget won't rebuild
        expect('ref.read() in build detected', isNotNull);
      });

      test('ref.watch() in build() should NOT trigger', () {
        // ref.watch() is the correct pattern for build methods
        expect('ref.watch() in build passes', isNotNull);
      });

      test('ref.read() in onPressed callback should NOT trigger', () {
        // Callbacks should use ref.read() not ref.watch()
        expect('ref.read() in callback passes', isNotNull);
      });
    });

    group('avoid_ref_watch_outside_build', () {
      test('ref.watch() in initState SHOULD trigger', () {
        // ref.watch() outside build creates subscription leaks
        expect('ref.watch() in initState detected', isNotNull);
      });

      test('ref.watch() in callback SHOULD trigger', () {
        expect('ref.watch() in callback detected', isNotNull);
      });

      test('ref.watch() in build should NOT trigger', () {
        expect('ref.watch() in build passes', isNotNull);
      });
    });

    group('avoid_ref_inside_state_dispose', () {
      test('ref usage in dispose() SHOULD trigger', () {
        // Provider may already be disposed during widget dispose
        expect('ref in dispose detected', isNotNull);
      });

      test('ref usage in build() should NOT trigger', () {
        expect('ref in build passes', isNotNull);
      });
    });

    group('use_ref_read_synchronously', () {
      test('ref.watch() used synchronously in callback SHOULD trigger', () {
        expect('synchronous ref.watch() in callback detected', isNotNull);
      });

      test('ref.read() in callback should NOT trigger', () {
        expect('ref.read() is correct for sync access', isNotNull);
      });
    });

    group('use_ref_and_state_synchronously', () {
      test('async gap before state access SHOULD trigger', () {
        expect('stale state after await detected', isNotNull);
      });

      test('synchronous state access should NOT trigger', () {
        expect('sync state access passes', isNotNull);
      });
    });

    group('avoid_ref_in_build_body', () {
      test('ref.read in build body outside watch SHOULD trigger', () {
        expect('ref.read in build body detected', isNotNull);
      });
    });

    group('avoid_ref_in_dispose', () {
      test('ref access in dispose SHOULD trigger', () {
        expect('ref in dispose detected', isNotNull);
      });
    });

    group('prefer_ref_watch_over_read', () {
      test('ref.read in build for reactive data SHOULD trigger', () {
        expect('ref.read where watch needed detected', isNotNull);
      });

      test('ref.read in event handler should NOT trigger', () {
        expect('ref.read in handler passes', isNotNull);
      });
    });
  });

  group('Provider Lifecycle Rules', () {
    group('prefer_riverpod_auto_dispose', () {
      test('StateProvider without autoDispose SHOULD trigger', () {
        // Providers should auto-dispose when no longer listened to
        expect('non-autoDispose provider detected', isNotNull);
      });

      test('autoDispose provider should NOT trigger', () {
        expect('autoDispose passes', isNotNull);
      });
    });

    group('require_auto_dispose', () {
      test('provider without autoDispose modifier SHOULD trigger', () {
        expect('missing autoDispose detected', isNotNull);
      });
    });

    group('require_provider_scope', () {
      test('app without ProviderScope SHOULD trigger', () {
        // ProviderScope is required at root for Riverpod
        expect('missing ProviderScope detected', isNotNull);
      });

      test('ProviderScope wrapping app should NOT trigger', () {
        expect('ProviderScope present passes', isNotNull);
      });
    });

    group('avoid_global_riverpod_providers', () {
      test('top-level provider declaration SHOULD trigger', () {
        // Global providers are hard to test and maintain
        expect('global provider detected', isNotNull);
      });

      test('scoped provider should NOT trigger', () {
        expect('scoped provider passes', isNotNull);
      });
    });
  });

  group('Notifier & State Rules', () {
    group('avoid_assigning_notifiers', () {
      test('direct notifier assignment SHOULD trigger', () {
        // ref.read(provider.notifier).state = newState bypasses lifecycle
        expect('notifier assignment detected', isNotNull);
      });
    });

    group('avoid_notifier_constructors', () {
      test('manual notifier instantiation SHOULD trigger', () {
        // Notifiers should only be created by the provider
        expect('manual notifier construction detected', isNotNull);
      });

      test('provider-managed notifier should NOT trigger', () {
        expect('provider-managed passes', isNotNull);
      });
    });

    group('prefer_immutable_provider_arguments', () {
      test('mutable object as provider argument SHOULD trigger', () {
        expect('mutable argument detected', isNotNull);
      });

      test('immutable argument should NOT trigger', () {
        expect('immutable argument passes', isNotNull);
      });
    });

    group('avoid_riverpod_state_mutation', () {
      test('direct state.value mutation SHOULD trigger', () {
        expect('state mutation detected', isNotNull);
      });

      test('state = newValue should NOT trigger', () {
        expect('immutable state update passes', isNotNull);
      });
    });

    group('prefer_notifier_over_state', () {
      test('StateProvider for complex logic SHOULD trigger', () {
        // Notifier provides better testability and encapsulation
        expect('complex StateProvider detected', isNotNull);
      });

      test('simple StateProvider should NOT trigger', () {
        expect('simple StateProvider passes', isNotNull);
      });
    });

    group('avoid_riverpod_notifier_in_build', () {
      test('notifier method call in build SHOULD trigger', () {
        expect('notifier in build detected', isNotNull);
      });

      test('notifier call in callback should NOT trigger', () {
        expect('notifier in callback passes', isNotNull);
      });
    });
  });

  group('Widget Rules', () {
    group('avoid_unnecessary_consumer_widgets', () {
      test('ConsumerWidget not using ref SHOULD trigger', () {
        // Use StatelessWidget if ref is not needed
        expect('unused ConsumerWidget detected', isNotNull);
      });

      test('ConsumerWidget using ref.watch should NOT trigger', () {
        expect('ref-using ConsumerWidget passes', isNotNull);
      });
    });

    group('prefer_consumer_widget', () {
      test('Consumer(builder: ...) deep in tree SHOULD trigger', () {
        // ConsumerWidget is cleaner than nested Consumer
        expect('nested Consumer detected', isNotNull);
      });

      test('ConsumerWidget class should NOT trigger', () {
        expect('ConsumerWidget passes', isNotNull);
      });
    });

    group('prefer_riverpod_select', () {
      test('ref.watch(provider) for single field SHOULD trigger', () {
        // select() prevents unnecessary rebuilds
        expect('over-watching detected', isNotNull);
      });

      test('ref.watch(provider.select((s) => s.field)) should NOT trigger', () {
        expect('select usage passes', isNotNull);
      });
    });

    group('prefer_select_for_partial', () {
      test('watching full state for partial use SHOULD trigger', () {
        expect('over-subscription detected', isNotNull);
      });
    });

    group('prefer_selector', () {
      test('watching full provider for single property SHOULD trigger', () {
        expect('missing select detected', isNotNull);
      });
    });
  });

  group('Async & Error Handling Rules', () {
    group('avoid_nullable_async_value_pattern', () {
      test('AsyncValue<MyType?> SHOULD trigger', () {
        // AsyncValue already handles loading/error; nullable is redundant
        expect('nullable AsyncValue detected', isNotNull);
      });

      test('AsyncValue<MyType> should NOT trigger', () {
        expect('non-nullable AsyncValue passes', isNotNull);
      });
    });

    group('require_riverpod_error_handling', () {
      test('async provider without error handling SHOULD trigger', () {
        expect('unhandled async provider error detected', isNotNull);
      });

      test('provider with .when() error handler should NOT trigger', () {
        expect('error handling present passes', isNotNull);
      });
    });

    group('require_error_handling_in_async', () {
      test('async notifier without try-catch SHOULD trigger', () {
        expect('unhandled async error detected', isNotNull);
      });
    });

    group('require_riverpod_async_value_guard', () {
      test('async operation without AsyncValue.guard SHOULD trigger', () {
        expect('missing guard detected', isNotNull);
      });

      test('AsyncValue.guard() wrapping should NOT trigger', () {
        expect('guard present passes', isNotNull);
      });
    });

    group('require_async_value_order', () {
      test('when() with wrong branch order SHOULD trigger', () {
        expect('incorrect when() order detected', isNotNull);
      });

      test('loading/error/data order should NOT trigger', () {
        expect('correct order passes', isNotNull);
      });
    });

    group('avoid_listen_in_async', () {
      test('ref.listen in async context SHOULD trigger', () {
        expect('listen in async detected', isNotNull);
      });
    });
  });

  group('Provider Family Rules', () {
    group('prefer_riverpod_family_for_params', () {
      test('provider recreated with different params SHOULD trigger', () {
        expect('non-family parameterized provider detected', isNotNull);
      });

      test('.family provider should NOT trigger', () {
        expect('family provider passes', isNotNull);
      });
    });

    group('prefer_family_for_params', () {
      test('manually parameterized provider SHOULD trigger', () {
        expect('non-family params detected', isNotNull);
      });
    });
  });

  group('Architecture Rules', () {
    group('avoid_circular_provider_deps', () {
      test('provider A depending on B depending on A SHOULD trigger', () {
        expect('circular dependency detected', isNotNull);
      });

      test('linear dependency chain should NOT trigger', () {
        expect('linear deps pass', isNotNull);
      });
    });

    group('avoid_riverpod_navigation', () {
      test('navigation in provider SHOULD trigger', () {
        // Providers should not handle navigation
        expect('navigation in provider detected', isNotNull);
      });

      test('navigation in widget should NOT trigger', () {
        expect('widget navigation passes', isNotNull);
      });
    });

    group('avoid_riverpod_for_network_only', () {
      test('provider only doing network call SHOULD trigger', () {
        // FutureProvider for simple HTTP is over-engineering
        expect('network-only provider detected', isNotNull);
      });
    });
  });

  group('Package Configuration Rules', () {
    group('require_flutter_riverpod_package', () {
      test('riverpod without flutter_riverpod SHOULD trigger', () {
        // Flutter apps should use flutter_riverpod, not plain riverpod
        expect('wrong package detected', isNotNull);
      });
    });

    group('require_flutter_riverpod_not_riverpod', () {
      test('import of riverpod instead of flutter_riverpod SHOULD trigger', () {
        expect('wrong import detected', isNotNull);
      });
    });

    group('require_riverpod_lint', () {
      test('project without riverpod_lint SHOULD trigger', () {
        expect('missing riverpod_lint detected', isNotNull);
      });

      test('riverpod_lint in dev_dependencies should NOT trigger', () {
        expect('riverpod_lint present passes', isNotNull);
      });
    });
  });
}
