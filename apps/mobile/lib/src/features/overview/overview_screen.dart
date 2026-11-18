import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/localization/app_strings.dart';
import '../../core/network/api_providers.dart';

class OverviewScreen extends ConsumerStatefulWidget {
  const OverviewScreen({required this.strings, super.key});

  final AppStrings strings;

  @override
  ConsumerState<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends ConsumerState<OverviewScreen> {
  bool _checking = false;
  bool? _reachable;

  Future<void> _checkApi() async {
    setState(() => _checking = true);
    bool reachable;
    try {
      reachable = await ref.read(statusClientProvider).isResponding();
    } catch (_) {
      reachable = false;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _reachable = reachable;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.strings.foundation),
            const SizedBox(height: 16),
            Text(widget.strings.noLiveData),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _checking ? null : _checkApi,
              child: Text(widget.strings.checkApi),
            ),
            if (_checking) const CircularProgressIndicator(),
            if (_reachable != null)
              Text(_reachable!
                  ? widget.strings.apiReachable
                  : widget.strings.apiUnavailable),
            Text(widget.strings.statusScope),
          ],
        ),
      );
}
