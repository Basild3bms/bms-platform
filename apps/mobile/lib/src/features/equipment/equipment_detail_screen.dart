import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/localization/app_strings.dart';
import '../floors/hierarchy_controller.dart';
import '../floors/hierarchy_status.dart';
import 'equipment_controller.dart';
import 'equipment_scope.dart';

class EquipmentDetailScreen extends ConsumerStatefulWidget {
  const EquipmentDetailScreen(
      {required this.buildingId, required this.equipmentId, super.key});
  final String buildingId, equipmentId;

  @override
  ConsumerState<EquipmentDetailScreen> createState() =>
      _EquipmentDetailScreenState();
}

class _EquipmentDetailScreenState extends ConsumerState<EquipmentDetailScreen> {
  late final EquipmentController _controller;
  bool _loadScheduled = false;
  EquipmentScope get scope => EquipmentScope(widget.buildingId);

  void _load() {
    if (_loadScheduled) return;
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) {
        _controller.loadDetail(scope, widget.equipmentId);
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
  void didUpdateWidget(covariant EquipmentDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.buildingId != widget.buildingId ||
        oldWidget.equipmentId != widget.equipmentId) {
      _load();
    }
  }

  @override
  void dispose() {
    _controller.releaseDetail(scope, widget.equipmentId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final state = ref.watch(equipmentControllerProvider);
    final current = state.scope == scope && state.detailId == widget.equipmentId
        ? state
        : null;
    if (current == null && (ModalRoute.of(context)?.isCurrent ?? true)) _load();
    final item = current?.detail;
    return Scaffold(
      appBar: AppBar(title: Text(item?.code ?? strings.section('equipment'))),
      body: SafeArea(
          child: switch (current?.detailPhase) {
        HierarchyDetailPhase.ready when item != null => ListView(children: [
            ListTile(title: Text(strings.code), subtitle: Text(item.code)),
            ListTile(
                title: Text(item.name),
                subtitle:
                    Text(strings.equipmentStatusLabel(item.lifecycleStatus))),
            if (item.description?.isNotEmpty == true)
              ListTile(
                  title: Text(strings.description),
                  subtitle: Text(item.description!)),
            ListTile(
                title: Text(strings.equipmentType),
                subtitle: Text(strings.equipmentTypeLabel(item.typeCode))),
            ListTile(
                title: Text(strings.lifecycleStatus),
                subtitle:
                    Text(strings.equipmentStatusLabel(item.lifecycleStatus))),
            if (item.manufacturer?.isNotEmpty == true)
              ListTile(
                  title: Text(strings.manufacturer),
                  subtitle: Text(item.manufacturer!)),
            if (item.model?.isNotEmpty == true)
              ListTile(title: Text(strings.model), subtitle: Text(item.model!)),
            if (item.serialNumber?.isNotEmpty == true)
              ListTile(
                  title: Text(strings.serialNumber),
                  subtitle: Text(item.serialNumber!)),
            ListTile(
                title: Text(strings.building), subtitle: Text(item.buildingId)),
            ListTile(
                title: Text(strings.floor),
                subtitle: Text(item.floorId ?? strings.buildingLevel)),
            if (item.zoneId != null)
              ListTile(title: Text(strings.zone), subtitle: Text(item.zoneId!)),
            ListTile(
                title: Text(strings.installedOn),
                subtitle: Text(strings.equipmentDate(item.installedOn))),
            ListTile(
                title: Text(strings.commissionedOn),
                subtitle: Text(strings.equipmentDate(item.commissionedOn))),
            ListTile(
                title: Text(strings.specifications),
                subtitle: Text(item.specifications == null
                    ? strings.notAvailable
                    : item.specifications!.supported
                        ? item.specifications!.values.isEmpty
                            ? strings.notAvailable
                            : ''
                        : strings.specificationsUnsupported)),
            if (item.specifications?.supported == true)
              for (final spec in item.specifications!.values.entries)
                ListTile(
                    title: Text(strings.specificationLabel(spec.key)),
                    subtitle: Text(
                        '${spec.value} ${spec.key.endsWith('_kw') ? 'kW' : 'm³/h'}')),
          ]),
        HierarchyDetailPhase.unavailable =>
          HierarchyStatus(strings.equipmentUnavailable),
        HierarchyDetailPhase.error => HierarchyStatus(
            strings.hierarchyFailureMessage(
                current?.detailFailure, strings.equipmentUnavailable),
            onRetry: () => _controller.loadDetail(scope, widget.equipmentId),
            retryLabel: strings.retry),
        _ => HierarchyStatus(strings.loadingEquipment, loading: true),
      }),
    );
  }
}
