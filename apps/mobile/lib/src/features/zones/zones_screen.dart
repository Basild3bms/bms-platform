import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/localization/app_strings.dart';
import '../floors/floors_controller.dart';
import '../floors/hierarchy_controller.dart';
import '../floors/hierarchy_status.dart';
import 'zones_controller.dart';

class ZonesScreen extends ConsumerStatefulWidget {
  const ZonesScreen(
      {required this.buildingId, required this.floorId, super.key});
  final String buildingId, floorId;

  @override
  ConsumerState<ZonesScreen> createState() => _ZonesScreenState();
}

class _ZonesScreenState extends ConsumerState<ZonesScreen> {
  late final ZonesController _controller;
  bool _loadScheduled = false;
  HierarchyScope get scope => HierarchyScope(widget.buildingId, widget.floorId);
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
    _controller = ref.read(zonesControllerProvider.notifier);
    _load();
  }

  @override
  void didUpdateWidget(covariant ZonesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.buildingId != widget.buildingId ||
        oldWidget.floorId != widget.floorId) {
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
    final state = ref.watch(zonesControllerProvider);
    final current = state.scope == scope ? state : null;
    if (current == null && (ModalRoute.of(context)?.isCurrent ?? true)) {
      _load();
    }
    final floors = ref.watch(floorsControllerProvider);
    final floor = floors.scope == HierarchyScope(widget.buildingId) &&
            floors.detailId == widget.floorId
        ? floors.detail
        : null;
    final controller = ref.read(zonesControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(strings.zones)),
      body: SafeArea(
          child: RefreshIndicator(
              onRefresh: () => controller.refresh(scope),
              child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    ListTile(
                        title: Text(strings.floor),
                        subtitle: Text(floor == null
                            ? widget.floorId
                            : '${floor.name} · ${strings.level} ${floor.level}')),
                    if (current == null ||
                        current.listPhase == HierarchyListPhase.idle ||
                        current.listPhase == HierarchyListPhase.loading)
                      HierarchyStatus(strings.loadingZones, loading: true),
                    if (current?.listPhase == HierarchyListPhase.empty)
                      HierarchyStatus(strings.noZones),
                    if (current?.listPhase == HierarchyListPhase.error)
                      HierarchyStatus(
                          strings.hierarchyFailureMessage(
                              current!.listFailure, strings.zoneUnavailable),
                          onRetry: () => controller.loadFirstPage(scope),
                          retryLabel: strings.retry),
                    for (final zone in current?.records ?? [])
                      ListTile(
                          title: Text(zone.name),
                          subtitle: Text(
                              '${zone.code} · ${strings.zoneTypeLabel(zone.zoneType)}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(
                              '/buildings/${Uri.encodeComponent(widget.buildingId)}/floors/${Uri.encodeComponent(widget.floorId)}/zones/${Uri.encodeComponent(zone.id)}')),
                    if (current?.listPhase == HierarchyListPhase.ready &&
                        current?.listFailure != null)
                      HierarchyStatus(
                          strings.hierarchyFailureMessage(
                              current!.listFailure, strings.zoneUnavailable),
                          onRetry: () => controller.loadMore(scope),
                          retryLabel: strings.retry),
                    if (current?.listPhase == HierarchyListPhase.ready &&
                        current!.hasMore)
                      Center(
                          child: current.loadingMore
                              ? const CircularProgressIndicator()
                              : TextButton(
                                  onPressed: () => controller.loadMore(scope),
                                  child: Text(strings.loadMore))),
                  ]))),
    );
  }
}
