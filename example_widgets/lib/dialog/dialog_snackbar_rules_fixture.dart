// ignore_for_file: unused_local_variable, unused_element, depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors
// Test fixture for dialog and snackbar rules (Plan Group D)

import 'package:saropa_lints_example/flutter_mocks.dart';

// =========================================================================
// require_snackbar_duration (D1)
// =========================================================================

class BadSnackbarWidget extends StatelessWidget {
  const BadSnackbarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          // expect_lint: require_snackbar_duration
          SnackBar(content: Text('Message')),
        );
      },
      child: Text('Show Snackbar'),
    );
  }
}

class GoodSnackbarWidget extends StatelessWidget {
  const GoodSnackbarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          // GOOD: Has explicit duration
          SnackBar(
            content: Text('Message'),
            duration: Duration(seconds: 4),
          ),
        );
      },
      child: Text('Show Snackbar'),
    );
  }
}

// =========================================================================
// require_dialog_barrier_dismissible (D2)
// =========================================================================

class BadDialogWidget extends StatelessWidget {
  const BadDialogWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        // expect_lint: require_dialog_barrier_dismissible
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Title'),
            content: Text('Content'),
          ),
        );
      },
      child: Text('Show Dialog'),
    );
  }
}

class GoodDialogWidget extends StatelessWidget {
  const GoodDialogWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        // GOOD: Has explicit barrierDismissible
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text('Title'),
            content: Text('Content'),
          ),
        );
      },
      child: Text('Show Dialog'),
    );
  }
}

// =========================================================================
// require_dialog_result_handling (D3)
// =========================================================================

class BadDialogResultWidget extends StatelessWidget {
  const BadDialogResultWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        // expect_lint: require_dialog_result_handling
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Confirm'),
              ),
            ],
          ),
        );
      },
      child: Text('Show Dialog'),
    );
  }
}

class GoodDialogResultWidget extends StatelessWidget {
  const GoodDialogResultWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        // GOOD: Result is awaited
        final result = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Confirm'),
              ),
            ],
          ),
        );
        if (result == true) {
          // Handle confirmation
        }
      },
      child: Text('Show Dialog'),
    );
  }
}

// =========================================================================
// avoid_snackbar_queue_buildup (D4)
// =========================================================================

class BadSnackbarQueueWidget extends StatelessWidget {
  const BadSnackbarQueueWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        // expect_lint: avoid_snackbar_queue_buildup
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New message'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Text('Show Snackbar'),
    );
  }
}

class GoodSnackbarQueueWidget extends StatelessWidget {
  const GoodSnackbarQueueWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        // GOOD: Clears previous snackbars first
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text('New message'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Text('Show Snackbar'),
    );
  }
}
