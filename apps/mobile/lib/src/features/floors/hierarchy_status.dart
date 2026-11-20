import 'package:material_ui/material_ui.dart';

import '../../core/localization/app_strings.dart';

class HierarchyStatus extends StatelessWidget {
  const HierarchyStatus(this.message,
      {this.loading = false, this.onRetry, this.retryLabel, super.key});
  final String message;
  final bool loading;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (loading) const CircularProgressIndicator(),
        if (loading) const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center),
        if (onRetry != null)
          TextButton(
              onPressed: onRetry,
              child: Text(retryLabel ?? AppStrings.of(context).retry)),
      ])));
}
