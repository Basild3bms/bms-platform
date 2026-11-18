import 'package:material_ui/material_ui.dart';

import '../../core/localization/app_strings.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({required this.strings, super.key});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(strings.foundation),
            const SizedBox(height: 16),
            Text(strings.noLiveData),
          ],
        ),
      );
}
