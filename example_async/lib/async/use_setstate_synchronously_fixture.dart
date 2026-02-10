// ignore_for_file: unused_local_variable, unused_element, depend_on_referenced_packages
// ignore_for_file: unused_field
// Test fixture for use_setstate_synchronously rule

import 'package:saropa_lints_example/flutter_mocks.dart';

// =========================================================================
// use_setstate_synchronously
// =========================================================================
// Warns when setState is called after an async gap without mounted check.

// BAD: setState after await without mounted check
class BadSetStateAfterAwait extends StatefulWidget {
  const BadSetStateAfterAwait({super.key});

  @override
  State<BadSetStateAfterAwait> createState() => _BadSetStateAfterAwaitState();
}

class _BadSetStateAfterAwaitState extends State<BadSetStateAfterAwait> {
  String _data = '';

  Future<void> loadData() async {
    final data = await Future.value('data');
    // expect_lint: use_setstate_synchronously
    setState(() => _data = data);
  }

  @override
  Widget build(BuildContext context) => Text(_data);
}

// GOOD: setState after await WITH mounted check (if statement)
class GoodSetStateWithMountedCheck extends StatefulWidget {
  const GoodSetStateWithMountedCheck({super.key});

  @override
  State<GoodSetStateWithMountedCheck> createState() =>
      _GoodSetStateWithMountedCheckState();
}

class _GoodSetStateWithMountedCheckState
    extends State<GoodSetStateWithMountedCheck> {
  String _data = '';

  Future<void> loadData() async {
    final data = await Future.value('data');
    if (mounted) {
      setState(() => _data = data); // Protected by if (mounted)
    }
  }

  @override
  Widget build(BuildContext context) => Text(_data);
}

// GOOD: setState after await WITH negated guard (if (!mounted) return)
class GoodSetStateWithNegatedGuard extends StatefulWidget {
  const GoodSetStateWithNegatedGuard({super.key});

  @override
  State<GoodSetStateWithNegatedGuard> createState() =>
      _GoodSetStateWithNegatedGuardState();
}

class _GoodSetStateWithNegatedGuardState
    extends State<GoodSetStateWithNegatedGuard> {
  String _data = '';

  Future<void> loadData() async {
    final data = await Future.value('data');
    if (!mounted) return; // Guard pattern
    setState(() => _data = data); // Protected by guard above
  }

  @override
  Widget build(BuildContext context) => Text(_data);
}

// GOOD: setState after await WITH negated guard (if (!mounted) throw)
class GoodSetStateWithNegatedGuardThrow extends StatefulWidget {
  const GoodSetStateWithNegatedGuardThrow({super.key});

  @override
  State<GoodSetStateWithNegatedGuardThrow> createState() =>
      _GoodSetStateWithNegatedGuardThrowState();
}

class _GoodSetStateWithNegatedGuardThrowState
    extends State<GoodSetStateWithNegatedGuardThrow> {
  String _data = '';

  Future<void> loadData() async {
    final data = await Future.value('data');
    if (!mounted) {
      throw StateError('Widget disposed');
    }
    setState(() => _data = data); // Protected by guard above
  }

  @override
  Widget build(BuildContext context) => Text(_data);
}

// GOOD: Nested mounted check (if (mounted) { ... setState ... })
class GoodSetStateNestedMountedCheck extends StatefulWidget {
  const GoodSetStateNestedMountedCheck({super.key});

  @override
  State<GoodSetStateNestedMountedCheck> createState() =>
      _GoodSetStateNestedMountedCheckState();
}

class _GoodSetStateNestedMountedCheckState
    extends State<GoodSetStateNestedMountedCheck> {
  String _data = '';
  bool _isLoading = false;

  Future<void> loadData() async {
    final data = await Future.value('data');
    if (mounted) {
      _isLoading = false;
      setState(() => _data = data); // Nested inside if (mounted)
    }
  }

  @override
  Widget build(BuildContext context) => Text(_data);
}

// GOOD: setState inside try block with mounted check
class GoodSetStateInTryWithMountedCheck extends StatefulWidget {
  const GoodSetStateInTryWithMountedCheck({super.key});

  @override
  State<GoodSetStateInTryWithMountedCheck> createState() =>
      _GoodSetStateInTryWithMountedCheckState();
}

