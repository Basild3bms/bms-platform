import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/localization/app_strings.dart';
import '../buildings/buildings_controller.dart';
import 'floors_controller.dart';
import 'hierarchy_controller.dart';
import 'hierarchy_status.dart';

class FloorDetailScreen extends ConsumerStatefulWidget {
  const FloorDetailScreen(
      {required this.buildingId, required this.floorId, super.key});
  final String buildingId, floorId;

  @override
  ConsumerState<FloorDetailScreen> createState() => _FloorDetailScreenState();
}

class _FloorDetailScreenState extends ConsumerState<FloorDetailScreen> {
  late final FloorsController _controller;
  bool _loadScheduled = false;
  HierarchyScope get scope => HierarchyScope(widget.buildingId);
  void _load() {
    if (_loadScheduled) return;
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) {
        _controller.loadDetail(scope, widget.floorId);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _controller = ref.read(floorsControllerProvider.notifier);
    _load();
  }

  @override
  void didUpdateWidget(covariant FloorDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.buildingId != widget.buildingId ||
        oldWidget.floorId != widget.floorId) {
      _load();
    }
  }

  @override
  void dispose() {
    _controller.releaseDetail(scope, widget.floorId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final state = ref.watch(floorsControllerProvider);
    final current =
        state.scope == scope && state.detailId == widget.floorId ? state : null;
    if (current == null && (ModalRoute.of(context)?.isCurrent ?? true)) {
      _load();
    }
    final detail = current?.detail;
    final buildingState = ref.watch(buildingsControllerProvider);
    final building = buildingState.detail?.id == widget.buildingId
        ? buildingState.detail
        : null;
    return Scaffold(
        appBar: AppBar(title: Text(detail?.name ?? strings.floor)),
        body: SafeArea(
            child: switch (current?.detailPhase) {
          HierarchyDetailPhase.ready when detail != null => ListView(children: [
              ListTile(
                  title: Text(strings.building),
                  subtitle: Text(building?.name ?? widget.buildingId)),
              ListTile(title: Text(strings.code), subtitle: Text(detail.code)),
              ListTile(
                  title: Text(strings.level),
                  subtitle: Text('${detail.level}')),
              ListTile(
                  title: Text(strings.browseZones),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(
                      '/buildings/${Uri.encodeComponent(widget.buildingId)}/floors/${Uri.encodeComponent(widget.floorId)}/zones')),
            ]),
          HierarchyDetailPhase.unavailable =>
            HierarchyStatus(strings.floorUnavailable),
          HierarchyDetailPhase.error => HierarchyStatus(
              strings.hierarchyFailureMessage(
                  current?.detailFailure, strings.floorUnavailable),
              onRetry: () => ref
                  .read(floorsControllerProvider.notifier)
                  .loadDetail(scope, widget.floorId),
              retryLabel: strings.retry),
          _ => HierarchyStatus(strings.loadingFloors, loading: true),
        }));
  }
}
