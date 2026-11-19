import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/localization/app_strings.dart';
import '../floors/floors_controller.dart';
import '../floors/hierarchy_controller.dart';
import '../floors/hierarchy_status.dart';
import 'zones_controller.dart';

class ZoneDetailScreen extends ConsumerStatefulWidget {
  const ZoneDetailScreen(
      {required this.buildingId,
      required this.floorId,
      required this.zoneId,
      super.key});
  final String buildingId, floorId, zoneId;

  @override
  ConsumerState<ZoneDetailScreen> createState() => _ZoneDetailScreenState();
}

class _ZoneDetailScreenState extends ConsumerState<ZoneDetailScreen> {
  late final ZonesController _controller;
  bool _loadScheduled = false;
  HierarchyScope get scope => HierarchyScope(widget.buildingId, widget.floorId);
  void _load() {
    if (_loadScheduled) return;
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) {
        _controller.loadDetail(scope, widget.zoneId);
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
  void didUpdateWidget(covariant ZoneDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.buildingId != widget.buildingId ||
        oldWidget.floorId != widget.floorId ||
        oldWidget.zoneId != widget.zoneId) {
      _load();
    }
  }

  @override
  void dispose() {
    _controller.releaseDetail(scope, widget.zoneId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final state = ref.watch(zonesControllerProvider);
    final current =
        state.scope == scope && state.detailId == widget.zoneId ? state : null;
    if (current == null && (ModalRoute.of(context)?.isCurrent ?? true)) {
      _load();
    }
    final detail = current?.detail;
    final floors = ref.watch(floorsControllerProvider);
    final floor = floors.scope == HierarchyScope(widget.buildingId) &&
            floors.detailId == widget.floorId
        ? floors.detail
        : null;
    return Scaffold(
        appBar: AppBar(title: Text(detail?.name ?? strings.zone)),
        body: SafeArea(
            child: switch (current?.detailPhase) {
          HierarchyDetailPhase.ready when detail != null => ListView(children: [
              ListTile(
                  title: Text(strings.floor),
                  subtitle: Text(floor == null
                      ? widget.floorId
                      : '${floor.name} · ${strings.level} ${floor.level}')),
              ListTile(title: Text(strings.code), subtitle: Text(detail.code)),
              ListTile(
                  title: Text(strings.zoneType),
                  subtitle: Text(strings.zoneTypeLabel(detail.zoneType))),
            ]),
          HierarchyDetailPhase.unavailable =>
            HierarchyStatus(strings.zoneUnavailable),
          HierarchyDetailPhase.error => HierarchyStatus(
              strings.hierarchyFailureMessage(
                  current?.detailFailure, strings.zoneUnavailable),
              onRetry: () => ref
                  .read(zonesControllerProvider.notifier)
                  .loadDetail(scope, widget.zoneId),
              retryLabel: strings.retry),
          _ => HierarchyStatus(strings.loadingZones, loading: true),
        }));
  }
}
