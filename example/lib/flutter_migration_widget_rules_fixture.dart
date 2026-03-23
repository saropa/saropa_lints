// ignore_for_file: unused_element, prefer_super_parameters
// prefer_super_parameters: BAD cases below intentionally use explicit super(key: key).

import 'flutter_mocks.dart';

// =============================================================================
// prefer_super_key
// =============================================================================

class BadSuperKeyWidget extends StatelessWidget {
  // LINT: Use super.key instead of Key? key + super(key: key)
  const BadSuperKeyWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class GoodSuperKeyWidget extends StatelessWidget {
  const GoodSuperKeyWidget({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class GoodValueKeyWidget extends StatelessWidget {
  // OK: Parameter type is not Key — rule requires NamedType Key exactly.
  const GoodValueKeyWidget({ValueKey<String>? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// =============================================================================
// avoid_chip_delete_inkwell_circle_border
// =============================================================================

Widget badChipDeleteInkWell() {
  // LINT: Circular customBorder on delete InkWell mismatches square chip delete
  return InputChip(
    label: const Text('x'),
    onDeleted: () {},
    deleteIcon: InkWell(
      customBorder: const CircleBorder(),
      onTap: () {},
      child: const Icon(Icons.close),
    ),
  );
}

Widget goodChipDelete() {
  return InputChip(
    label: const Text('x'),
    onDeleted: () {},
    deleteIcon: const Icon(Icons.close),
  );
}

Widget goodChipDeleteNonCircleBorder() {
  return RawChip(
    label: const Text('y'),
    deleteIcon: InkWell(
      onTap: () {},
      child: const Icon(Icons.close),
    ),
  );
}

// -----------------------------------------------------------------------------
// prefer_image_filter_quality_medium (Flutter SDK projects)
// -----------------------------------------------------------------------------
// Real apps: rule flags package:flutter Image / RawImage / FadeInImage /
// DecorationImage with filterQuality: FilterQuality.low (Flutter 3.24+ PR
// #148799). This package mocks Widget types (not package:flutter), so
// // LINT fixtures would not fire. See test/image_filter_quality_detection_test.dart
// and lib/src/rules/widget/image_filter_quality_migration_rules.dart.
