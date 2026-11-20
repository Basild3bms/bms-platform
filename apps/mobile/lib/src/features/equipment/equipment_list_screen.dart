import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/localization/app_strings.dart';
import '../floors/hierarchy_controller.dart';
import '../floors/hierarchy_status.dart';
import 'equipment_controller.dart';
import 'equipment_models.dart';
import 'equipment_scope.dart';

class EquipmentListScreen extends ConsumerStatefulWidget {
  const EquipmentListScreen(
      {required this.buildingId, this.floorId, this.zoneId, super.key});
  final String buildingId;
  final String? floorId, zoneId;

  @override
  ConsumerState<EquipmentListScreen> createState() =>
      _EquipmentListScreenState();
}

class _EquipmentListScreenState extends ConsumerState<EquipmentListScreen> {
  late final EquipmentController _controller;
  bool _loadScheduled = false;
  EquipmentScope get scope => EquipmentScope(widget.buildingId,
      floorId: widget.floorId, zoneId: widget.zoneId);

  void _load() {
    if (_loadScheduled) return;
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) {
        _controller.loadFirstPage(scope);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _controller = ref.read(equipmentControllerProvider.notifier);
    _load();
  }

  @override
  void didUpdateWidget(covariant EquipmentListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.buildingId != widget.buildingId ||
        oldWidget.floorId != widget.floorId ||
        oldWidget.zoneId != widget.zoneId) {
      _load();
    }
  }

  @override
  void dispose() {
    _controller.releaseList(scope);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final state = ref.watch(equipmentControllerProvider);
    final current = state.scope == scope ? state : null;
    if (current == null && (ModalRoute.of(context)?.isCurrent ?? true)) _load();
    final heading = widget.zoneId != null
        ? strings.equipmentZoneScope
        : widget.floorId != null
            ? strings.equipmentFloorScope
            : strings.equipmentBuildingScope;
    return Scaffold(
      appBar: AppBar(title: Text(strings.section('equipment'))),
      body: SafeArea(
          child: RefreshIndicator(
              onRefresh: () => _controller.refresh(scope),
              child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    ListTile(
                        title: Text(heading),
                        subtitle: Text(widget.zoneId ??
                            widget.floorId ??
                            widget.buildingId)),
                    if (current == null ||
                        current.listPhase == HierarchyListPhase.idle ||
                        current.listPhase == HierarchyListPhase.loading)
                      HierarchyStatus(strings.loadingEquipment, loading: true),
                    if (current?.listPhase == HierarchyListPhase.empty)
                      HierarchyStatus(strings.noEquipment),
                    if (current?.listPhase == HierarchyListPhase.error)
                      HierarchyStatus(
                          strings.hierarchyFailureMessage(current?.listFailure,
                              strings.equipmentUnavailable),
                          onRetry: () => _controller.loadFirstPage(scope),
                          retryLabel: strings.retry),
                    if (current?.listPhase == HierarchyListPhase.ready)
                      for (final item in current!.records)
                        ListTile(
                          title: Text(item.code),
                          subtitle: Text(
                              '${item.name} · ${strings.equipmentTypeLabel(item.typeCode)} · '
                              '${strings.equipmentStatusLabel(item.lifecycleStatus)} · '
                              '${_location(item, strings)}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(
                              '/buildings/${Uri.encodeComponent(widget.buildingId)}/equipment/${Uri.encodeComponent(item.id)}'),
                        ),
                    if (current?.listPhase == HierarchyListPhase.ready &&
                        current?.listFailure != null)
                      HierarchyStatus(
                          strings.hierarchyFailureMessage(current!.listFailure,
                              strings.equipmentUnavailable),
                          onRetry: () => _controller.loadMore(scope),
                          retryLabel: strings.retry),
                    if (current?.listPhase == HierarchyListPhase.ready &&
                        current!.hasMore)
                      Center(
                          child: current.loadingMore
                              ? const CircularProgressIndicator()
                              : TextButton(
                                  onPressed: () => _controller.loadMore(scope),
                                  child: Text(strings.loadMore))),
                  ]))),
    );
  }

  String _location(EquipmentRecord item, AppStrings strings) {
    if (item.zoneId != null) return '${strings.zone} ${item.zoneId}';
    if (item.floorId != null) return '${strings.floor} ${item.floorId}';
    return strings.buildingLevel;
  }
}