class _GoodSetStateInTryWithMountedCheckState
    extends State<GoodSetStateInTryWithMountedCheck> {
  String _data = '';

  Future<void> loadData() async {
    try {
      final data = await Future.value('data');
      if (mounted) {
        setState(() => _data = data); // Protected
      }
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) => Text(_data);
}

// BAD: setState in try block without mounted check
class BadSetStateInTryWithoutMountedCheck extends StatefulWidget {
  const BadSetStateInTryWithoutMountedCheck({super.key});

  @override
  State<BadSetStateInTryWithoutMountedCheck> createState() =>
      _BadSetStateInTryWithoutMountedCheckState();
}

class _BadSetStateInTryWithoutMountedCheckState
    extends State<BadSetStateInTryWithoutMountedCheck> {
  String _data = '';

  Future<void> loadData() async {
    try {
      final data = await Future.value('data');
      // expect_lint: use_setstate_synchronously
      setState(() => _data = data); // Not protected!
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) => Text(_data);
}

// GOOD: this.mounted check
class GoodSetStateWithThisMounted extends StatefulWidget {
  const GoodSetStateWithThisMounted({super.key});

  @override
  State<GoodSetStateWithThisMounted> createState() =>
      _GoodSetStateWithThisMountedState();
}

class _GoodSetStateWithThisMountedState
    extends State<GoodSetStateWithThisMounted> {
  String _data = '';

  Future<void> loadData() async {
    final data = await Future.value('data');
    if (this.mounted) {
      setState(() => _data = data); // Protected by this.mounted
    }
  }

  @override
  Widget build(BuildContext context) => Text(_data);
}

// BAD: Multiple awaits - need guard after EACH await
class BadMultipleAwaitsPartialGuard extends StatefulWidget {
  const BadMultipleAwaitsPartialGuard({super.key});

  @override
  State<BadMultipleAwaitsPartialGuard> createState() =>
      _BadMultipleAwaitsPartialGuardState();
}

class _BadMultipleAwaitsPartialGuardState
    extends State<BadMultipleAwaitsPartialGuard> {
  String _data1 = '';
  String _data2 = '';

  Future<void> loadData() async {
    final data1 = await Future.value('data1');
    if (!mounted) return;
    setState(() => _data1 = data1); // Protected

    final data2 = await Future.value('data2'); // Second await resets protection
    // expect_lint: use_setstate_synchronously
    setState(() => _data2 = data2); // NOT protected! Need another guard
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [Text(_data1), Text(_data2)],
      );
}

// GOOD: Multiple awaits with guard after each
class GoodMultipleAwaitsWithGuards extends StatefulWidget {
  const GoodMultipleAwaitsWithGuards({super.key});

  @override
  State<GoodMultipleAwaitsWithGuards> createState() =>
      _GoodMultipleAwaitsWithGuardsState();
}

class _GoodMultipleAwaitsWithGuardsState
    extends State<GoodMultipleAwaitsWithGuards> {
  String _data1 = '';
  String _data2 = '';

  Future<void> loadData() async {
    final data1 = await Future.value('data1');
    if (!mounted) return;
    setState(() => _data1 = data1); // Protected

    final data2 = await Future.value('data2');
    if (!mounted) return; // Guard after second await
    setState(() => _data2 = data2); // Protected
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [Text(_data1), Text(_data2)],
      );
}

// =========================================================================
// Compound && mounted checks
// =========================================================================
// Short-circuit evaluation guarantees mounted is true in the then-branch.

// GOOD: Compound && with mounted on left side
class GoodCompoundMountedLeft extends StatefulWidget {
  const GoodCompoundMountedLeft({super.key});

  @override
  State<GoodCompoundMountedLeft> createState() =>
      _GoodCompoundMountedLeftState();
}

class _GoodCompoundMountedLeftState extends State<GoodCompoundMountedLeft> {
  String _data = '';
  bool _shouldUpdate = true;

  Future<void> loadData() async {
    final data = await Future.value('data');
    if (mounted && _shouldUpdate) {
      setState(() => _data = data); // Protected - mounted checked in &&
    }
  }

  @override
  Widget build(BuildContext context) => Text(_data);
}

// GOOD: Compound && with mounted on right side
class GoodCompoundMountedRight extends StatefulWidget {
  const GoodCompoundMountedRight({super.key});

  @override
  State<GoodCompoundMountedRight> createState() =>
      _GoodCompoundMountedRightState();
}

class _GoodCompoundMountedRightState extends State<GoodCompoundMountedRight> {
  String _data = '';
  bool _isActive = true;

  Future<void> loadData() async {
    final data = await Future.value('data');
    if (_isActive && mounted) {
      setState(() => _data = data); // Protected - mounted checked in &&
    }
  }

  @override
  Widget build(BuildContext context) => Text(_data);
}

// GOOD: Compound && with context.mounted
class GoodCompoundContextMounted extends StatefulWidget {
  const GoodCompoundContextMounted({super.key});

  @override
  State<GoodCompoundContextMounted> createState() =>
      _GoodCompoundContextMountedState();
}

class _GoodCompoundContextMountedState
    extends State<GoodCompoundContextMounted> {
  String _data = '';
  bool _canUpdate = true;

  Future<void> loadData() async {
    final data = await Future.value('data');
    if (context.mounted && _canUpdate) {
      setState(() => _data = data); // Protected - context.mounted in &&
    }
  }

  @override
  Widget build(BuildContext context) => Text(_data);
}

// GOOD: Double mounted check in && (redundant but valid)
class GoodDoubleMountedCheck extends StatefulWidget {
  const GoodDoubleMountedCheck({super.key});

  @override
  State<GoodDoubleMountedCheck> createState() => _GoodDoubleMountedCheckState();
}

class _GoodDoubleMountedCheckState extends State<GoodDoubleMountedCheck> {
  String _data = '';

  Future<void> loadData() async {
    final data = await Future.value('data');
    if (mounted && context.mounted) {
      setState(() => _data = data); // Protected - both checked
    }
  }

  @override
  Widget build(BuildContext context) => Text(_data);
}

// =========================================================================
// check_mounted_after_async - await showDialog false positive fix
// =========================================================================
// When showDialog IS the awaited expression (await showDialog(...)), its own
// await keyword should not count as a "preceding await". Only a separate
// earlier await creates an async gap that needs a mounted guard.

// GOOD: await showDialog() as the only await - no preceding async gap
class GoodAwaitShowDialogOnly extends StatefulWidget {
  const GoodAwaitShowDialogOnly({super.key});

  @override
  State<GoodAwaitShowDialogOnly> createState() =>
      _GoodAwaitShowDialogOnlyState();
}

class _GoodAwaitShowDialogOnlyState extends State<GoodAwaitShowDialogOnly> {
  Future<void> openDialog() async {
    await showDialog(
      context: context,
      builder: (_) => const Text('dialog'),
    ); // No preceding await - should NOT trigger
  }

  @override
  Widget build(BuildContext context) => const Text('test');
}

// BAD: showDialog after a separate await without mounted check
class BadShowDialogAfterAwait extends StatefulWidget {
  const BadShowDialogAfterAwait({super.key});

  @override
  State<BadShowDialogAfterAwait> createState() =>
      _BadShowDialogAfterAwaitState();
}

class _BadShowDialogAfterAwaitState extends State<BadShowDialogAfterAwait> {
  Future<void> loadAndShowDialog() async {
    await Future.value('data');
    // expect_lint: check_mounted_after_async
    showDialog(
      context: context,
      builder: (_) => const Text('dialog'),
    ); // Preceded by a different await - SHOULD trigger
  }

  @override
  Widget build(BuildContext context) => const Text('test');
}

// BAD: await showDialog after a separate await without mounted check
class BadAwaitShowDialogAfterAwait extends StatefulWidget {
  const BadAwaitShowDialogAfterAwait({super.key});

  @override
  State<BadAwaitShowDialogAfterAwait> createState() =>
      _BadAwaitShowDialogAfterAwaitState();
}

class _BadAwaitShowDialogAfterAwaitState
    extends State<BadAwaitShowDialogAfterAwait> {
  Future<void> loadAndShowDialog() async {
    await Future.value('data');
    // expect_lint: check_mounted_after_async
    await showDialog(
      context: context,
      builder: (_) => const Text('dialog'),
    ); // Preceded by a different await - SHOULD trigger even though also awaited
  }

  @override
  Widget build(BuildContext context) => const Text('test');
}

// GOOD: showDialog after await WITH mounted check
class GoodShowDialogAfterAwaitWithGuard extends StatefulWidget {
  const GoodShowDialogAfterAwaitWithGuard({super.key});

  @override
  State<GoodShowDialogAfterAwaitWithGuard> createState() =>
      _GoodShowDialogAfterAwaitWithGuardState();
}

class _GoodShowDialogAfterAwaitWithGuardState
    extends State<GoodShowDialogAfterAwaitWithGuard> {
  Future<void> loadAndShowDialog() async {
    await Future.value('data');
    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => const Text('dialog'),
      ); // Protected by mounted check
    }
  }

  @override
  Widget build(BuildContext context) => const Text('test');
}
