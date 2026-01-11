// ignore_for_file: unused_local_variable, unused_element, depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors
// Test fixture for accessibility rules (Plan Group C)

import 'package:flutter/material.dart';

// =========================================================================
// require_avatar_alt_text (C1)
// =========================================================================

class BadAvatarWidget extends StatelessWidget {
  const BadAvatarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: require_avatar_alt_text
    return CircleAvatar(
      backgroundImage: NetworkImage('https://example.com/avatar.jpg'),
    );
  }
}

class GoodAvatarWidget extends StatelessWidget {
  const GoodAvatarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // GOOD: Has semanticLabel
    return CircleAvatar(
      backgroundImage: NetworkImage('https://example.com/avatar.jpg'),
      semanticLabel: 'User profile picture',
    );
  }
}

// =========================================================================
// require_badge_semantics (C2)
// =========================================================================

class BadBadgeWidget extends StatelessWidget {
  const BadBadgeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: require_badge_semantics
    return Badge(
      label: Text('5'),
      child: Icon(Icons.notifications),
    );
  }
}

class GoodBadgeWidget extends StatelessWidget {
  const GoodBadgeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // GOOD: Wrapped in Semantics
    return Semantics(
      label: '5 notifications',
      child: Badge(
        label: Text('5'),
        child: Icon(Icons.notifications),
      ),
    );
  }
}

// =========================================================================
// require_badge_count_limit (C3)
// =========================================================================

class BadBadgeCountWidget extends StatelessWidget {
  const BadBadgeCountWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '150 notifications',
      child: Badge(
        // expect_lint: require_badge_count_limit
        label: Text('150'),
        child: Icon(Icons.mail),
      ),
    );
  }
}

class GoodBadgeCountWidget extends StatelessWidget {
  const GoodBadgeCountWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // GOOD: Using 99+ pattern
    return Semantics(
      label: '99+ notifications',
      child: Badge(
        label: Text('99+'),
        child: Icon(Icons.mail),
      ),
    );
  }
}
