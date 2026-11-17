import 'package:material_ui/material_ui.dart';

import '../localization/app_strings.dart';

class UnavailableCard extends StatelessWidget {
  const UnavailableCard({required this.strings, super.key});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline),
              const SizedBox(height: 12),
              Text(strings.unavailable),
              const SizedBox(height: 8),
              Text(strings.futureFeature, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
