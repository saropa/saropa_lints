// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// Test fixture for: require_pagination_error_recovery

import 'package:saropa_lints_example/flutter_mocks.dart';

dynamic builder;
final items = <dynamic>[];
void loadMore() {}

// BAD: Pagination (loadMore) with no error recovery in scope — should trigger
// expect_lint: require_pagination_error_recovery
void _badPaginationNoRecovery() {
  ListView.builder(
    itemCount: items.length + 1,
    itemBuilder: (ctx, i) {
      if (i == items.length) return CircularProgressIndicator();
      if (i == items.length - 1) loadMore();
      return ItemTile(items[i]);
    },
  );
}

// GOOD: Pagination with error recovery (retry) in scope — should NOT trigger
void _goodPaginationWithRetry() {
  final hasError = false;
  ListView.builder(
    itemCount: items.length + (hasError ? 1 : 0) + 1,
    itemBuilder: (ctx, i) {
      if (hasError && i == items.length) {
        return TextButton(onPressed: loadMore, child: Text('Retry'));
      }
      if (i == items.length) return CircularProgressIndicator();
      if (i == items.length - 1) loadMore();
      return ItemTile(items[i]);
    },
  );
}
