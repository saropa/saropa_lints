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
