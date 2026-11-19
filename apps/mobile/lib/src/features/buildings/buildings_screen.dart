import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/localization/app_strings.dart';
import 'building_models.dart';
import 'buildings_controller.dart';

class BuildingsScreen extends ConsumerStatefulWidget {
  const BuildingsScreen({super.key});

  @override
  ConsumerState<BuildingsScreen> createState() => _BuildingsScreenState();
}

class _BuildingsScreenState extends ConsumerState<BuildingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(buildingsControllerProvider.notifier).loadFirstPage();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final state = ref.watch(buildingsControllerProvider);
    final controller = ref.read(buildingsControllerProvider.notifier);
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (state.listPhase == BuildingListPhase.idle ||
              state.listPhase == BuildingListPhase.loading)
            _Message(strings.loadingBuildings, loading: true),
          if (state.listPhase == BuildingListPhase.empty)
            _Message(strings.noBuildings),
          if (state.listPhase == BuildingListPhase.error) ...[
            _Message(strings.buildingFailureMessage(state.listFailure)),
            Center(
                child: TextButton(
                    onPressed: controller.loadFirstPage,
                    child: Text(strings.retry))),
          ],
          for (final building in state.records)
            _BuildingTile(building: building, strings: strings),
          if (state.listPhase == BuildingListPhase.ready &&
              state.listFailure != null)
            _Message(strings.buildingFailureMessage(state.listFailure)),
          if (state.listPhase == BuildingListPhase.ready && state.hasMore)
            Center(
              child: state.loadingMore
                  ? const CircularProgressIndicator()
                  : TextButton(
                      onPressed: controller.loadMore,
                      child: Text(strings.loadMore)),
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.message, {this.loading = false});
  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
            child: Column(children: [
          if (loading) const CircularProgressIndicator(),
          if (loading) const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
        ])),
      );
}

class _BuildingTile extends StatelessWidget {
  const _BuildingTile({required this.building, required this.strings});
  final BuildingRecord building;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(building.name),
        subtitle: Text([
          building.code,
          if (building.address?.isNotEmpty == true) building.address!,
          building.timezone,
        ].join(' · ')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            context.push('/buildings/${Uri.encodeComponent(building.id)}'),
      );
}
