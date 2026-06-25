// ignore_for_file: unused_element
// Test fixture for: avoid_animated_size_in_wrap
// BAD: AnimatedSize as a direct child of Wrap/Flow (re-dirties itself during
//      the parent layout pass and throws at runtime once its size animates).
// GOOD: Column/ListView lay each child out once; a bounded box between the Wrap
//       and the AnimatedSize is the valid escape hatch.
import 'package:flutter/material.dart';

const Duration _d = Duration(milliseconds: 200);

// BAD: AnimatedSize directly in Wrap(children: [...]).
class BadAnimatedSizeInWrap extends StatelessWidget {
  const BadAnimatedSizeInWrap({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: <Widget>[
        // expect_lint: avoid_animated_size_in_wrap
        AnimatedSize(duration: _d, child: const Placeholder()),
      ],
    );
  }
}

// BAD: AnimatedSize produced by a ForElement inside Wrap.children.
class BadAnimatedSizeInWrapForElement extends StatelessWidget {
  const BadAnimatedSizeInWrapForElement({super.key, required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: <Widget>[
        for (final Widget card in cards)
          // expect_lint: avoid_animated_size_in_wrap
          AnimatedSize(duration: _d, child: card),
      ],
    );
  }
}

// BAD: AnimatedSize directly in Flow(children: [...]) — same layout pattern.
class BadAnimatedSizeInFlow extends StatelessWidget {
  const BadAnimatedSizeInFlow({super.key, required this.delegate});

  final FlowDelegate delegate;

  @override
  Widget build(BuildContext context) {
    return Flow(
      delegate: delegate,
      children: <Widget>[
        // expect_lint: avoid_animated_size_in_wrap
        AnimatedSize(duration: _d, child: const Placeholder()),
      ],
    );
  }
}

// GOOD: Column lays each child out exactly once — the restart defers a frame.
class OkAnimatedSizeInColumn extends StatelessWidget {
  const OkAnimatedSizeInColumn({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        AnimatedSize(duration: _d, child: const Placeholder()),
      ],
    );
  }
}

// GOOD: ListView is a safe parent for AnimatedSize.
class OkAnimatedSizeInListView extends StatelessWidget {
  const OkAnimatedSizeInListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        AnimatedSize(duration: _d, child: const Placeholder()),
      ],
    );
  }
}

// GOOD: a bounded box between Wrap and AnimatedSize fixes the crash — the
// intervening widget is the documented escape hatch, so no lint.
class OkAnimatedSizeBoundedInWrap extends StatelessWidget {
  const OkAnimatedSizeBoundedInWrap({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: <Widget>[
        SizedBox(
          width: 100,
          child: AnimatedSize(duration: _d, child: const Placeholder()),
        ),
      ],
    );
  }
}
