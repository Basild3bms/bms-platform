import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/localization/app_strings.dart';
import 'session_controller.dart';

class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final session = ref.watch(sessionControllerProvider);
    return Scaffold(
      body: SafeArea(
          child: Center(
              child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.apartment, size: 52),
          const SizedBox(height: 16),
          if (session.phase == SessionPhase.loading) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(strings.restoringSession),
          ] else ...[
            Text(strings.failureMessage(session.failure?.kind)),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: () =>
                    ref.read(sessionControllerProvider.notifier).restore(),
                child: Text(strings.retry)),
            const SizedBox(height: 8),
            TextButton(
                onPressed: () =>
                    ref.read(sessionControllerProvider.notifier).logout(),
                child: Text(strings.signOut)),
          ],
        ]),
      ))),
    );
  }
}
