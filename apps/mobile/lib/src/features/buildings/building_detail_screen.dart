import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/localization/app_strings.dart';
import 'buildings_controller.dart';

class BuildingDetailScreen extends ConsumerStatefulWidget {
  const BuildingDetailScreen({required this.buildingId, super.key});

  final String buildingId;

  @override
  ConsumerState<BuildingDetailScreen> createState() =>
      _BuildingDetailScreenState();
}

class _BuildingDetailScreenState extends ConsumerState<BuildingDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(buildingsControllerProvider.notifier)
            .loadDetail(widget.buildingId);
      }
    });
  }

  @override
  void didUpdateWidget(covariant BuildingDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.buildingId != widget.buildingId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(buildingsControllerProvider.notifier)
              .loadDetail(widget.buildingId);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final state = ref.watch(buildingsControllerProvider);
    final detail = state.detail?.id == widget.buildingId ? state.detail : null;
    final phase =
        state.detailPhase == BuildingDetailPhase.ready && detail == null
            ? BuildingDetailPhase.loading
            : state.detailPhase;
    return Scaffold(
      appBar: AppBar(title: Text(detail?.name ?? strings.section('buildings'))),
      body: SafeArea(
          child: switch (phase) {
        BuildingDetailPhase.idle || BuildingDetailPhase.loading => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(strings.loadingBuildings),
          ])),
        BuildingDetailPhase.ready when detail != null => ListView(children: [
            ListTile(title: Text(strings.code), subtitle: Text(detail.code)),
            if (detail.address?.isNotEmpty == true)
              ListTile(
                  title: Text(strings.address),
                  subtitle: Text(detail.address!)),
            ListTile(
                title: Text(strings.timezone), subtitle: Text(detail.timezone)),
            ListTile(
                title: Text(strings.browseFloors),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                    '/buildings/${Uri.encodeComponent(widget.buildingId)}/floors')),
            ListTile(
                title: Text(strings.browseEquipment),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                    '/buildings/${Uri.encodeComponent(widget.buildingId)}/equipment')),
          ]),
        _ => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(state.detailPhase == BuildingDetailPhase.unavailable
                ? strings.buildingUnavailable
                : strings.buildingFailureMessage(state.detailFailure)),
            if (state.detailPhase == BuildingDetailPhase.error)
              TextButton(
                onPressed: () => ref
                    .read(buildingsControllerProvider.notifier)
                    .loadDetail(widget.buildingId),
                child: Text(strings.retry),
              ),
          ])),
      }),
    );
  }
}
