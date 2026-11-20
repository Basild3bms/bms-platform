import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/localization/app_strings.dart';
import '../../core/routing/app_router.dart';
import '../../core/widgets/unavailable_card.dart';
import '../overview/overview_screen.dart';
import '../settings/settings_screen.dart';
import '../auth/session_controller.dart';
import '../buildings/buildings_screen.dart';
import '../equipment/equipment_building_screen.dart';

class SectionScreen extends ConsumerWidget {
  const SectionScreen({required this.section, super.key});

  final String section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final organization = ref.watch(sessionControllerProvider).organization;
    return Scaffold(
      appBar: AppBar(title: Text(strings.section(section)), actions: [
        if (organization != null) Center(child: Text(organization.name)),
        IconButton(
          tooltip: strings.switchOrganization,
          onPressed: () => ref
              .read(sessionControllerProvider.notifier)
              .chooseAnotherOrganization(),
          icon: const Icon(Icons.swap_horiz),
        ),
      ]),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              const DrawerHeader(child: Center(child: Text('BMS'))),
              for (final item in sections)
                ListTile(
                  title: Text(strings.section(item)),
                  selected: item == section,
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go('/$item');
                  },
                ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: switch (section) {
          'overview' => OverviewScreen(strings: strings),
          'buildings' => const BuildingsScreen(),
          'equipment' => const EquipmentBuildingScreen(),
          'settings' => SettingsScreen(strings: strings),
          _ => Center(child: UnavailableCard(strings: strings)),
        },
      ),
    );
  }
}
