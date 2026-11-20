import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/localization/app_strings.dart';
import '../buildings/buildings_controller.dart';
import '../floors/hierarchy_status.dart';

class EquipmentBuildingScreen extends ConsumerStatefulWidget {
  const EquipmentBuildingScreen({super.key});
  @override
  ConsumerState<EquipmentBuildingScreen> createState() =>
      _EquipmentBuildingScreenState();
}

class _EquipmentBuildingScreenState
    extends ConsumerState<EquipmentBuildingScreen> {
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
        child:
            ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
          ListTile(title: Text(strings.chooseEquipmentBuilding)),
          if (state.listPhase == BuildingListPhase.idle ||
              state.listPhase == BuildingListPhase.loading)
            HierarchyStatus(strings.loadingBuildings, loading: true),
          if (state.listPhase == BuildingListPhase.empty)
            HierarchyStatus(strings.noBuildings),
          if (state.listPhase == BuildingListPhase.error)
            HierarchyStatus(strings.buildingFailureMessage(state.listFailure),
                onRetry: controller.loadFirstPage, retryLabel: strings.retry),
          for (final building in state.records)
            ListTile(
                title: Text(building.name),
                subtitle: Text(building.code),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                    '/buildings/${Uri.encodeComponent(building.id)}/equipment')),
          if (state.listPhase == BuildingListPhase.ready &&
              state.listFailure != null)
            HierarchyStatus(strings.buildingFailureMessage(state.listFailure),
                onRetry: controller.loadMore, retryLabel: strings.retry),
          if (state.listPhase == BuildingListPhase.ready && state.hasMore)
            Center(
                child: state.loadingMore
                    ? const CircularProgressIndicator()
                    : TextButton(
                        onPressed: controller.loadMore,
                        child: Text(strings.loadMore))),
        ]));
  }
}
