import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/localization/app_strings.dart';
import '../../core/routing/app_router.dart';
import '../../core/widgets/unavailable_card.dart';
import '../overview/overview_screen.dart';
import '../settings/settings_screen.dart';

class SectionScreen extends StatelessWidget {
  const SectionScreen({required this.section, super.key});

  final String section;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.section(section))),
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
          'settings' => SettingsScreen(strings: strings),
          _ => Center(child: UnavailableCard(strings: strings)),
        },
      ),
    );
  }
}
