import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/localization/app_strings.dart';
import 'session_controller.dart';

class OrganizationScreen extends ConsumerWidget {
  const OrganizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final session = ref.watch(sessionControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(strings.chooseOrganization), actions: [
        TextButton(
            onPressed: () =>
                ref.read(sessionControllerProvider.notifier).logout(),
            child: Text(strings.signOut)),
      ]),
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          if (session.phase == SessionPhase.noOrganizations)
            Text(strings.noOrganizations),
          if (session.failure != null)
            Text(strings.failureMessage(session.failure!.kind)),
          for (final organization in session.organizations)
            Card(
                child: ListTile(
              title: Text(organization.name),
              subtitle: Text(organization.role),
              trailing: const Icon(Icons.chevron_right),
              enabled: !session.busy,
              onTap: () => ref
                  .read(sessionControllerProvider.notifier)
                  .selectOrganization(organization.id),
            )),
          const SizedBox(height: 16),
          OutlinedButton(
              onPressed: session.busy
                  ? null
                  : () => ref
                      .read(sessionControllerProvider.notifier)
                      .refreshOrganizations(),
              child: Text(strings.refreshAccess)),
        ]),
      ))),
    );
  }
}
