import '../floors/hierarchy_controller.dart';

class EquipmentScope extends HierarchyScope {
  EquipmentScope(String buildingId,
      {String? floorId,
      this.zoneId,
      this.typeCode,
      this.lifecycleStatus,
      this.query})
      : super(buildingId, floorId) {
    if (zoneId != null && floorId == null) {
      throw const FormatException('Zone requires floor.');
    }
    if (query != null && (query!.isEmpty || query!.length > 100)) {
      throw const FormatException('Invalid equipment search.');
    }
  }
  final String? zoneId, typeCode, lifecycleStatus, query;

  @override
  bool operator ==(Object other) =>
      other is EquipmentScope &&
      super == other &&
      other.zoneId == zoneId &&
      other.typeCode == typeCode &&
      other.lifecycleStatus == lifecycleStatus &&
      other.query == query;
  @override
  int get hashCode =>
      Object.hash(super.hashCode, zoneId, typeCode, lifecycleStatus, query);
}
