import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_preferences.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({required this.strings, super.key});

  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(strings.settingsHelp),
          const SizedBox(height: 16),
          Text(strings.language),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'en', label: Text('English')),
              ButtonSegment(value: 'fr', label: Text('Français')),
            ],
            selected: {ref.watch(localeProvider).languageCode},
            onSelectionChanged: (value) => ref
                .read(localeProvider.notifier)
                .setLocale(Locale(value.first)),
          ),
          const SizedBox(height: 20),
          Text(strings.appearance),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                  value: ThemeMode.system, label: Text(strings.system)),
              ButtonSegment(value: ThemeMode.light, label: Text(strings.light)),
              ButtonSegment(value: ThemeMode.dark, label: Text(strings.dark)),
            ],
            selected: {ref.watch(themeModeProvider)},
            onSelectionChanged: (value) =>
                ref.read(themeModeProvider.notifier).setMode(value.first),
          ),
        ],
      );
}
