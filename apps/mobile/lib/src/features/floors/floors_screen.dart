import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/localization/app_strings.dart';
import '../buildings/buildings_controller.dart';
import 'floors_controller.dart';
import 'hierarchy_controller.dart';
import 'hierarchy_status.dart';

class FloorsScreen extends ConsumerStatefulWidget {
  const FloorsScreen({required this.buildingId, super.key});
  final String buildingId;

  @override
  ConsumerState<FloorsScreen> createState() => _FloorsScreenState();
}

class _FloorsScreenState extends ConsumerState<FloorsScreen> {
  late final FloorsController _controller;
  bool _loadScheduled = false;
  HierarchyScope get scope => HierarchyScope(widget.buildingId);

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
    _controller = ref.read(floorsControllerProvider.notifier);
    _load();
  }

  @override
  void didUpdateWidget(covariant FloorsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.buildingId != widget.buildingId) {
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
    final state = ref.watch(floorsControllerProvider);
    final controller = ref.read(floorsControllerProvider.notifier);
    final current = state.scope == scope ? state : null;
    if (current == null && (ModalRoute.of(context)?.isCurrent ?? true)) {
      _load();
    }
    final buildings = ref.watch(buildingsControllerProvider);
    final building =
        buildings.detail?.id == widget.buildingId ? buildings.detail : null;
    return Scaffold(
      appBar: AppBar(title: Text(strings.floors)),
      body: SafeArea(
          child: RefreshIndicator(
              onRefresh: () => controller.refresh(scope),
              child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    ListTile(
                        title: Text(strings.building),
                        subtitle: Text(building?.name ?? widget.buildingId)),
                    if (current == null ||
                        current.listPhase == HierarchyListPhase.idle ||
                        current.listPhase == HierarchyListPhase.loading)
                      HierarchyStatus(strings.loadingFloors, loading: true),
                    if (current?.listPhase == HierarchyListPhase.empty)
                      HierarchyStatus(strings.noFloors),
                    if (current?.listPhase == HierarchyListPhase.error)
                      HierarchyStatus(
                          strings.hierarchyFailureMessage(
                              current!.listFailure, strings.floorUnavailable),
                          onRetry: () => controller.loadFirstPage(scope),
                          retryLabel: strings.retry),
                    for (final floor in current?.records ?? [])
                      ListTile(
                          title: Text(floor.name),
                          subtitle: Text(
                              '${floor.code} · ${strings.level} ${floor.level}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(
                              '/buildings/${Uri.encodeComponent(widget.buildingId)}/floors/${Uri.encodeComponent(floor.id)}')),
                    if (current?.listPhase == HierarchyListPhase.ready &&
                        current?.listFailure != null)
                      HierarchyStatus(
                          strings.hierarchyFailureMessage(
                              current!.listFailure, strings.floorUnavailable),
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
